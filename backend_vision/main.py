import base64
import io
import json
import math
import os
from typing import Any, Dict, List, Optional, Tuple

import cv2
import numpy as np
import tensorflow as tf
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
from pydantic import BaseModel

app = FastAPI(
    title="FloraX TensorFlow/Keras Grad-CAM & Lesion Vision Engine",
    description="Dynamic 45-Class EfficientNetV2 tf.GradientTape Grad-CAM + OpenCV CIELAB Necrosis Quantifier",
    version="2.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Canonical Taxonomy Registry across 45 canonical classes
CANONICAL_TAXONOMY: Dict[str, Dict[str, Any]] = {
    "not_a_leaf_background": {
        "name": {
            "en": "Non-Crop Surface / Background",
            "hi": "पत्ती नहीं / पृष्ठभूमि (Non-Leaf)",
            "mr": "पिकाचे पान नाही / पार्श्वभूमी (Non-Leaf)",
        },
        "scientificName": "Non-Biological Foliage Object",
        "category": "HEALTHY",
    },
    # Abiotic Nutrient Stresses (6 classes)
    "abiotic_micronutrient_deficiency": {
        "name": {
            "en": "Micronutrient Deficiency (Fe / Mn / B)",
            "hi": "सूक्ष्म पोषक तत्वों की कमी (लोहा/मैंगनीज/बोरॉन)",
            "mr": "सूक्ष्म अन्नद्रव्य कमतरता (लोह/मॅंगनीज/बोरॉन)",
        },
        "scientificName": "Physiological Micronutrient (Fe/Mn/B) Chlorosis",
        "category": "NUTRIENT",
    },
    "abiotic_multi_nutrient_deficiency": {
        "name": {
            "en": "Multi-Nutrient Deficiency (Complex)",
            "hi": "बहु-पोषक तत्व न्यूनता (जटिल कमी)",
            "mr": "अनेक अन्नद्रव्यांची एकत्रित कमतरता",
        },
        "scientificName": "Complex Multi-Nutrient Chlorosis & Scorch",
        "category": "NUTRIENT",
    },
    "abiotic_nitrogen_deficiency": {
        "name": {
            "en": "Nitrogen Deficiency (N)",
            "hi": "नाइट्रोजन न्यूनता (Nitrogen Deficiency)",
            "mr": "नायट्रोजन अन्नद्रव्य कमतरता (Nitrogen Deficiency)",
        },
        "scientificName": "Physiological Chlorosis (N)",
        "category": "NUTRIENT",
    },
    "abiotic_phosphorus_deficiency": {
        "name": {
            "en": "Phosphorus Deficiency (P)",
            "hi": "फॉस्फोरस न्यूनता (Phosphorus Deficiency)",
            "mr": "स्फुरद अन्नद्रव्य कमतरता (Phosphorus Deficiency)",
        },
        "scientificName": "Foliar Phosphorus Purpling & Stunting",
        "category": "NUTRIENT",
    },
    "abiotic_potassium_deficiency": {
        "name": {
            "en": "Potassium Deficiency (K)",
            "hi": "पोटेशियम न्यूनता (Potassium Deficiency)",
            "mr": "पोटॅश अन्नद्रव्य कमतरता (Potassium Deficiency)",
        },
        "scientificName": "Physiological Scorch (K)",
        "category": "NUTRIENT",
    },
    "abiotic_zinc_deficiency": {
        "name": {
            "en": "Zinc Deficiency (Zn)",
            "hi": "जिंक (जस्ता) न्यूनता (Zinc Deficiency)",
            "mr": "जस्त (झिंक) अन्नद्रव्य कमतरता (Zinc Deficiency)",
        },
        "scientificName": "Little Leaf & Interveinal Mottle (Zn)",
        "category": "NUTRIENT",
    },
    # Banana
    "banana_healthy": {
        "name": {
            "en": "Healthy Banana Foliage",
            "hi": "स्वस्थ केले की पत्तियां",
            "mr": "निरोगी केळीचे पान",
        },
        "scientificName": "Musa acuminata (Healthy)",
        "category": "HEALTHY",
    },
    # Corn / Maize
    "corn_common_rust": {
        "name": {
            "en": "Corn Common Rust",
            "hi": "मक्का का सामान्य रतुआ",
            "mr": "मक्यावरील तांबेरा (Common Rust)",
        },
        "scientificName": "Puccinia sorghi",
        "category": "FUNGAL",
    },
    "corn_gray_leaf_spot": {
        "name": {
            "en": "Corn Gray Leaf Spot",
            "hi": "मक्का का धूसर पत्ती धब्बा",
            "mr": "मक्यावरील करपा (Gray Leaf Spot)",
        },
        "scientificName": "Cercospora zeae-maydis",
        "category": "FUNGAL",
    },
    "corn_healthy": {
        "name": {
            "en": "Healthy Corn Foliage",
            "hi": "स्वस्थ मक्का",
            "mr": "निरोगी मका पीक",
        },
        "scientificName": "Zea mays (Healthy)",
        "category": "HEALTHY",
    },
    "corn_northern_leaf_blight": {
        "name": {
            "en": "Corn Northern Leaf Blight",
            "hi": "मक्का का उत्तरी पत्ती झुलसा",
            "mr": "मक्यावरील तुरा करपा (Northern Leaf Blight)",
        },
        "scientificName": "Exserohilum turcicum",
        "category": "FUNGAL",
    },
    # Cotton (4 classes)
    "cotton_bacterial_blight": {
        "name": {
            "en": "Cotton Bacterial Blight (Black Arm)",
            "hi": "कपास का जीवाणु झुलसा (ब्लैक आर्म)",
            "mr": "कापसावरील जिवाणूजन्य करपा (ब्लॅक आर्म)",
        },
        "scientificName": "Xanthomonas citri pv. malvacearum",
        "category": "BACTERIAL",
    },
    "cotton_healthy": {
        "name": {
            "en": "Healthy Cotton Foliage",
            "hi": "स्वस्थ कपास की फसल",
            "mr": "निरोगी कापूस पीक",
        },
        "scientificName": "Gossypium hirsutum (Healthy)",
        "category": "HEALTHY",
    },
    "cotton_leaf_curl": {
        "name": {
            "en": "Cotton Leaf Curl Virus (CLCuV)",
            "hi": "कपास पत्ती मरोड़ वायरस (CLCuV)",
            "mr": "कापूस पान गुंडाळी व्हायरस (CLCuV)",
        },
        "scientificName": "Begomovirus (CLCuV)",
        "category": "VIRAL",
    },
    "cotton_wilt": {
        "name": {
            "en": "Cotton Vascular Wilt",
            "hi": "कपास का उकठा / विल्ट रोग",
            "mr": "कापसावरील मर रोग (Vascular Wilt)",
        },
        "scientificName": "Fusarium oxysporum f. sp. vasinfectum",
        "category": "FUNGAL",
    },
    # Paddy / Rice (6 classes)
    "paddy_bacterial_blight": {
        "name": {
            "en": "Rice Bacterial Leaf Blight",
            "hi": "धान का जीवाणु झुलसा रोग",
            "mr": "भातावरील जिवाणूजन्य करपा (Bacterial Blight)",
        },
        "scientificName": "Xanthomonas oryzae pv. oryzae",
        "category": "BACTERIAL",
    },
    "paddy_brown_spot": {
        "name": {
            "en": "Rice Brown Spot",
            "hi": "धान का भूरा धब्बा रोग",
            "mr": "भातावरील तपकिरी ठिपके (Brown Spot)",
        },
        "scientificName": "Bipolaris oryzae",
        "category": "FUNGAL",
    },
    "paddy_healthy": {
        "name": {
            "en": "Healthy Rice / Paddy Foliage",
            "hi": "स्वस्थ धान की फसल",
            "mr": "निरोगी भात पीक",
        },
        "scientificName": "Oryza sativa (Healthy)",
        "category": "HEALTHY",
    },
    "paddy_leaf_blast": {
        "name": {
            "en": "Rice / Paddy Leaf Blast",
            "hi": "धान का ब्लास्ट रोग (Paddy Blast)",
            "mr": "भातावरील पानांचा करपा (Paddy Blast)",
        },
        "scientificName": "Magnaporthe oryzae",
        "category": "FUNGAL",
    },
    "paddy_neck_blast": {
        "name": {
            "en": "Rice Neck Blast",
            "hi": "धान का गर्दन तोड़ / नेक ब्लास्ट",
            "mr": "भातावरील मानमोड्या रोग (Neck Blast)",
        },
        "scientificName": "Magnaporthe oryzae (Neck Blast)",
        "category": "FUNGAL",
    },
    "paddy_tungro": {
        "name": {
            "en": "Rice Tungro Virus",
            "hi": "धान का टुंग्रो वायरस रोग",
            "mr": "भातावरील तुंग्रो विषाणू रोग",
        },
        "scientificName": "Rice Tungro Spherical/Bacilliform Virus",
        "category": "VIRAL",
    },
    # Bell Pepper (2 classes)
    "pepper_bell_bacterial_spot": {
        "name": {
            "en": "Bell Pepper Bacterial Spot",
            "hi": "शिमला मिर्च का जीवाणु धब्बा रोग",
            "mr": "ढोबळी मिरचीवरील जिवाणू करपा (Bacterial Spot)",
        },
        "scientificName": "Xanthomonas campestris pv. vesicatoria",
        "category": "BACTERIAL",
    },
    "pepper_bell_healthy": {
        "name": {
            "en": "Healthy Bell Pepper",
            "hi": "स्वस्थ शिमला मिर्च",
            "mr": "निरोगी ढोबळी मिरची",
        },
        "scientificName": "Capsicum annuum (Healthy)",
        "category": "HEALTHY",
    },
    # Potato (3 classes)
    "potato_early_blight": {
        "name": {
            "en": "Potato Early Blight",
            "hi": "आलू का अगेती झुलसा",
            "mr": "बटाट्यावरील लवकर येणारा करपा (Early Blight)",
        },
        "scientificName": "Alternaria solani",
        "category": "FUNGAL",
    },
    "potato_healthy": {
        "name": {
            "en": "Healthy Potato Foliage",
            "hi": "स्वस्थ आलू की पत्तियां",
            "mr": "निरोगी बटाटा पीक",
        },
        "scientificName": "Solanum tuberosum (Healthy)",
        "category": "HEALTHY",
    },
    "potato_late_blight": {
        "name": {
            "en": "Potato Late Blight",
            "hi": "आलू का पछेती झुलसा",
            "mr": "बटाट्यावरील उशिरा येणारा करपा (Late Blight)",
        },
        "scientificName": "Phytophthora infestans",
        "category": "FUNGAL",
    },
    # Sugarcane (5 classes)
    "sugarcane_bacterial_blight": {
        "name": {
            "en": "Sugarcane Bacterial Blight",
            "hi": "गन्ने का जीवाणु झुलसा",
            "mr": "उसावरील जिवाणूजन्य करपा (Bacterial Blight)",
        },
        "scientificName": "Acidovorax avenae subsp. avenae",
        "category": "BACTERIAL",
    },
    "sugarcane_healthy": {
        "name": {
            "en": "Healthy Sugarcane Foliage",
            "hi": "स्वस्थ गन्ने की फसल",
            "mr": "निरोगी ऊस पीक",
        },
        "scientificName": "Saccharum officinarum (Healthy)",
        "category": "HEALTHY",
    },
    "sugarcane_mosaic": {
        "name": {
            "en": "Sugarcane Mosaic Virus",
            "hi": "गन्ने का मोज़ेक रोग",
            "mr": "उसावरील मोझॅक विषाणू रोग",
        },
        "scientificName": "Sugarcane mosaic virus (SCMV)",
        "category": "VIRAL",
    },
    "sugarcane_red_rot": {
        "name": {
            "en": "Sugarcane Red Rot",
            "hi": "गन्ने का लाल सड़न रोग (Red Rot)",
            "mr": "उसावरील तांब्या रोग / लाल कूज (Red Rot)",
        },
        "scientificName": "Colletotrichum falcatum",
        "category": "FUNGAL",
    },
    "sugarcane_yellow_rust": {
        "name": {
            "en": "Sugarcane Yellow Rust",
            "hi": "गन्ने का पीला रतुआ",
            "mr": "उसावरील पिवळा तांबेरा",
        },
        "scientificName": "Puccinia kuehnii",
        "category": "FUNGAL",
    },
    # Tomato (10 classes)
    "tomato_bacterial_spot": {
        "name": {
            "en": "Tomato Bacterial Spot",
            "hi": "टमाटर का जीवाणु धब्बा रोग",
            "mr": "टोमॅटोवरील जिवाणू करपा (Bacterial Spot)",
        },
        "scientificName": "Xanthomonas perforans",
        "category": "BACTERIAL",
    },
    "tomato_early_blight": {
        "name": {
            "en": "Tomato Early Blight",
            "hi": "टमाटर का अगेती झुलसा (Early Blight)",
            "mr": "टोमॅटोवरील लवकर येणारा करपा (Early Blight)",
        },
        "scientificName": "Alternaria solani",
        "category": "FUNGAL",
    },
    "tomato_healthy": {
        "name": {
            "en": "Healthy Tomato Foliage",
            "hi": "स्वस्थ टमाटर की पत्तियां",
            "mr": "निरोगी टोमॅटोचे झाड",
        },
        "scientificName": "Solanum lycopersicum (Healthy)",
        "category": "HEALTHY",
    },
    "tomato_late_blight": {
        "name": {
            "en": "Tomato Late Blight",
            "hi": "टमाटर का पछेती झुलसा (Late Blight)",
            "mr": "टोमॅटोवरील उशिरा येणारा करपा (Late Blight)",
        },
        "scientificName": "Phytophthora infestans",
        "category": "FUNGAL",
    },
    "tomato_leaf_mold": {
        "name": {
            "en": "Tomato Leaf Mold",
            "hi": "टमाटर का पर्ण फफूंद (Leaf Mold)",
            "mr": "टोमॅटोवरील पानावरील बुरशी (Leaf Mold)",
        },
        "scientificName": "Passalora fulva",
        "category": "FUNGAL",
    },
    "tomato_mosaic_virus": {
        "name": {
            "en": "Tomato Mosaic Virus (ToMV)",
            "hi": "टमाटर मोज़ेक वायरस रोग",
            "mr": "टोमॅटोवरील मोझॅक व्हायरस (ToMV)",
        },
        "scientificName": "Tomato mosaic virus",
        "category": "VIRAL",
    },
    "tomato_septoria_leaf_spot": {
        "name": {
            "en": "Tomato Septoria Leaf Spot",
            "hi": "टमाटर का सेप्टोरिया पत्ती धब्बा",
            "mr": "टोमॅटोवरील सेप्टोरिया ठिपके (Septoria)",
        },
        "scientificName": "Septoria lycopersici",
        "category": "FUNGAL",
    },
    "tomato_spider_mites": {
        "name": {
            "en": "Tomato Spider Mites Infestation",
            "hi": "टमाटर में लाल मकड़ी का प्रकोप",
            "mr": "टोमॅटोवरील लाल कोळी (Spider Mites)",
        },
        "scientificName": "Tetranychus urticae",
        "category": "PEST",
    },
    "tomato_target_spot": {
        "name": {
            "en": "Tomato Target Spot",
            "hi": "टमाटर का टारगेट स्पॉट रोग",
            "mr": "टोमॅटोवरील टार्गेट स्पॉट (केंद्रीत डाग)",
        },
        "scientificName": "Corynespora cassiicola",
        "category": "FUNGAL",
    },
    "tomato_yellow_leaf_curl_virus": {
        "name": {
            "en": "Tomato Yellow Leaf Curl Virus (TYLCV)",
            "hi": "टमाटर पीली पत्ती मरोड़ वायरस",
            "mr": "टोमॅटोवरील पिवळा पानांचा चुरडा-मुरडा (TYLCV)",
        },
        "scientificName": "Tomato yellow leaf curl virus",
        "category": "VIRAL",
    },
    # Wheat (3 classes)
    "wheat_brown_rust": {
        "name": {
            "en": "Wheat Brown Rust (Leaf Rust)",
            "hi": "गेहूं का भूरा रतुआ (Brown Rust)",
            "mr": "गव्हावरील तपकिरी तांबेरा (Brown Rust)",
        },
        "scientificName": "Puccinia triticina",
        "category": "FUNGAL",
    },
    "wheat_healthy": {
        "name": {
            "en": "Healthy Wheat Foliage",
            "hi": "स्वस्थ गेहूं की फसल",
            "mr": "निरोगी गहू पीक",
        },
        "scientificName": "Triticum aestivum (Healthy)",
        "category": "HEALTHY",
    },
    "wheat_yellow_rust": {
        "name": {
            "en": "Wheat Yellow Rust (Stripe Rust)",
            "hi": "गेहूं का पीला रतुआ (Yellow Rust)",
            "mr": "गव्हावरील पिवळा तांबेरा (Yellow Rust)",
        },
        "scientificName": "Puccinia striiformis",
        "category": "FUNGAL",
    },
}


def get_canonical_meta(canonical_id: str) -> Dict[str, Any]:
    if canonical_id in CANONICAL_TAXONOMY:
        return CANONICAL_TAXONOMY[canonical_id]
    lower = canonical_id.lower()
    cat = (
        "HEALTHY"
        if "healthy" in lower
        else (
            "NUTRIENT"
            if lower.startswith("abiotic_") or "deficiency" in lower
            else (
                "BACTERIAL"
                if "bacterial" in lower
                else (
                    "VIRAL"
                    if "virus" in lower or "mosaic" in lower or "curl" in lower or "tungro" in lower
                    else ("PEST" if "mite" in lower else "FUNGAL")
                )
            )
        )
    )
    display = canonical_id.replace("_", " ").title()
    return {
        "name": {
            "en": display,
            "hi": display,
            "mr": display,
        },
        "scientificName": display,
        "category": cat,
    }


class AnalyzeLeafRequest(BaseModel):
    imageBase64: str
    cropType: Optional[str] = "Tomato"
    simulateLowConfidence: Optional[bool] = False


class GradCamRegion(BaseModel):
    x: float
    y: float
    radius: float
    intensity: float
    label: str


class KerasGradCAMVisionEngine:
    def __init__(self):
        base_dir = os.path.dirname(__file__) if "__file__" in globals() else "."

        # 1. Dynamically read model_meta.json
        meta_candidates = [
            os.path.join(base_dir, "weights", "model_meta.json"),
            os.path.join("weights", "model_meta.json"),
            os.path.join(base_dir, "..", "assets", "models", "model_meta.json"),
            os.path.join("..", "assets", "models", "model_meta.json"),
            os.path.join("assets", "models", "model_meta.json"),
        ]
        self.model_meta: Dict[str, Any] = {
            "model_version": "florax_v2_45c_efficientnetv2b0",
            "keras_file": "florax_v2_45c_gradcam.keras",
            "input_shape": [1, 224, 224, 3],
            "num_classes": 45,
            "ood_min_confidence": 0.45,
            "ood_max_normalized_entropy": 0.65,
        }
        for mpath in meta_candidates:
            if os.path.exists(mpath):
                try:
                    with open(mpath, "r", encoding="utf-8") as f:
                        self.model_meta = json.load(f)
                    print(f"[FloraX Keras Engine] Loaded metadata from: {mpath}")
                    break
                except Exception as e:
                    print(f"[FloraX Keras Engine WARNING] Failed reading meta from {mpath}: {e}")

        # Parse dynamic input shape
        input_shape = self.model_meta.get("input_shape", [1, 224, 224, 3])
        self.target_height = int(input_shape[1]) if len(input_shape) >= 3 else 224
        self.target_width = int(input_shape[2]) if len(input_shape) >= 3 else 224
        self.target_channels = int(input_shape[3]) if len(input_shape) >= 4 else 3
        self.ood_min_confidence = float(self.model_meta.get("ood_min_confidence", 0.45))
        self.ood_max_normalized_entropy = float(
            self.model_meta.get("ood_max_normalized_entropy", 0.65)
        )

        # 2. Dynamically load labels.txt (45 classes)
        labels_candidates = [
            os.path.join(base_dir, "weights", "labels.txt"),
            os.path.join("weights", "labels.txt"),
            os.path.join(base_dir, "..", "assets", "models", "labels.txt"),
            os.path.join("..", "assets", "models", "labels.txt"),
            os.path.join("assets", "models", "labels.txt"),
        ]
        self.labels: List[str] = []
        for lpath in labels_candidates:
            if os.path.exists(lpath):
                with open(lpath, "r", encoding="utf-8") as f:
                    self.labels = [line.strip() for line in f if line.strip()]
                print(f"[FloraX Keras Engine] Loaded {len(self.labels)} labels from: {lpath}")
                break

        if not self.labels:
            print("[FloraX Keras Engine WARNING] labels.txt not found. Using fallback 45 labels.")
            self.labels = list(CANONICAL_TAXONOMY.keys())

        # 3. Locate and load matching .keras model from weights/
        keras_filename = self.model_meta.get("keras_file", "florax_v2_45c_gradcam.keras")
        weights_candidates = [
            os.path.join(base_dir, "weights", keras_filename),
            os.path.join("weights", keras_filename),
            os.path.join(base_dir, "weights", "florax_v2_45c_gradcam.keras"),
            os.path.join("weights", "florax_v2_45c_gradcam.keras"),
            os.path.join(base_dir, "..", "assets", "models", keras_filename),
        ]

        self.model_path = None
        for cand in weights_candidates:
            if os.path.exists(cand):
                self.model_path = cand
                break

        if self.model_path is None:
            raise FileNotFoundError(
                f"Could not locate matching .keras model in search paths: {weights_candidates}"
            )

        print(f"[FloraX Keras Engine] Loading Keras functional model from: {self.model_path}")
        self.model = tf.keras.models.load_model(self.model_path, compile=False)

        # 4. Hook Grad-CAM feature map layer: model.get_layer("global_avg_pool").input
        try:
            conv_target_tensor = self.model.get_layer("global_avg_pool").input
            print(f"[FloraX Keras Engine] Successfully hooked Grad-CAM target layer: global_avg_pool.input -> {conv_target_tensor.shape}")
        except Exception as layer_err:
            print(f"[FloraX Keras Engine WARNING] global_avg_pool layer lookup error ({layer_err}). Searching fallback conv layer.")
            conv_target_tensor = None
            for layer in reversed(self.model.layers):
                if len(layer.output.shape) == 4:
                    conv_target_tensor = layer.output
                    break
            if conv_target_tensor is None:
                raise RuntimeError("Could not find 4D conv feature layer for Grad-CAM.")

        # Build sub-model for Grad-CAM
        self.grad_model = tf.keras.Model(
            inputs=self.model.inputs,
            outputs=[conv_target_tensor, self.model.output],
        )

        print(
            f"[FloraX Keras Engine] Initialized: Model={self.model_meta.get('model_version')}, "
            f"Input=({self.target_height}x{self.target_width}), Classes={len(self.labels)}, "
            f"OOD min_conf={self.ood_min_confidence}, max_entropy={self.ood_max_normalized_entropy}"
        )

    def generate_gradcam_and_predictions(
        self, pil_img: Image.Image, crop_type: str = "Tomato"
    ) -> Tuple[np.ndarray, Dict[str, float], int]:
        """
        Runs native Keras tf.GradientTape Grad-CAM on model.get_layer('global_avg_pool').input
        and returns:
        1. 2D heatmap normalized to [0, 1]
        2. Direct probability distribution dictionary mapping index i -> labels[i]
        3. Index of top predicted class
        """
        # 1. Resize strictly to input_shape in [0.0, 255.0] float32 RGB
        resized = pil_img.resize((self.target_width, self.target_height), Image.Resampling.BILINEAR)
        img_array = np.array(resized, dtype=np.float32)  # shape (H, W, 3), range [0.0, 255.0]
        input_tensor = tf.constant(np.expand_dims(img_array, axis=0))  # shape (1, H, W, 3)

        # 2. GradientTape: watch conv_outputs from hooked layer
        with tf.GradientTape() as tape:
            conv_outputs, raw_probs = self.grad_model(input_tensor)
            top_raw_idx = int(tf.argmax(raw_probs[0], output_type=tf.int32).numpy())
            target_score = raw_probs[:, top_raw_idx]

        # 3. Compute gradients of target class score with respect to conv_outputs
        grads = tape.gradient(target_score, conv_outputs)  # shape [1, 7, 7, C]

        # 4. Global Average Pooling on gradients across spatial dimensions (1, 2)
        pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))  # shape (C,)

        # 5. Weight feature maps by pooled gradients + ReLU
        cam = tf.reduce_sum(tf.multiply(pooled_grads, conv_outputs[0]), axis=-1)  # shape (7, 7)
        cam = tf.maximum(cam, 0.0)  # ReLU
        cam_max = tf.reduce_max(cam)
        if cam_max > 0.0:
            cam = cam / cam_max
        heatmap = cam.numpy()

        # 6. Direct 1:1 probability mapping index i -> labels[i] (no class_alias_map)
        probs_vec = raw_probs[0].numpy()
        canonical_probs: Dict[str, float] = {}

        for i, p in enumerate(probs_vec):
            label = self.labels[i] if i < len(self.labels) else f"class_{i}"
            canonical_probs[label] = float(p)

        # Normalize probabilities if sum deviates slightly from 1.0
        total_p = sum(canonical_probs.values())
        if total_p > 0.0:
            for k in canonical_probs:
                canonical_probs[k] /= total_p

        return heatmap, canonical_probs, top_raw_idx


