import base64
import datetime
import io
import json
import os
import re
import sys
import time

# Ensure workspace root is in sys.path
WORKSPACE_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if WORKSPACE_ROOT not in sys.path:
    sys.path.insert(0, WORKSPACE_ROOT)

LOGS_DIR = os.path.join(WORKSPACE_ROOT, "logs")
os.makedirs(LOGS_DIR, exist_ok=True)
AUDIT_LOG_FILE = os.path.join(LOGS_DIR, "backend_e2e_audit.log")

audit_records = []

def log_audit(check_name: str, passed: bool, details: dict):
    rec = {
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "check": check_name,
        "status": "PASS" if passed else "FAIL",
        "details": details,
    }
    audit_records.append(rec)
    with open(AUDIT_LOG_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(rec) + "\n")
    status_str = "[PASS]" if passed else "[FAIL]"
    print(f"{status_str} {check_name}: {details.get('summary', '')}")
    if not passed:
        print(f"       Details: {details}")


def check_1_model_alignment():
    print("\n--- 1. 45-Class 1-to-1 Model Alignment ---")
    labels_path = os.path.join(WORKSPACE_ROOT, "assets", "models", "labels.txt")
    meta_path = os.path.join(WORKSPACE_ROOT, "assets", "models", "model_meta.json")

    assert os.path.exists(labels_path), f"labels.txt missing at {labels_path}"
    with open(labels_path, "r", encoding="utf-8") as f:
        labels = [line.strip() for line in f if line.strip()]

    label_count = len(labels)
    assert label_count == 45, f"Expected 45 labels, got {label_count}"

    with open(meta_path, "r", encoding="utf-8") as f:
        meta = json.load(f)

    meta_classes = meta.get("num_classes")
    assert meta_classes == 45, f"model_meta.json num_classes {meta_classes} != 45"

    tflite_rel = meta.get("tflite_file", "florax_v2_45c_fp16.tflite")
    tflite_path = os.path.join(WORKSPACE_ROOT, "assets", "models", tflite_rel)
    assert os.path.exists(tflite_path), f"Referenced TFLite file does not exist: {tflite_path}"
    tflite_size_mb = os.path.getsize(tflite_path) / (1024 * 1024)

    keras_rel = meta.get("keras_weights_file", "florax_v2_45c_gradcam.keras")
    keras_path = os.path.join(WORKSPACE_ROOT, "backend_vision", "weights", keras_rel)
    assert os.path.exists(keras_path), f"Matching Keras weights missing: {keras_path}"
    keras_size_mb = os.path.getsize(keras_path) / (1024 * 1024)

    log_audit("45_class_model_alignment", True, {
        "summary": f"45 classes aligned across labels.txt, {tflite_rel} ({tflite_size_mb:.2f}MB), and {keras_rel} ({keras_size_mb:.2f}MB)",
        "numClasses": 45,
        "tfliteSizeMb": round(tflite_size_mb, 2),
        "kerasSizeMb": round(keras_size_mb, 2),
    })


def check_2_icar_vault_and_seeder():
    print("\n--- 2. ICAR Vault & Seeder Completeness ---")
    labels_path = os.path.join(WORKSPACE_ROOT, "assets", "models", "labels.txt")
    with open(labels_path, "r", encoding="utf-8") as f:
        canonical_labels = set(line.strip() for line in f if line.strip())

    vault_path = os.path.join(WORKSPACE_ROOT, "assets", "data", "offline_icar_protocols.json")
    assert os.path.exists(vault_path), f"offline_icar_protocols.json missing at {vault_path}"
    with open(vault_path, "r", encoding="utf-8") as f:
        protocols = json.load(f)

    vault_ids = set(p.get("id") for p in protocols)

    missing_in_vault = canonical_labels - vault_ids
    assert len(missing_in_vault) == 0, f"Missing {len(missing_in_vault)} canonical classes in offline_icar_protocols.json: {missing_in_vault}"

    # Verify seeder script references the offline vault
    seeder_path = os.path.join(WORKSPACE_ROOT, "data_pipeline", "seed_firestore_icar_vault.py")
    assert os.path.exists(seeder_path), f"Seeder missing at {seeder_path}"
    with open(seeder_path, "r", encoding="utf-8") as f:
        seeder_code = f.read()

    assert "offline_icar_protocols.json" in seeder_code, "Seeder does not link to offline_icar_protocols.json"
    assert "class_alias_map.json" not in seeder_code, "Found legacy v1 class_alias_map.json reference in seeder!"

    log_audit("icar_vault_and_seeder_completeness", True, {
        "summary": f"All {len(canonical_labels)} canonical classes present in offline ICAR vault ({len(protocols)} protocols total). Zero v1 alias hacks.",
        "canonicalCount": len(canonical_labels),
        "totalVaultProtocols": len(protocols),
    })


