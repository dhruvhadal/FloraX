#!/usr/bin/env python3
"""
FloraX Backend Vision Smoke Test
Verifies:
1. Native Keras MobileNetV2 functional model loads cleanly without compile.
2. GradientTape computes valid Grad-CAM heatmap on test array.
3. Class alias map merges 69 raw probabilities to 50 canonical classes.
4. /health endpoint returns modelStatus == 'trained', numRawClasses == 69, numCanonicalClasses == 50.
5. /analyze-leaf generates non-empty Base64 heatmap and correct response payload.
"""

import base64
import io
import os
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from main import app, vision_engine, health_check, analyze_leaf, AnalyzeLeafRequest

def run_smoke_test():
    print("=" * 60)
    print("FloraX Vision Backend Keras Grad-CAM Smoke Test")
    print("=" * 60)

    # 1. Check health
    health = health_check()
    print("1. /health response:", health)
    assert health["status"] == "online", "Server status must be online"
    assert health["modelStatus"] == "trained", "modelStatus must be trained"
    assert health["numRawClasses"] == 69, f"Expected 69 raw classes, got {health['numRawClasses']}"
    assert health["numCanonicalClasses"] == 50, f"Expected 50 canonical classes, got {health['numCanonicalClasses']}"
    print("   [PASS] /health assertions verified.")

    # 2. Check model layers
    model = vision_engine.model
    expected_layers = [
        "leaf_rgb_255",
        "mobilenetv2_rescale",
        "mobilenetv2_1.00_224",
        "global_average_pooling2d",
        "dense",
    ]
    actual_layers = [layer.name for layer in model.layers]
    for el in expected_layers:
        assert el in actual_layers, f"Layer {el} missing from Keras model"
    print("2. Layer topology verified:", actual_layers)
    print("   [PASS] Model architecture verified.")

    # 3. Test Grad-CAM computation on synthetic test image
    test_img = Image.new("RGB", (320, 320), color=(60, 150, 45))
    heatmap, canonical_probs, top_raw_idx = vision_engine.generate_gradcam_and_predictions(test_img)
    assert heatmap is not None, "Heatmap must not be None"
    assert heatmap.shape == (7, 7), f"Expected heatmap shape (7, 7), got {heatmap.shape}"
    assert len(canonical_probs) == 50, f"Expected 50 canonical probabilities, got {len(canonical_probs)}"
    assert abs(sum(canonical_probs.values()) - 1.0) < 1e-4, "Merged canonical probabilities must sum to 1.0"
    print("3. Grad-CAM heatmap min:", float(np.min(heatmap)), "max:", float(np.max(heatmap)))
    print("   Merged canonical classes count:", len(canonical_probs))
    print("   Sum of merged probabilities:", round(sum(canonical_probs.values()), 4))
    print("   [PASS] GradientTape Grad-CAM and alias probability merging verified.")

    # 4. Test /analyze-leaf with synthetic leaf
    buf = io.BytesIO()
    test_img.save(buf, format="JPEG")
    b64_payload = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode("utf-8")

    req = AnalyzeLeafRequest(imageBase64=b64_payload, cropType="Tomato")
    result = analyze_leaf(req)

    assert result["modelStatus"] == "trained", "Result modelStatus must be trained"
    assert len(result["topCandidates"]) >= 1, "Must return at least 1 candidate"
    assert len(result["heatmapBase64"]) > 100, "Must return valid non-empty Base64 heatmap"
    assert result["heatmapBase64"].startswith("data:image/jpeg;base64,"), "Heatmap must be JPEG data URL"
    assert len(result["gradCamRegions"]) >= 1, "Must return at least 1 Grad-CAM attention region"
    assert "affectedRegions" in result, "Must return affectedRegions for Feature #1"
    assert len(result["affectedRegions"]) >= 1, "Must return at least 1 affected multi-contour region"
    assert "boundingBox" in result["affectedRegions"][0], "Region must have boundingBox"

    print("4. /analyze-leaf result:")
    print("   modelStatus:", result["modelStatus"])
    print("   topCandidate:", result["topCandidates"][0]["id"], f"({result['topCandidates'][0]['confidence']}%)")
    print("   scientificName:", result["topCandidates"][0]["scientificName"])
    print("   category:", result["topCandidates"][0]["category"])
    print("   lesionAreaPercentage:", result["lesionAreaPercentage"], "%")
    print("   heatmapBase64 length:", len(result["heatmapBase64"]))
    print("   verificationStatus:", result["verificationStatus"])
    print("   [PASS] /analyze-leaf endpoint verified.")

    print("=" * 60)
    print("ALL SMOKE TESTS PASSED CLEANLY (100% SUCCESS)!")
    print("=" * 60)

if __name__ == "__main__":
    run_smoke_test()
