#!/usr/bin/env python3
"""
FloraX Backend Vision Smoke Test (45-Class Dynamic EfficientNetV2 Engine)
Verifies:
1. Native Keras EfficientNetV2 functional model loads cleanly without compile.
2. GradientTape computes valid Grad-CAM heatmap on global_avg_pool.input.
3. 45-class direct probability distribution sums to 1.0.
4. /health endpoint returns modelStatus == 'trained', numClasses == 45, inputShape == [1, 224, 224, 3].
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
    print("FloraX Vision Backend Keras Grad-CAM Smoke Test (45-Class)")
    print("=" * 60)

    # 1. Check health
    health = health_check()
    print("1. /health response:", health)
    assert health["status"] == "online", "Server status must be online"
    assert health["modelStatus"] == "trained", "modelStatus must be trained"
    assert health["numClasses"] == 45, f"Expected 45 classes, got {health['numClasses']}"
    assert health["inputShape"] == [1, 224, 224, 3], f"Expected [1, 224, 224, 3], got {health['inputShape']}"
    print("   [PASS] /health assertions verified.")

    # 2. Check model layers
    model = vision_engine.model
    expected_layers = [
        "leaf_rgb_255",
        "efficientnetv2-b0",
        "global_avg_pool",
        "probabilities",
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
    assert len(canonical_probs) == 45, f"Expected 45 classes, got {len(canonical_probs)}"
    assert abs(sum(canonical_probs.values()) - 1.0) < 1e-4, "Probabilities must sum to 1.0"
    print("3. Grad-CAM heatmap min:", float(np.min(heatmap)), "max:", float(np.max(heatmap)))
    print("   45-class distribution count:", len(canonical_probs))
    print("   Sum of probabilities:", round(sum(canonical_probs.values()), 4))
    print("   [PASS] GradientTape Grad-CAM and 45-class distribution verified.")

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
    assert "affectedRegions" in result, "Must return affectedRegions"
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
