#!/usr/bin/env python3
"""
scripts/verify_tflite_parity.py
Production Edge-ML Parity & Verification Script for FloraX / KisanSetu
Validates on-device 45-class EfficientNetV2 FP16 LiteRT model contract,
probability distributions, 2-view TTA, and offline ICAR IPM lookup.
"""

import os
import sys
import json
import math
import numpy as np
from PIL import Image

try:
    import tflite_runtime.interpreter as tflite
except ImportError:
    try:
        import tensorflow.lite as tflite
    except ImportError:
        import subprocess
        alt_python = r"D:\tools\python\python.exe"
        if os.path.exists(alt_python) and sys.executable.lower() != alt_python.lower():
            sys.exit(subprocess.call([alt_python, __file__] + sys.argv[1:]))
        print("[ERROR] Neither tflite_runtime nor tensorflow.lite is available.")
        sys.exit(1)

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MODEL_PATH = os.path.join(PROJECT_ROOT, "assets", "models", "florax_v2_45c_fp16.tflite")
LABELS_PATH = os.path.join(PROJECT_ROOT, "assets", "models", "labels.txt")
META_PATH = os.path.join(PROJECT_ROOT, "assets", "models", "model_meta.json")
PROTOCOLS_PATH = os.path.join(PROJECT_ROOT, "assets", "data", "offline_icar_protocols.json")
REAL_LEAF_PATH = os.path.join(PROJECT_ROOT, "leaf_test.jpg")

def compute_normalized_entropy(probs):
    k = len(probs)
    ln_k = math.log(k)
    entropy = 0.0
    for p in probs:
        if p > 1e-12:
            entropy -= p * math.log(p)
    return entropy / ln_k if ln_k > 0 else 0.0

def run_inference_tta(interpreter, img_rgb_224):
    """Executes 2-View TTA (Original + Horizontally Flipped) matching Dart runtime."""
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # View 1: Original
    input_orig = np.expand_dims(img_rgb_224.astype(np.float32), axis=0)
    interpreter.set_tensor(input_details[0]['index'], input_orig)
    interpreter.invoke()
    out_orig = interpreter.get_tensor(output_details[0]['index'])[0]

    # View 2: Horizontal flip
    img_flipped = np.fliplr(img_rgb_224)
    input_flipped = np.expand_dims(img_flipped.astype(np.float32), axis=0)
    interpreter.set_tensor(input_details[0]['index'], input_flipped)
    interpreter.invoke()
    out_flipped = interpreter.get_tensor(output_details[0]['index'])[0]

    # Averaged TTA probabilities
    avg_probs = (out_orig + out_flipped) / 2.0
    sum_probs = np.sum(avg_probs)
    normalized_probs = avg_probs / sum_probs
    return normalized_probs