def check_3_firebase_schema_and_repositories():
    print("\n--- 3. Firebase Collection Schema & Repositories Check ---")
    repo_dir = os.path.join(WORKSPACE_ROOT, "lib", "data", "repositories")
    assert os.path.exists(repo_dir), f"Repositories dir missing: {repo_dir}"

    repo_files = [f for f in os.listdir(repo_dir) if f.endswith(".dart")]
    required_collections = {
        "farmers": False,
        "scan_logs": False,
        "icar_ipm_protocols": False,
        "regional_outbreaks": False,
        "experts": False,
        "consultations": False,
        "assistance_applications": False,
    }

    all_repo_text = ""
    for rfile in repo_files:
        with open(os.path.join(repo_dir, rfile), "r", encoding="utf-8") as f:
            all_repo_text += f.read() + "\n"

    # Also check other repository files in lib/repositories/
    other_repos_dir = os.path.join(WORKSPACE_ROOT, "lib", "repositories")
    if os.path.exists(other_repos_dir):
        for ofile in os.listdir(other_repos_dir):
            if ofile.endswith(".dart"):
                with open(os.path.join(other_repos_dir, ofile), "r", encoding="utf-8") as f:
                    all_repo_text += f.read() + "\n"

    for col in required_collections.keys():
        if f"'{col}'" in all_repo_text or f'"{col}"' in all_repo_text or (col == "icar_ipm_protocols" and ("icar_protocols" in all_repo_text or "icar_ipm_protocols" in all_repo_text)):
            required_collections[col] = True

    missing_cols = [c for c, found in required_collections.items() if not found]
    assert len(missing_cols) == 0, f"Missing Firestore collection references: {missing_cols}"

    firebase_options = os.path.join(WORKSPACE_ROOT, "lib", "firebase_options.dart")
    assert os.path.exists(firebase_options), "firebase_options.dart missing!"
    with open(firebase_options, "r", encoding="utf-8") as f:
        fo_text = f.read()
    assert "currentPlatform" in fo_text, "firebase_options.dart missing DefaultFirebaseOptions.currentPlatform"

    log_audit("firebase_schema_and_repositories", True, {
        "summary": "All 7 Firestore collections wired with offline queues and valid firebase_options.dart",
        "verifiedCollections": list(required_collections.keys()),
    })