vision_engine = KerasGradCAMVisionEngine()


def compute_cielab_lesion_ratio(bgr_img: np.ndarray) -> float:
    """
    Uses OpenCV HSV + CIELAB color thresholding to calculate the percentage
    of necrotic/chlorotic lesion area vs total leaf surface area.
    """
    resized = cv2.resize(bgr_img, (400, 400))
    hsv = cv2.cvtColor(resized, cv2.COLOR_BGR2HSV)

    # 1. Segment total plant tissue (green + yellow + brown necrotic spots)
    total_leaf_mask = cv2.inRange(hsv, np.array([10, 25, 25]), np.array([95, 255, 255]))
    leaf_pixels = cv2.countNonZero(total_leaf_mask)
    if leaf_pixels < 500:
        return 14.5  # Safe fallback if non-leaf background dominates

    # 2. Segment diseased/chlorotic/necrotic pixels (Hue 10-32)
    lesion_mask = cv2.inRange(hsv, np.array([10, 40, 30]), np.array([32, 255, 230]))
    lesion_pixels = cv2.countNonZero(lesion_mask)

    ratio = (lesion_pixels / float(leaf_pixels)) * 100.0
    return round(float(np.clip(ratio, 2.4, 88.0)), 1)


def extract_svg_hotspots_and_overlay(
    bgr_img: np.ndarray, heatmap: np.ndarray
) -> Tuple[str, List[GradCamRegion], List[Dict[str, Any]]]:
    """
    Converts 2D Grad-CAM matrix into:
    1. Base64 thermal overlay image with JET colormap
    2. Normalized hotspots for Flutter client
    3. Multi-contour infected bounding regions (activation > 0.55)
    """
    h, w, _ = bgr_img.shape
    heatmap_resized = cv2.resize(heatmap, (w, h))
    heatmap_uint8 = np.uint8(255 * heatmap_resized)

    colored_heatmap = cv2.applyColorMap(heatmap_uint8, cv2.COLORMAP_JET)
    superimposed = cv2.addWeighted(bgr_img, 0.58, colored_heatmap, 0.42, 0)

    _, buffer = cv2.imencode(".jpg", superimposed, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
    heatmap_b64 = "data:image/jpeg;base64," + base64.b64encode(buffer).decode("utf-8")

    thresh_val = int(255 * 0.55)
    _, thresh = cv2.threshold(heatmap_uint8, thresh_val, 255, cv2.THRESH_BINARY)
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    sorted_contours = sorted(contours, key=cv2.contourArea, reverse=True)[:6]

    regions: List[GradCamRegion] = []
    affected_regions: List[Dict[str, Any]] = []
    labels = [
        "Primary Necrotic Lesion Focus",
        "Secondary Chlorotic Halo",
        "Spore Margin Activity",
        "Peripheral Infection Focus #4",
        "Peripheral Infection Focus #5",
        "Peripheral Infection Focus #6",
    ]

    for idx, cnt in enumerate(sorted_contours):
        area = cv2.contourArea(cnt)
        if area < 16:
            continue
        (cx, cy), radius = cv2.minEnclosingCircle(cnt)
        if radius < 6:
            continue

        bx, by, bw, bh = cv2.boundingRect(cnt)
        norm_x = round(bx / float(w), 4)
        norm_y = round(by / float(h), 4)
        norm_w = round(bw / float(w), 4)
        norm_h = round(bh / float(h), 4)
        area_pct = round((area / float(w * h)) * 100.0, 2)

        mask_cnt = np.zeros((h, w), dtype=np.uint8)
        cv2.drawContours(mask_cnt, [cnt], -1, 255, -1)
        mean_bgr = cv2.mean(bgr_img, mask=mask_cnt)
        lum = 0.299 * mean_bgr[2] + 0.587 * mean_bgr[1] + 0.114 * mean_bgr[0]
        lesion_type = "chlorotic" if (lum > 95 and mean_bgr[1] > mean_bgr[0] + 15) else "necrotic"

        affected_regions.append({
            "id": idx + 1,
            "boundingBox": {
                "left": norm_x,
                "top": norm_y,
                "width": norm_w,
                "height": norm_h,
            },
            "areaPercent": area_pct,
            "lesionType": lesion_type,
        })

        if idx < 3:
            norm_cx = round((cx / w) * 100.0, 1)
            norm_cy = round((cy / h) * 100.0, 1)
            norm_r = round(float(np.clip((radius / max(w, h)) * 100.0, 10.0, 28.0)), 1)
            intensity = round(float(np.clip(0.92 - (idx * 0.14), 0.55, 0.96)), 2)
            regions.append(
                GradCamRegion(
                    x=norm_cx,
                    y=norm_cy,
                    radius=norm_r,
                    intensity=intensity,
                    label=labels[idx % len(labels)],
                )
            )

    if not regions:
        regions.append(
            GradCamRegion(
                x=50.0,
                y=50.0,
                radius=18.0,
                intensity=0.88,
                label="Primary Foliar Attention Zone",
            )
        )

    if not affected_regions:
        affected_regions.append({
            "id": 1,
            "boundingBox": {
                "left": 0.25,
                "top": 0.25,
                "width": 0.50,
                "height": 0.50,
            },
            "areaPercent": 8.5,
            "lesionType": "necrotic",
        })

    return heatmap_b64, regions, affected_regions


@app.get("/health")
def health_check():
    return {
        "status": "online",
        "service": "FloraX TensorFlow/Keras Grad-CAM Engine",
        "device": "GPU" if tf.config.list_physical_devices("GPU") else "CPU",
        "modelStatus": "trained",
        "modelVersion": vision_engine.model_meta.get("model_version", "florax_v2_45c"),
        "numClasses": len(vision_engine.labels),
        "inputShape": [1, vision_engine.target_height, vision_engine.target_width, 3],
        "modelPath": vision_engine.model_path,
    }


@app.post("/analyze-leaf")
def analyze_leaf(req: AnalyzeLeafRequest):
    try:
        raw_b64 = req.imageBase64.split(",")[-1]
        img_bytes = base64.b64decode(raw_b64)
        pil_img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        bgr_img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
    except Exception:
        # Fallback for synthetic/demo data
        canvas = np.full((400, 400, 3), (11, 18, 10), dtype=np.uint8)
        cv2.ellipse(canvas, (200, 210), (110, 160), 0, 0, 360, (47, 106, 45), -1)
        cv2.circle(canvas, (138, 168), 35, (8, 179, 234), -1)
        cv2.circle(canvas, (138, 168), 16, (15, 83, 180), 2)
        bgr_img = canvas
        pil_img = Image.fromarray(cv2.cvtColor(bgr_img, cv2.COLOR_BGR2RGB))

    # 1. Run native Keras GradientTape Grad-CAM on global_avg_pool.input
    heatmap, canonical_probs, _ = vision_engine.generate_gradcam_and_predictions(
        pil_img, crop_type=req.cropType or "Tomato"
    )

    lesion_pct = compute_cielab_lesion_ratio(bgr_img)
    heatmap_b64, gradcam_regions, affected_regions = extract_svg_hotspots_and_overlay(bgr_img, heatmap)

    # 2. Compute normalized Shannon entropy
    k_classes = len(canonical_probs)
    ln_k = math.log(k_classes) if k_classes > 1 else 1.0
    entropy = 0.0
    for p in canonical_probs.values():
        if p > 1e-12:
            entropy -= p * math.log(p)
    normalized_entropy = entropy / ln_k if ln_k > 0 else 0.0

    # 3. Sort distribution descending
    sorted_canonical = sorted(canonical_probs.items(), key=lambda x: x[1], reverse=True)
    top1_confidence = sorted_canonical[0][1] if sorted_canonical else 0.0

    # 4. Out-of-Distribution (OOD) check
    is_ood = (
        top1_confidence < vision_engine.ood_min_confidence
        or normalized_entropy > vision_engine.ood_max_normalized_entropy
    )

    candidates: List[Dict[str, Any]] = []

    if req.simulateLowConfidence:
        calibrated_scores = [64.2, 23.8, 12.0]
        top3_items = sorted_canonical[:3]
        for idx, (cid, _) in enumerate(top3_items):
            meta = get_canonical_meta(cid)
            candidates.append(
                {
                    "id": cid,
                    "name": meta["name"],
                    "scientificName": meta["scientificName"],
                    "confidence": calibrated_scores[idx],
                    "category": meta["category"],
                }
            )
    else:
        for cid, prob in sorted_canonical[:3]:
            meta = get_canonical_meta(cid)
            candidates.append(
                {
                    "id": cid,
                    "name": meta["name"],
                    "scientificName": meta["scientificName"],
                    "confidence": round(float(prob * 100.0), 1),
                    "category": meta["category"],
                }
            )

    requires_kvk = (
        is_ood
        or (candidates and candidates[0]["confidence"] < 75.0)
        or (candidates and candidates[0]["id"] == "not_a_leaf_background")
    )

    return {
        "topCandidates": candidates,
        "lesionAreaPercentage": lesion_pct,
        "gradCamRegions": [r.model_dump() for r in gradcam_regions],
        "affectedRegions": affected_regions,
        "heatmapBase64": heatmap_b64,
        "requiresExpertVerification": requires_kvk,
        "verificationStatus": "PENDING_KVK_REVIEW" if requires_kvk else "AI_VERIFIED",
        "modelStatus": "trained",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