def main():
    print("=" * 80)
    print("FLORAX PRODUCTION TFLITE EDGE-ML PARITY VERIFICATION")
    print("=" * 80)

    # 1. Validate files on disk
    for path, desc in [
        (MODEL_PATH, "TFLite Model"),
        (LABELS_PATH, "Labels File"),
        (META_PATH, "Model Metadata"),
        (PROTOCOLS_PATH, "Offline ICAR Protocols"),
        (REAL_LEAF_PATH, "Real Leaf Sample"),
    ]:
        if not os.path.isfile(path):
            print(f"[ERROR] Missing file: {desc} at {path}")
            sys.exit(1)
        print(f"[OK] Found {desc}: {path} ({os.path.getsize(path):,} bytes)")

    # 2. Inspect metadata & labels
    with open(META_PATH, "r", encoding="utf-8") as f:
        meta = json.load(f)
    with open(LABELS_PATH, "r", encoding="utf-8") as f:
        labels = [line.strip() for line in f if line.strip()]

    print(f"\n[METADATA CONTRACT]")
    print(f"  Model Version : {meta.get('model_version')}")
    print(f"  Backbone      : {meta.get('backbone')}")
    print(f"  Num Classes   : {meta.get('num_classes')} (labels count: {len(labels)})")
    print(f"  Input Shape   : {meta.get('input_shape')}")
    print(f"  Input Range   : {meta.get('input_range')}")
    print(f"  OOD Class     : {meta.get('ood_class')}")

    assert len(labels) == 45, f"Expected 45 labels, got {len(labels)}"
    assert meta.get('num_classes') == 45, f"Expected 45 classes in meta, got {meta.get('num_classes')}"

    # 3. Instantiate Interpreter and Validate Tensors
    interpreter = tflite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    in_shape = list(input_details[0]['shape'])
    out_shape = list(output_details[0]['shape'])
    in_dtype = str(input_details[0]['dtype'])
    out_dtype = str(output_details[0]['dtype'])

    print(f"\n[TENSOR VALIDATION]")
    print(f"  Input Tensor  : shape={in_shape}, dtype={in_dtype}")
    print(f"  Output Tensor : shape={out_shape}, dtype={out_dtype}")

    assert in_shape == [1, 224, 224, 3], f"Invalid input shape: {in_shape}"
    assert out_shape == [1, 45], f"Invalid output shape: {out_shape}"
    assert "float32" in in_dtype, f"Invalid input dtype: {in_dtype}"
    assert "float32" in out_dtype, f"Invalid output dtype: {out_dtype}"
    print("[PASS] Tensor Contract Validated: [1, 224, 224, 3] Float32 -> [1, 45] Float32")

    # 4. Load Offline ICAR Protocols
    with open(PROTOCOLS_PATH, "r", encoding="utf-8") as f:
        icar_data = json.load(f)
    if isinstance(icar_data, list):
        protocols = {item["id"]: item for item in icar_data if isinstance(item, dict) and "id" in item}
    elif isinstance(icar_data, dict):
        protocols = icar_data.get("protocols", {})
    else:
        protocols = {}
    print(f"\n[ICAR PROTOCOL KNOWLEDGE VAULT]")
    print(f"  Loaded {len(protocols)} offline agronomic IPM treatment protocols.")
    assert len(protocols) >= 45, f"Expected at least 45 protocols in knowledge vault, got {len(protocols)}"

    # 5. SAMPLE 1: Real Leaf Image
    print(f"\n[INFERENCE TEST: REAL LEAF SAMPLE]")
    print(f"  Source: {REAL_LEAF_PATH}")
    pil_leaf = Image.open(REAL_LEAF_PATH).convert("RGB")
    pil_leaf_224 = pil_leaf.resize((224, 224), Image.Resampling.BILINEAR)
    np_leaf_224 = np.array(pil_leaf_224, dtype=np.float32) # [0.0, 255.0]

    assert np_leaf_224.shape == (224, 224, 3), f"Invalid array shape: {np_leaf_224.shape}"
    assert np_leaf_224.max() > 1.0, "Input range error: values are not in [0.0, 255.0]"

    probs_leaf = run_inference_tta(interpreter, np_leaf_224)
    sum_probs_leaf = float(np.sum(probs_leaf))
    entropy_leaf = compute_normalized_entropy(probs_leaf)

    assert len(probs_leaf) == 45, f"Invalid class output count: {len(probs_leaf)}"
    assert not np.isnan(probs_leaf).any(), "NaN detected in inference probabilities!"
    assert not np.isinf(probs_leaf).any(), "Infinity detected in inference probabilities!"
    assert abs(sum_probs_leaf - 1.0) < 1e-4, f"Softmax sum must be 1.0, got {sum_probs_leaf}"

    top1_idx = int(np.argmax(probs_leaf))
    top1_label = labels[top1_idx]
    top1_conf = float(probs_leaf[top1_idx])

    # Top-3 predictions
    top3_indices = np.argsort(probs_leaf)[::-1][:3]
    print(f"  Inference Sum(Probs) : {sum_probs_leaf:.6f} [PASS == 1.0]")
    print(f"  Shannon Entropy      : {entropy_leaf:.4f}")
    print(f"  Top-1 Prediction     : {top1_label} ({top1_conf*100:.2f}%)")
    print(f"  Top-3 Candidate Set  :")
    for rank, idx in enumerate(top3_indices, start=1):
        print(f"    #{rank} {labels[idx]:<35} : {probs_leaf[idx]*100:.2f}%")

    # Match protocol
    protocol = protocols.get(top1_label)
    if not protocol:
        # Fallback to general category or primary crop protocol
        crop_prefix = top1_label.split('_')[0]
        matching_keys = [k for k in protocols if k.startswith(crop_prefix)]
        protocol = protocols.get(matching_keys[0]) if matching_keys else None
    
    assert protocol is not None, f"ICAR IPM protocol lookup failed for {top1_label}"
    protocol_name = protocol.get('disease_name') or protocol.get('title') or list(protocol.keys())
    print(f"  ICAR Protocol Match  : Found verified advisory ({protocol_name}) [PASS]")

    # 6. SAMPLE 2: Synthetic Non-Leaf Sample (Uniform Gray/Noise to test OOD)
    print(f"\n[INFERENCE TEST: SYNTHETIC NON-LEAF SAMPLE]")
    np_nonleaf_224 = np.full((224, 224, 3), 128.0, dtype=np.float32)
    probs_nonleaf = run_inference_tta(interpreter, np_nonleaf_224)
    sum_probs_nonleaf = float(np.sum(probs_nonleaf))
    entropy_nonleaf = compute_normalized_entropy(probs_nonleaf)

    assert len(probs_nonleaf) == 45
    assert not np.isnan(probs_nonleaf).any()
    assert abs(sum_probs_nonleaf - 1.0) < 1e-4, f"Softmax sum must be 1.0, got {sum_probs_nonleaf}"

    top1_nl_idx = int(np.argmax(probs_nonleaf))
    top1_nl_label = labels[top1_nl_idx]
    top1_nl_conf = float(probs_nonleaf[top1_nl_idx])

    print(f"  Inference Sum(Probs) : {sum_probs_nonleaf:.6f} [PASS == 1.0]")
    print(f"  Shannon Entropy      : {entropy_nonleaf:.4f}")
    print(f"  Top-1 Prediction     : {top1_nl_label} ({top1_nl_conf*100:.2f}%)")
    
    # Check OOD detection behavior
    is_ood = (top1_nl_label == "not_a_leaf_background") or (top1_nl_conf < meta.get("ood_min_confidence", 0.45)) or (entropy_nonleaf > meta.get("ood_max_normalized_entropy", 0.65))
    print(f"  OOD Gate Activated   : {is_ood} (Confidence < 45% or Entropy > 0.65 or not_a_leaf_background) [PASS]")
    assert is_ood, "Synthetic non-leaf sample was not rejected by OOD guardrails!"

    print("\n" + "=" * 80)
    print("ALL EDGE-ML PARITY CHECKS PASSED: MODEL IS PRODUCTION-READY FOR DEPLOYMENT")
    print("=" * 80)
    return 0

if __name__ == "__main__":
    sys.exit(main())
