# FloraX / LeafGuard — Comprehensive System Architecture, ML Model & Full-Stack Audit
**Document Version:** 1.0.0-AUDIT  
**Date:** November 22, 2026  
**Auditor:** Principal Full-Stack Mobile, Cloud & ML Systems Architect  
**Target Repository:** `d:\FloraX\`  
**Target Applications:** FloraX Flutter Android Mobile (`com.florax.crophealth`), FastAPI Vision Engine (`backend_vision`), Cloud Firestore ICAR Vault (`data_pipeline`).

---

## 1. Executive System Health Scorecard

| System Layer | Current Status | Health Score | Core Finding |
|---|---|:---:|---|
| **Flutter Mobile App (UI & Client)** | **OPERATIONAL** | **94%** | Compiles cleanly across all 5 core navigation tabs + Drawer consoles. Zero layout overflows or compilation failures. |
| **Test Suite (`flutter test`)** | **PASSED** | **100%** | **18 / 18 unit and integration tests passing** across `florax_architecture_test.dart` and `leafguard_16_feature_audit_test.dart`. |
| **Offline Engine & SQLite Persistence** | **OPERATIONAL** | **95%** | Unlimited Firestore SQLite cache, background Dart Isolates, local JPEG queueing (`OfflineMediaSyncManager`), and auto-flush on connectivity work reliably. |
| **Cloud Firestore & Security Rules** | **STAGED (OFFLINE-READY)** | **82%** | Rules (`firestore.rules`, `storage.rules`, `firestore.indexes.json`) strictly enforce RBAC and App Check. Runs with fallback offline credentials; live remote write depends on valid App Check tokens. |
| **AI Vision Model (`.tflite`)** | **CRITICAL DEFICIT (UNTRAINED)** | **15%** | `florax_mobilenet_v3_int8.tflite` was **never trained on real crop leaves**. Exported from 20 synthetic noise images per class. Outputs pseudo-random probabilities. |
| **Cloud Grad-CAM (`backend_vision`)** | **CRITICAL DEFICIT (UNTRAINED)** | **20%** | `florax_mobilenet.pth` does not exist. Runs on random weights with a hardcoded `+4.5` logit boost and synthetic confidence clamping. Class IDs use hyphens (`tomato-early-blight`) breaking Firestore doc lookups. |
| **Taxonomy & Class Alignment** | **PARTIAL MISMATCH** | **60%** | `labels.txt` has 5 classes; `seed_firestore_icar_vault.py` has 7 classes; `backend_vision` has 4 classes. **`Not_a_Leaf / Background` class is missing across all layers**. |

---

## 2. Layer 1: AI Model, Labels & Dataset Pipeline Audit

### 2.1. Exact Class Labels Audit (`assets/models/labels.txt`)
`assets/models/labels.txt` contains exactly 5 lines:
```text
1: abiotic_magnesium_deficiency
2: cotton_leaf_curl
3: paddy_leaf_blast
4: tomato_early_blight
5: tomato_healthy
```

#### Taxonomy Cross-Comparison Analysis
1. **Healthy Class:**  
   `tomato_healthy` is present.
2. **`Not_a_Leaf / Background` Class:**  
   **MISSING.** Neither `not_a_leaf` nor `background` exists. If a user points the camera at a table, hand, boot, or tractor, the model is mathematically forced to assign 100% of its probability across the 5 crop disease classes. While `IsolateLesionAnalyzer` has a pre-inference heuristic filter (requiring `leafCoveragePercent >= 18.0%`), any textured green/brown non-crop surface (e.g., grass lawn, green cloth, carpet) will bypass the filter and receive a confident disease diagnosis.
3. **1-to-1 Mapping with `data_pipeline/seed_firestore_icar_vault.py`:**
   - `tomato_early_blight` ➔ **MATCH** (`icar_ipm_protocols/tomato_early_blight`)
   - `paddy_leaf_blast` ➔ **MATCH** (`icar_ipm_protocols/paddy_leaf_blast`)
   - `cotton_leaf_curl` ➔ **MATCH** (`icar_ipm_protocols/cotton_leaf_curl`)
   - `abiotic_magnesium_deficiency` ➔ **MATCH** (`icar_ipm_protocols/abiotic_magnesium_deficiency`)
   - `tomato_healthy` ➔ **MATCH** (`icar_ipm_protocols/tomato_healthy`)
   - *Omitted from `labels.txt` but present in Firestore seeder:* `abiotic_nitrogen_deficiency` and `abiotic_potassium_deficiency`. (These are handled via fallback metadata in `tflite_isolate_service.dart`, but the edge model cannot predict them).
4. **Mismatch with `backend_vision/main.py`:**  
   `backend_vision/main.py` defines `FLORAX_CLASSES` using hyphenated strings:
   - `tomato-early-blight` *(vs `tomato_early_blight`)*
   - `paddy-blast` *(vs `paddy_leaf_blast`)*
   - `cotton-leaf-curl` *(vs `cotton_leaf_curl`)*
   - `magnesium-deficiency` *(vs `abiotic_magnesium_deficiency`)*
   - `tomato_healthy` is **completely missing** in `backend_vision`.
   
   > [!CAUTION]
   > **Direct Impact:** When cloud inference responds via `HybridGradCamClient`, the app queries Firestore: `_firestore.collection('icar_ipm_protocols').doc('tomato-early-blight')`. This document does not exist (the Firestore document ID is `tomato_early_blight`), resulting in a **null protocol** and forcing empty advisory cards.

---

### 2.2. Model Training Truth Audit

#### Edge Model: `assets/models/florax_mobilenet_v3_int8.tflite` (3,772,984 bytes)
Inspecting `data_pipeline/export_quantized_tflite.py`:
- Lines 55–119 (`create_representative_sample_dataset`):
  ```python
  # Generates 20 synthetic images per class using Gaussian noise + math circles
  img_arr = np.tile(base_rgb, (224, 224, 1))
  noise = rng.normal(0, 12, (224, 224, 3))
  # Concentric rings math formula:
  band_mask = mask & ((np.sin(dist / 3.0) > 0.1))
  ```
- Lines 390–394:
  ```python
  if not data_dir or not os.path.isdir(data_dir):
      default_staging = os.path.join(os.path.dirname(__file__), "sample_calibration_dataset")
      data_dir = create_representative_sample_dataset(default_staging, num_samples_per_class=20)
  ```
- Lines 207–242: Trains for 2 epochs on the 100 synthetic noise images.
- Lines 276–340: Converts via `tf.lite.Optimize.DEFAULT` + representative dataset generator.
- **VERDICT:** The current `florax_mobilenet_v3_int8.tflite` is an **untrained placeholder**. Its weights have learned nothing about real crop diseases.

#### Cloud Model: `backend_vision/main.py`
Inspecting `backend_vision/main.py`:
- Lines 96–111:
  ```python
  self.model = models.mobilenet_v3_large(weights=weights)
  in_features = self.model.classifier[3].in_features
  self.model.classifier[3] = nn.Linear(in_features, len(FLORAX_CLASSES))
  # Checks if weights/florax_mobilenet.pth exists
  ```
- Physical filesystem check: `backend_vision/weights/` **does not exist**; no `.pth` weights file exists in the repository.
- Lines 147–159:
  ```python
  if not self.has_custom_weights:
      # Hardcoded domain prior added to logits
      logits[0, target_idx] += 4.5
  ```
- Lines 306–312:
  ```python
  base_top = float(np.clip(top_probs[0] * 100.0 + 48.0, 81.5, 96.4))
  rem = 100.0 - base_top
  calibrated_scores = [round(base_top, 1), round(rem * 0.68, 1), round(rem * 0.32, 1)]
  ```
- **VERDICT:** The cloud vision engine is running an untrained PyTorch classification head masked by a heuristic domain logit offset (`+4.5`) and hardcoded confidence score formatting.

---

### 2.3. Tensor Normalization & Input Signature Verification

- **In Flutter (`lib/services/vision/tflite_isolate_service.dart` lines 302–319):**
  Preprocesses image bytes into `[1, 224, 224, 3]` float32 tensor with raw pixel values `[0.0, 255.0]`.
- **In Python (`data_pipeline/export_quantized_tflite.py` lines 170–172, 292–293):**
  The Keras graph begins with `tf.keras.applications.mobilenet_v3.preprocess_input(inputs)`, which internally maps `[0.0, 255.0]` to `[-1.0, 1.0]`. The converter config specifies:
  ```python
  converter.inference_input_type = tf.float32
  converter.inference_output_type = tf.float32
  ```
- **VERDICT:** **PASSED.** The tensor signature across Dart and TFLite matches. The model expects float32 inputs scaled `0.0–255.0` and outputs float32 probabilities `[1, 5]`.

---

### 2.4. Raw Training Dataset Directory Rules & Git Hygiene

- **Target Path:** Raw image datasets must reside strictly under `data_pipeline/raw_datasets/`.
- **`.gitignore` Audit:** `d:\FloraX\.gitignore` currently does **NOT** contain `data_pipeline/raw_datasets/`, `sample_calibration_dataset/`, or `*.pth`.
- **`pubspec.yaml` Audit:** Lines 57–59 strictly list:
  ```yaml
  assets:
    - assets/models/florax_mobilenet_v3_int8.tflite
    - assets/models/labels.txt
  ```
  `pubspec.yaml` is clean and does not bundle datasets.

---

## 3. Layer 2: Backend, Firebase & Live Data Wiring Audit

### 3.1. Firebase Configuration & Security Credentials
- **`android/app/google-services.json`:** Configured with `project_id: "florax-crophealth-prod"`, `project_number: "1029384756"`, `api_key: "AIzaSyFloraXProductionClientKeyDefault001"`.
- **`lib/core/bootstrap/firebase_security_init.dart`:** Contains duplicate fallback credentials for the same project.
- **`lib/firebase_options.dart`:** **MISSING.** (The app relies on native Android `google-services.json` or inline fallback options).
- **App Check Attestation:** In `firebase_security_init.dart`, `AndroidProvider.playIntegrity` is enforced unless `kDebugMode` or `USE_APP_CHECK_DEBUG` is set. In `firestore.rules`, `isTrustedCaller()` requires `request.app != null` for scan and protocol reads/writes.
  > [!WARNING]
  > Without registering the Android app's release SHA-256 in the Firebase Console under App Check (Play Integrity), real production network calls to Firestore/Storage will return `PERMISSION_DENIED`.

### 3.2. Leftover Hardcoded / Mock Data Fallbacks
1. **`lib/repositories/ecosystem_directory_repository.dart` (Lines 288–330):**
   ```dart
   final scansSnap = await _firestore.collection('scans').limit(500).get();
   final int totalScans = max(scansSnap.size, 14820);
   final int divertedCount = max(abioticCount, 3420);
   final int secondOpinionsCount = max(secondOpinionsSnap.size, 184);
   final int outbreakCount = max(outbreaksSnap.size, 24);
   ```
   Uses hardcoded minimums (`14,820`, `3,420`, `184`, `24`) to simulate a mature production telemetry dashboard.
2. **`lib/presentation/screens/radar/predictive_radar_and_heatmap_screen.dart` (Lines 714–750):**
   The animated 5km Radar Canvas paints 4 hardcoded pins (`Tomato Blight`, `Armyworm`, `Downy Mildew`, `Bio Guarded`) at static pixel coordinates, despite the live list below it querying Firestore `outbreak_clusters`.
3. **`lib/presentation/screens/progression/disease_progression_screen.dart` (Lines 28–32):**
   Uses a static list of 3 plant plots (`PLANT-TOM-01`, `PLANT-PAD-03`, `PLANT-COT-04`) in local widget state rather than querying the user's distinct `plantTagId`s from Firestore.
4. **`lib/presentation/screens/kvk/kvk_scientist_console_sheet.dart` (Lines 23–28, 129):**
   Hardcodes the logged-in scientist identity as "Dr. S. Patil (Pathology Lead), KVK Nashik • ICAR Station #402" and pre-populates feedback text controllers.

### 3.3. Offline Sync & Push Notification Wiring
- **`OfflineMediaSyncManager`:** **FULLY WIRED.** Initialized in `lib/main.dart` (line 62). In `scan_orchestrator_provider.dart` (lines 340–349), whenever Firebase Storage upload fails or is offline, images are written to `${appDocDir}/pending_scans/${scanId}.jpg` and registered in `pending_uploads.json`. Network transitions via `connectivity_plus` trigger automatic batch uploading.
- **`OutbreakFcmService`:** **PARTIALLY WIRED.** Initialized in `lib/main.dart` (line 70) and registered with background handler. Subscribes to private KVK prescription topics: `kvk_updates_${userId}`. **However, `subscribeToOutbreakTopic(geoHash5)` is NEVER called** anywhere in `main.dart`, `smart_camera_screen.dart`, or `predictive_weather_service.dart`. Farmers will never receive regional epidemic push notifications unless this is hooked to location acquisition.

---

## 4. Layer 3: 16-Feature LeafGuard Completeness Matrix

Each of the 16 LeafGuard requirements has been audited directly against the source code:

| # | LeafGuard Feature Requirement | Status | Exact File(s) & Implementation Points | Specific Remaining Gap / Blocker |
|---|---|:---:|---|---|
| **1** | **Multi-Region Disease Detection** | `[PARTIAL]` | `lib/services/vision/isolate_lesion_analyzer.dart` (BFS connected-components, `_extractMultiRegionRoiPatches`), `lib/services/vision/tflite_isolate_service.dart` (`classifyMultiRegion`), `lib/presentation/widgets/gradcam_overlay_painter.dart` (`MultiRegionBoxPainter`) | Logic and UI are fully functional, but on-device INT8 model has untrained weights. Cloud `backend_vision` does not support ROI patch cropping. |
| **2** | **Disease vs. Nutrient Deficiency Differentiation** | `[LIVE]` | `lib/services/vision/isolate_lesion_analyzer.dart` (lines 316–324), `lib/services/vision/tflite_isolate_service.dart` (lines 249–256), `lib/presentation/widgets/smart_ipm_stepper_card.dart` (lines 72–74, 148–150) | None. Abiotic nutritional deficiencies suppress chemical fungicides, replace Tier 3 with soil amendments/micronutrients, and display yellow guardrail banners. Verified by unit tests. |
| **3** | **Early-Stage Disease Recognition** | `[LIVE]` | `lib/services/vision/isolate_lesion_analyzer.dart` (lines 328–336, 361–366), `lib/presentation/widgets/gradcam_overlay_painter.dart` (lines 204–207) | None. Analyzes narrow-band HSV for chlorotic flecks (0.5%–5.0% leaf area), triggers `isEarlyStageAlert`, and displays high-visibility alert badges. |
| **4** | **Explainable AI (Grad-CAM) Diagnosis** | `[PARTIAL]` | `lib/services/vision/hybrid_gradcam_client.dart`, `lib/presentation/widgets/gradcam_overlay_painter.dart`, `backend_vision/main.py` | UI rendering (opacity slider, JET colormap, tap-to-inspect hotspots) is live. Gap: `backend_vision/main.py` has no trained weights (`weights/florax_mobilenet.pth` missing), relying on dummy logit boosts. On-device fallback uses mathematical CIELAB centroids, not native neural Grad-CAM. |
| **5** | **Intelligent Image Quality Verification** | `[LIVE]` | `lib/services/vision/isolate_lesion_analyzer.dart` (lines 113–225), `lib/presentation/providers/scan_orchestrator_provider.dart` (lines 188–203), `lib/presentation/screens/scanner/smart_camera_screen.dart` (lines 695–872) | None. Computes luminance, foliage coverage (`>=18%`), and Laplacian blur variance (`>=85.0`). Rejects poor images before inference and presents a modal with vernacular audio guidance. |
| **6** | **Top-3 Differential Diagnosis & Questions** | `[LIVE]` | `lib/services/vision/tflite_isolate_service.dart` (lines 121–143), `lib/presentation/widgets/gradcam_overlay_painter.dart` (lines 225–228, `_buildDifferentialDiagnosisDeck`), `data_pipeline/seed_firestore_icar_vault.py` | None. Returns Top-3 sorted candidates with confidence bars and interactive vernacular clarifying questions from ICAR protocols. |
| **7** | **Verified Agricultural Advisory (ICAR / TNAU / SAU)** | `[LIVE]` | `data_pipeline/seed_firestore_icar_vault.py`, `lib/presentation/widgets/smart_ipm_stepper_card.dart` | None. 3-tier sequential cards (Cultural, Biological, Chemical) featuring CIB&RC formulations, dosage per litre, Waiting Periods (PHI), PPE warnings, and official institutional citations. |
| **8** | **Disease Severity Estimation** | `[LIVE]` | `lib/services/vision/isolate_lesion_analyzer.dart` (lines 347–359), `lib/domain/models/florax_models.dart` (`SeverityGrade.fromPercentage`) | None. Quantifies lesion pixels vs leaf pixels. Categorizes into Mild (<10%), Moderate (10–25%), and Severe (>25%) with color-coded UI badges. |
| **9** | **Treatment Effectiveness Tracking** | `[LIVE]` | `lib/repositories/firestore_ipm_and_scan_repository.dart` (`watchPlantProgression`), `lib/presentation/screens/progression/disease_progression_screen.dart` | None. Real-time Firestore stream computing `deltaPercent`, plotting fl_chart historical trend lines, status chips (`RECOVERING`, `STABLE`, `SPREADING`), worsening alerts, and Before/After visual comparisons. |
| **10** | **Botanical & Agri Expert Directory (5 Specialties)** | `[LIVE]` | `lib/repositories/ecosystem_directory_repository.dart` (`watchVerifiedExperts`), `lib/presentation/screens/experts/expert_directory_screen.dart` | None. Filterable by 5 disciplines (pathologists, botanists, agronomists, entomologists, horticulturists) and district. Directly connected to second-opinion routing. |
| **11** | **NGO Partnership Network (*LeafGuard Connect*)** | `[LIVE]` | `lib/repositories/ecosystem_directory_repository.dart` (`watchNgoPartners`, `submitNgoAssistanceRequest`), `lib/presentation/screens/ngo/leafguard_connect_screen.dart` | None. Streams accredited NGOs by district with Darpan IDs, zero-copay badges, and a "Request Field Support" modal submitting to `ngo_assistance_requests`. |
| **12** | **Expert Verification & Second Opinion Flow** | `[LIVE]` | `lib/presentation/widgets/smart_ipm_stepper_card.dart` (`_buildSecondOpinionActionButton`), `lib/presentation/screens/kvk/kvk_scientist_console_sheet.dart`, `firestore.rules` | None. Submits scans to `second_opinion_requests`. Dedicated KVK console sheet allows agronomists to review low-confidence scans (<75%), write clinical notes, and approve chemical unlocks (`chemicalUnlocked = true`). |
| **13** | **Multilingual Voice Assistant (Marathi / Hindi / English)** | `[LIVE]` | `lib/services/voice/vernacular_voice_service.dart`, `lib/main.dart` (lines 154–159, 185–190) | None. Hands-free voice navigation ("Kisan Vani") supporting Marathi, Hindi, and English. Spoken intents trigger screen navigation; full 3-tier IPM advice is narrated aloud via `flutter_tts`. |
| **14** | **Institution-Only Outbreak Reporting (Strict RBAC)** | `[LIVE]` | `firestore.rules` (lines 42–51, 124, 139), `lib/repositories/ecosystem_directory_repository.dart` (`submitInstitutionalOutbreakReport`), `lib/presentation/screens/radar/predictive_radar_and_heatmap_screen.dart` | None. Cryptographically restricted in `firestore.rules`. "Log Verified Outbreak" button only appears for KVK/NGO/Admin roles. Farmers cannot forge outbreak alerts. |
| **15** | **Offline Disease Identification & Sync Queue** | `[LIVE]` | `lib/services/sync/offline_media_sync_manager.dart`, `lib/core/bootstrap/firebase_security_init.dart`, `lib/presentation/providers/scan_orchestrator_provider.dart` | None. On-device TFLite + Isolate CIELAB runs without network. Unlimited Firestore SQLite cache. Offline photos queued to local disk and auto-flushed when connectivity returns. |
| **16** | **NGO, CSR & Institutional Funding Hub** | `[PARTIAL]` | `lib/repositories/ecosystem_directory_repository.dart` (`watchCsrFundingPartners`, `submitPartnershipInquiry`, `fetchImpactTelemetry`), `lib/presentation/screens/institutional/csr_impact_and_funding_screen.dart` | Inquiry submission form and CSR directory are live. Gap: `fetchImpactTelemetry()` relies on hardcoded minimums (`max(..., 14820)`) instead of genuine aggregation counts. |

---

## 5. Dataset & AI Model Blueprint

### 5.1. Exact Folder Layout for Training & Fine-Tuning
Raw training datasets must never be placed in Flutter's `assets/` folder. Use the following structure on your workstation or Google Colab:

```text
FloraX/
└── data_pipeline/
    ├── raw_datasets/                  <-- STRICTLY EXCLUDED IN .gitignore
    │   ├── train/
    │   │   ├── abiotic_magnesium_deficiency/
    │   │   ├── abiotic_nitrogen_deficiency/
    │   │   ├── abiotic_potassium_deficiency/
    │   │   ├── cotton_leaf_curl/
    │   │   ├── paddy_leaf_blast/
    │   │   ├── tomato_early_blight/
    │   │   ├── tomato_healthy/
    │   │   └── not_a_leaf_background/     <-- ESSENTIAL NEGATIVE CLASS
    │   └── val/
    │       ├── abiotic_magnesium_deficiency/
    │       ├── abiotic_nitrogen_deficiency/
    │       ├── abiotic_potassium_deficiency/
    │       ├── cotton_leaf_curl/
    │       ├── paddy_leaf_blast/
    │       ├── tomato_early_blight/
    │       ├── tomato_healthy/
    │       └── not_a_leaf_background/
    ├── export_quantized_tflite.py
    └── seed_firestore_icar_vault.py
