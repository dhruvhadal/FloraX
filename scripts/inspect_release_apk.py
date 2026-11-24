#!/usr/bin/env python3
"""
scripts/inspect_release_apk.py
Production Release APK Forensic Binary Inspection Script
Verifies uncompressed TFLite assets, native LiteRT/TFLite SO libraries,
offline ICAR vault, branding assets, and Android permissions in release APK.
"""

import os
import sys
import json
import zipfile
import hashlib

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DEFAULT_APK_PATH = os.path.join(PROJECT_ROOT, "build", "app", "outputs", "flutter-apk", "app-release.apk")

def compute_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def inspect_apk(apk_path=DEFAULT_APK_PATH):
    print("=" * 80)
    print("KISANSETU RELEASE APK BINARY FORENSIC INSPECTION")
    print("=" * 80)
    
    if not os.path.exists(apk_path):
        print(f"[FAIL] Target APK does not exist at: {apk_path}")
        return False
        
    apk_size_bytes = os.path.getsize(apk_path)
    apk_size_mb = apk_size_bytes / (1024 * 1024)
    sha256_hash = compute_sha256(apk_path)
    
    print(f"APK Path       : {apk_path}")
    print(f"File Size      : {apk_size_mb:.2f} MB ({apk_size_bytes:,} bytes)")
    print(f"SHA-256 Digest : {sha256_hash}")
    print("-" * 80)
    
    results = []
    
    with zipfile.ZipFile(apk_path, "r") as zf:
        namelist = zf.namelist()
        
        # ---------------------------------------------------------------------
        # 1. MODEL ASSET & ZERO-COMPRESSION CHECK
        # ---------------------------------------------------------------------
        tflite_entries = [name for name in namelist if name.endswith(".tflite")]
        labels_entries = [name for name in namelist if name.endswith("labels.txt")]
        meta_entries = [name for name in namelist if name.endswith("model_meta.json")]
        
        if not tflite_entries:
            results.append(("1.1 TFLite Model Binary Present", "FAIL", "No .tflite model found in APK"))
        else:
            model_entry = tflite_entries[0]
            info = zf.getinfo(model_entry)
            is_uncompressed = (info.compress_type == zipfile.ZIP_STORED)
            status = "PASS" if is_uncompressed else "FAIL"
            comp_type_name = "ZIP_STORED (0 - Uncompressed)" if is_uncompressed else f"COMPRESSED ({info.compress_type})"
            results.append(("1.1 TFLite Model Binary Present", "PASS", f"{model_entry} ({info.file_size:,} bytes)"))
            results.append(("1.2 TFLite mmap Zero-Compression", status, f"compress_type={comp_type_name}"))
            
        if not labels_entries:
            results.append(("1.3 Labels File Present", "FAIL", "labels.txt missing from APK"))
        else:
            labels_content = zf.read(labels_entries[0]).decode("utf-8", errors="replace")
            lines = [l.strip() for l in labels_content.splitlines() if l.strip()]
            status = "PASS" if len(lines) == 45 else "FAIL"
            results.append(("1.3 Labels Contract (45 classes)", status, f"Exact class count: {len(lines)}/45"))
            
        if not meta_entries:
            results.append(("1.4 Model Metadata Present", "FAIL", "model_meta.json missing from APK"))
        else:
            meta_json = json.loads(zf.read(meta_entries[0]).decode("utf-8", errors="replace"))
            classes_meta = meta_json.get("num_classes", 0)
            status = "PASS" if classes_meta == 45 else "FAIL"
            results.append(("1.4 Model Metadata Valid", status, f"num_classes={classes_meta}, shape={meta_json.get('input_shape')}"))
            
        # ---------------------------------------------------------------------
        # 2. NATIVE LITERTE / TFLITE SHARED LIBRARIES CHECK
        # ---------------------------------------------------------------------
        arm64_so = [n for n in namelist if n.startswith("lib/arm64-v8a/") and n.endswith(".so")]
        arm32_so = [n for n in namelist if n.startswith("lib/armeabi-v7a/") and n.endswith(".so")]
        
        arm64_tflite = [n for n in arm64_so if "tensorflowlite" in n.lower() or "litert" in n.lower() or "tflite" in n.lower()]
        arm32_tflite = [n for n in arm32_so if "tensorflowlite" in n.lower() or "litert" in n.lower() or "tflite" in n.lower()]
        
        status_arm64 = "PASS" if arm64_tflite else "FAIL"
        status_arm32 = "PASS" if arm32_tflite else "FAIL"
        
        results.append(("2.1 Native arm64-v8a LiteRT / TFLite .so", status_arm64, ", ".join(arm64_tflite) if arm64_tflite else f"None (total {len(arm64_so)} SOs)"))
        results.append(("2.2 Native armeabi-v7a LiteRT / TFLite .so", status_arm32, ", ".join(arm32_tflite) if arm32_tflite else f"None (total {len(arm32_so)} SOs)"))
        
        # ---------------------------------------------------------------------
        # 3. OFFLINE VAULT & BRANDING ASSETS
        # ---------------------------------------------------------------------
        vault_entries = [n for n in namelist if "offline_icar_protocols.json" in n]
        branding_entries = [n for n in namelist if "kisansetu.jpg" in n]
        
        status_vault = "PASS" if vault_entries else "FAIL"
        status_brand = "PASS" if branding_entries else "FAIL"
        
        results.append(("3.1 Offline ICAR Knowledge Vault", status_vault, vault_entries[0] if vault_entries else "Missing"))
        results.append(("3.2 KisanSetu Branding Asset", status_brand, branding_entries[0] if branding_entries else "Missing"))
        
        # ---------------------------------------------------------------------
        # 4. MANIFEST PERMISSIONS & APP LABEL
        # ---------------------------------------------------------------------
        raw_manifest = zf.read("AndroidManifest.xml")
        
        def in_manifest(term):
            return (term.encode("utf-8") in raw_manifest) or (term.encode("utf-16le") in raw_manifest)

        has_fine_loc = in_manifest("ACCESS_FINE_LOCATION")
        has_coarse_loc = in_manifest("ACCESS_COARSE_LOCATION")
        has_camera = in_manifest("CAMERA")
        has_internet = in_manifest("INTERNET")
        has_label = in_manifest("KisanSetu")
        has_record_audio = in_manifest("RECORD_AUDIO")
        
        results.append(("4.1 ACCESS_FINE_LOCATION", "PASS" if has_fine_loc else "FAIL", "Present in Manifest"))
        results.append(("4.2 ACCESS_COARSE_LOCATION", "PASS" if has_coarse_loc else "FAIL", "Present in Manifest"))
        results.append(("4.3 CAMERA Permission", "PASS" if has_camera else "FAIL", "Present in Manifest"))
        results.append(("4.4 INTERNET Permission", "PASS" if has_internet else "FAIL", "Present in Manifest"))
        results.append(("4.5 android:label='KisanSetu'", "PASS" if has_label else "FAIL", "Present in Manifest"))
        results.append(("4.6 NO RECORD_AUDIO Permission", "PASS" if not has_record_audio else "FAIL", "Absent (No voice recording)" if not has_record_audio else "RECORD_AUDIO is present in Manifest!"))
        
    print(f"{'CHECK DESCRIPTION':<42} | {'STATUS':<6} | {'DETAILS'}")
    print("-" * 80)
    all_passed = True
    for desc, status, detail in results:
        print(f"{desc:<42} | {status:<6} | {detail}")
        if status != "PASS":
            all_passed = False
            
    print("-" * 80)
    if all_passed:
        print("[RESULT] ALL BINARY FORENSIC INSPECTION CHECKS PASSED.")
    else:
        print("[RESULT] ONE OR MORE BINARY FORENSIC CHECKS FAILED.")
        
    return all_passed

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_APK_PATH
    success = inspect_apk(target)
    sys.exit(0 if success else 1)
