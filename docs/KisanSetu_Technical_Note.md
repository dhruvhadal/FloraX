# KisanSetu — Technical Architecture & Evaluation Note
**Srujan 2026 × L&T EduTech | Phase 1 Online Judging | Track T1 (AI) — Problem AI-05: Crop Disease Identification**

## 1. Problem-Solution Alignment (`AI-05`)
Problem **AI-05** demands early visible crop disease identification with approved treatment advisories. **KisanSetu** overcomes rural zero-connectivity gaps and fungicide misuse via an offline `45`-class Edge LiteRT classifier (`11.41 MB`), a deterministic 4-state clinical safety router, and bundled ICAR/SAU protocols across `EN | हिन्दी | मराठी`.

## 2. System Architecture & Hybrid Data Flow
`Leaf Capture (Camera/Gallery) -> EXIF Bake & [0,255] Float32 Resize -> Edge LiteRT Isolate (2-View TTA) -> 4-State Clinical Safety Router -> Offline ICAR/SAU Vault & Firestore Sync + Async FastAPI Grad-CAM XAI`

- **Layered Flutter MVVM:** Separates Riverpod state notifiers, domain clinical evaluators (`ClinicalDiagnosisDecision`), and isolated inference/data layers.
- **Offline-First Vault & Cloud Sync:** Bundles `48` ICAR/SAU protocols (`offline_icar_protocols.json`, `100%` class coverage) alongside offline-cached Cloud Firestore collections (`farmers`, `scan_logs`, `icar_ipm_protocols`, `regional_outbreaks`, `experts`, `consultations`, `assistance_applications`, plus `user_crops`, `available_programs`, `ngo_directory`).
- **Stateless XAI Fallback:** FastAPI service (`GET /health`, `POST /api/v1/gradcam`) executes full-precision Keras Grad-CAM and OpenCV CIELAB lesion quantification.

## 3. AI/ML Pipeline & Verified Model Benchmarks
| Pipeline Dimension | Verified Ground-Truth Specification & Benchmarks |
|---|---|
| **Dataset Hygiene & Taxonomy** | Consolidated PlantVillage, PlantDoc, OLID-I, ICAR/SAU crop, nutrient & non-leaf corpora (`1,842` MD5 duplicates purged); `45` canonical 1-to-1 classes across `9` crops (Tomato, Paddy, Sugarcane, Corn, Cotton, Potato, Wheat, Bell Pepper, Banana), `6` `abiotic_*` stresses, and `1` OOD (`not_a_leaf_background`). |
| **Active Edge Model** | `florax_v2_45c_efficientnetv2b0` (`EfficientNetV2-B0`, `include_preprocessing=True`), `florax_v2_45c_fp16.tflite` (`11.41 MB`), `[1, 224, 224, 3]` Float32 `[0, 255]`, 2-View TTA. |
| **Verified Metrics & XAI** | **87.28%** Test Top-1 (`90.85%` Val), **96.65%** Test Top-3, **58.67%** outdoor field subset, **100.00%** OOD rejection; Softmax Sum = `1.000000`, Keras↔TFLite Max Diff `<= 0.000250`; Grad-CAM (`florax_v2_45c_gradcam.keras`, `23.71 MB`) via `tf.GradientTape` on `global_avg_pool.input`. |

## 4. Deterministic 4-State Clinical Safety Guardrails
| Safety State | Trigger Condition | Clinical & UX Action | Chemical Tab |
|---|---|---|---|
| **1. OOD Rejection** | `not_a_leaf_background` \| `conf < 0.45` \| `normEntropy > 0.65` | Blocks diagnosis; triggers guided camera retake. | **LOCKED** |
| **2. Abiotic Nutrient Stress** | `canonicalId.startsWith('abiotic_')` | Soil/foliar nutrient protocol; blocks fungicides. | **LOCKED** (`0 g/L`) |
| **3. Needs Review** | Biotic class & `conf < 0.75` | Top-3 differential + KVK Agri Experts link. | **LOCKED** |
| **4. Confirmed Advisory** | Biotic `conf >= 0.75` or `*_healthy` | 3-Tier Cultural, Biological (`AgriSage Organics`), & Chemical ICAR plans. | **UNLOCKED** |

## 5. Verified Technology Stack & Engineering Hardening
| Layer | Verified Packages, Capabilities & Release Hardening |
|---|---|
| **Mobile & UX** | Flutter MVVM (`Flutter 3.47.6`, `Dart 3.13.5`, `pubspec >=3.19.0`, `flutter_riverpod ^2.5.1`, Material 3); first-launch uniform `EN \| हिन्दी \| मराठी` sync (`shared_preferences ^2.2.3`); strict passwordless `+91` auth gate blocking duplicates & unregistered logins (`firebase_core ^2.30.0`, `cloud_firestore ^4.17.2`); 3-tier GPS (`geolocator 12.0.0` → `geocoding ^5.0.1` → OSM Nominatim → offline coords); `flutter_map ^8.3.2` Regional Outbreak Radar; scan-driven My Crops & Field Diary; Agri Experts; read-only Govt Scheme cards & active NGO Support requests; `camera ^0.10.5+9`, `image_picker ^1.1.2`, `image ^4.1.7`, `flutter_tts ^4.0.2` (instant `stopAllAudio()` cutoff on exit). |
| **Edge AI, XAI & Release** | `tflite_flutter ^0.12.1` FP16 LiteRT + 2-View TTA; Python/FastAPI/TensorFlow Grad-CAM; `build.gradle` (`compileSdk 36`, `minSdk 26`, `targetSdk 34`, `noCompress 'tflite', 'lite'`) + R8/ProGuard keep rules (`org.tensorflow.lite.**`, `com.google.ai.edge.litert.**`, `tflite_flutter.**`); verified `arm64-v8a` & `armeabi-v7a` `libtensorflowlite_jni.so`. |

**Prototype Verification:** `dart analyze`: `0` errors (`4` test-mock warnings) | `flutter test`: `73/73` PASS | `audit_l10n_coverage.py`: `0` violations (`276` `EN/HI/MR` keys) | `verify_tflite_parity.py`: PASS | APK: `releases/KisanSetu_Final_Release.apk` (`158.90 MB`, binary audit PASS).