```

### 5.2. Recommended 8-Class Production Taxonomy
To ensure 100% interoperability across Flutter, TFLite, Python, and Firestore, the next training iteration must train on these **exact 8 snake_case class labels**:

| Index | Label ID | Crop | Pathogen / Condition | Firestore Document ID |
|:---:|---|---|---|---|
| `0` | `abiotic_magnesium_deficiency` | Tomato/Cotton | Interveinal Chlorosis (Abiotic) | `abiotic_magnesium_deficiency` |
| `1` | `abiotic_nitrogen_deficiency` | All Crops | General Foliar Chlorosis (Abiotic) | `abiotic_nitrogen_deficiency` |
| `2` | `abiotic_potassium_deficiency` | All Crops | Marginal Leaf Scorch (Abiotic) | `abiotic_potassium_deficiency` |
| `3` | `cotton_leaf_curl` | Cotton | *Begomovirus* (CLCuV) | `cotton_leaf_curl` |
| `4` | `paddy_leaf_blast` | Rice / Paddy | *Magnaporthe oryzae* | `paddy_leaf_blast` |
| `5` | `tomato_early_blight` | Tomato | *Alternaria solani* | `tomato_early_blight` |
| `6` | `tomato_healthy` | Tomato | Healthy Foliage | `tomato_healthy` |
| `7` | `not_a_leaf_background` | None | Soil, Hands, Fabric, Hardware | `null` *(Triggers UI Retake)* |

### 5.3. Architecture Decoupling Protocol
To prevent re-training from breaking the Flutter app:
1. **Model Binary (`assets/models/florax_mobilenet_v3_int8.tflite`):** The app treats the `.tflite` file as a black box that takes a `[1, 224, 224, 3]` float32 tensor and outputs an array of softmax floats `[1, N]`.
2. **Label File (`assets/models/labels.txt`):** The app reads `labels.txt` line-by-line dynamically at startup (`AppConfig.loadDynamicPathologyLabels()`). Class count is never hardcoded.
3. **Firestore IPM Vault (`icar_ipm_protocols/{labelId}`):** The app takes the winning `labelId` string and retrieves the corresponding rich advisory document from Firestore. The model binary stores zero text or agronomic advice.

---

## 6. Prioritized 3-Stage Action Plan

### Stage A — Critical Blockers (Do Immediately)
1. **Train Real Weights on PlantVillage & PlantDoc:**  
   Replace `assets/models/florax_mobilenet_v3_int8.tflite` using real images passed via `python data_pipeline/export_quantized_tflite.py --data-dir data_pipeline/raw_datasets/`.
2. **Harmonize `backend_vision/main.py` Class IDs:**  
   Change hyphens to underscores (`tomato-early-blight` ➔ `tomato_early_blight`, `paddy-blast` ➔ `paddy_leaf_blast`, `magnesium-deficiency` ➔ `abiotic_magnesium_deficiency`) so cloud responses match Firestore document keys.
3. **Add `not_a_leaf_background` Class:**  
   Include 300+ non-leaf background images (COCO / ImageNet noise / hands) into the training pipeline to eliminate false disease triggers on non-crop objects.
4. **Fix Git Hygiene:**  
   Add `data_pipeline/raw_datasets/`, `data_pipeline/sample_calibration_dataset/`, and `*.pth` to `.gitignore`.
5. **Wire Regional Outbreak Topic Subscription in FCM:**  
   Call `ref.read(outbreakFcmServiceProvider).subscribeToOutbreakTopic(geoHash5)` inside `PredictiveWeatherService.getPredictiveDiseaseWarning()` upon GPS location acquisition.

### Stage B — High-Impact Polish (Before Demo / Submission)
1. **Connect Live Firestore Outbreak Clusters to Radar Canvas:**  
   Replace the 4 hardcoded pins in `_buildRadarViewportSection()` with a dynamic `CustomPainter` that plots real documents from `outbreak_clusters`.
2. **Dynamic Plant Tracking Selector:**  
   Query `_firestore.collection('scans').where('userId', isEqualTo: uid)` to populate distinct plant tag IDs in `DiseaseProgressionScreen` instead of using the static 3-plot list.
3. **Clean Live Impact Telemetry Counters:**  
   Remove the synthetic `max(scansSnap.size, 14820)` fallbacks in `EcosystemDirectoryRepository.fetchImpactTelemetry()` and show genuine scan counts with an attractive empty-state counter for demo accounts.
4. **Edge Grad-CAM Approximation:**  
   Add an isolate-based activation map renderer for true visual explainability when running 100% offline without the Python backend.

### Stage C — Post-Hackathon Scale (Defer for Now)
1. **`flutter_litert` & GPU Delegate Migration:**  
   Migrate from legacy `tflite_flutter` to official `flutter_litert` with NNAPI/GPU acceleration once stable.
2. **Cloud Functions (Blaze Plan) Epidemiological Clustering:**  
   Deploy automated server-side Firestore triggers that aggregate private scans into regional GeoHash5 clusters (`outbreak_clusters`) without client-side writes.
3. **Multi-Crop 38-Class Expansion:**  
   Scale taxonomy to support Potato, Apple, Maize, Grape, and Sugarcane diseases.
4. **Android 16 / Play Store Target SDK 36 Bump:**  
   Update Gradle toolchains for future Google Play requirements.

---

## 7. Ready-to-Run Next Prompts

To execute the immediate fixes identified in **Stage A**, use the following scoped prompts:

### Prompt 1: Harmonize Vision Backend Class IDs & Wire Regional FCM Topics
```text
Act as Principal Mobile & Cloud Engineer on d:\FloraX\.
Please execute two immediate Stage-A fixes:
1. In `backend_vision/main.py`, harmonize `FLORAX_CLASSES` so all IDs strictly use standard snake_case matching `assets/models/labels.txt` and `data_pipeline/seed_firestore_icar_vault.py` (e.g., 'tomato_early_blight', 'paddy_leaf_blast', 'cotton_leaf_curl', 'abiotic_magnesium_deficiency', and add 'tomato_healthy').
2. In `lib/services/weather/predictive_weather_service.dart` and `lib/presentation/providers/scan_orchestrator_provider.dart`, wire the OutbreakFcmService so that whenever `getCurrentGeoHash5()` resolves a new 5-character geohash, `OutbreakFcmService.subscribeToOutbreakTopic(geoHash5)` is automatically triggered.
Do not break any existing tests; run `flutter test` to verify.
```

### Prompt 2: Update `.gitignore` & Add Negative Class Gate to Python Pipeline
```text
Act as Principal ML Engineer on d:\FloraX\.
Please execute two Stage-A dataset and pipeline fixes:
1. Update `d:\FloraX\.gitignore` to strictly exclude all raw training datasets and large weight binaries:
   `data_pipeline/raw_datasets/`, `data_pipeline/sample_calibration_dataset/`, `backend_vision/weights/`, and `*.pth`.
2. In `data_pipeline/export_quantized_tflite.py`, add 'not_a_leaf_background' as the 8th standard class in `STANDARD_FLORAX_CLASSES`, updating the synthetic sample generator and label mapping accordingly so the architecture is ready for full dataset training.
```

### Prompt 3: Replace Hardcoded Radar Pins with Live Firestore Cluster Coordinates
```text
Act as Principal Flutter UI Architect on d:\FloraX\.
In `lib/presentation/screens/radar/predictive_radar_and_heatmap_screen.dart`, replace the hardcoded static pins inside `_buildRadarViewportSection()` (lines 714–750) with a dynamic StreamBuilder listening to `outbreak_clusters`. Render real pins based on the active cluster documents in Firestore, with color-coding according to disease severity. Ensure smooth animations and no layout regressions.
```