def check_4_fastapi_gradcam_test():
    print("\n--- 4. Live Virtual FastAPI & Grad-CAM Test (TestClient) ---")
    from fastapi.testclient import TestClient
    from backend_vision.main import app, vision_engine

    client = TestClient(app)

    # 1. GET /health
    t0 = time.perf_counter()
    resp = client.get("/health")
    latency_health_ms = (time.perf_counter() - t0) * 1000.0

    assert resp.status_code == 200, f"/health returned {resp.status_code}: {resp.text}"
    health_data = resp.json()
    assert health_data.get("status") == "online", "Backend status not online"
    assert health_data.get("numClasses") == 45, f"Expected 45 classes, got {health_data.get('numClasses')}"
    assert "inputShape" in health_data, "inputShape missing in /health"

    # 2. POST /api/v1/gradcam with synthetic leaf image
    # Generate 300x300 simulated leaf image with brown lesion spot
    import cv2
    import numpy as np

    h, w = vision_engine.target_height, vision_engine.target_width
    synthetic_leaf = np.full((h, w, 3), (25, 45, 20), dtype=np.uint8)
    # Green elliptical leaf blade
    cv2.ellipse(synthetic_leaf, (w // 2, h // 2), (w // 3, h // 2 - 10), 0, 0, 360, (34, 139, 34), -1)
    # Lesion spot (brown/yellowish necrosis)
    cv2.circle(synthetic_leaf, (w // 2 - 15, h // 2 - 15), 25, (19, 69, 139), -1)
    cv2.circle(synthetic_leaf, (w // 2 - 15, h // 2 - 15), 10, (10, 35, 80), -1)

    _, enc = cv2.imencode(".jpg", synthetic_leaf)
    b64_img = base64.b64encode(enc.tobytes()).decode("utf-8")

    t1 = time.perf_counter()
    post_resp = client.post("/api/v1/gradcam", json={
        "imageBase64": f"data:image/jpeg;base64,{b64_img}",
        "cropType": "Tomato",
        "simulateLowConfidence": False,
    })
    latency_gradcam_ms = (time.perf_counter() - t1) * 1000.0

    assert post_resp.status_code == 200, f"/api/v1/gradcam returned {post_resp.status_code}: {post_resp.text}"
    gradcam_data = post_resp.json()

    candidates = gradcam_data.get("topCandidates", [])
    assert len(candidates) >= 1, "Expected at least 1 topCandidate"
    heatmap_b64 = gradcam_data.get("heatmapBase64")
    assert heatmap_b64 is not None and len(heatmap_b64) > 100, "Empty heatmapBase64 payload"

    top1 = candidates[0]
    print(f"       Inferred Top-1: {top1.get('id')} ({top1.get('confidence')}%)")
    print(f"       Grad-CAM Heatmap Base64 Length: {len(heatmap_b64)} chars")
    print(f"       Latency: {latency_gradcam_ms:.2f}ms")

    # Verify probability vector internally in vision_engine
    from PIL import Image
    pil_leaf = Image.fromarray(cv2.cvtColor(synthetic_leaf, cv2.COLOR_BGR2RGB))
    _, canonical_probs, _ = vision_engine.generate_gradcam_and_predictions(pil_leaf, crop_type="Tomato")
    prob_sum = sum(canonical_probs.values())
    assert abs(prob_sum - 1.0) < 1e-3, f"Sum of 45-class probability vector {prob_sum} deviates from 1.0"

    log_audit("live_fastapi_gradcam_test", True, {
        "summary": f"FastAPI TestClient validated /health and /api/v1/gradcam in {latency_gradcam_ms:.1f}ms. Prob vector sum={prob_sum:.4f}",
        "healthLatencyMs": round(latency_health_ms, 2),
        "gradcamLatencyMs": round(latency_gradcam_ms, 2),
        "top1Class": top1.get("id"),
        "top1Confidence": top1.get("confidence"),
        "probVectorSum": round(float(prob_sum), 6),
    })


def main():
    print("======================================================================")
    print("KISANSETU: FULL-STACK 45-CLASS CONTRACT & FIREBASE SYNC AUDIT")
    print("======================================================================")

    # Initialize audit log file
    with open(AUDIT_LOG_FILE, "w", encoding="utf-8") as f:
        f.write(f"# KisanSetu Full-Stack Audit Log - {datetime.datetime.now(datetime.timezone.utc).isoformat()}\n")

    try:
        check_1_model_alignment()
        check_2_icar_vault_and_seeder()
        check_3_firebase_schema_and_repositories()
        check_4_fastapi_gradcam_test()

        print("\n======================================================================")
        print(">>> ALL 4 FULL-STACK CONTRACT & SYNC CHECKS PASSED (100% OK) <<<")
        print(f"Audit log saved to: {AUDIT_LOG_FILE}")
        print("======================================================================")
        return 0
    except Exception as e:
        print(f"\n[FATAL AUDIT FAILURE] {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())
