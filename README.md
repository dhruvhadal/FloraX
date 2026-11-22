# FloraX / LeafGuard 🌱🛡️
> **Universal Mobile Crop Pathology Diagnostic & ICAR Advisory Platform**  
> *Production-Ready Multi-Region Edge AI, Clinical Explainability (Grad-CAM), and Zero-Cost Firebase Spark Architecture*

[![Flutter](https://img.shields.io/badge/Flutter-3.47.6-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.5-0175C2?logo=dart)](https://dart.dev)
[![TensorFlow / Keras](https://img.shields.io/badge/TensorFlow%20%2F%20Keras-2.21-FF6F00?logo=tensorflow)](https://tensorflow.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.165-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Firebase](https://img.shields.io/badge/Firebase-Spark%20Plan-FFA611?logo=firebase)](https://firebase.google.com)

---

## 1. Architectural Overview (3-Layer Architecture)

FloraX is architected as an ultra-low-latency, resilient agronomic diagnostics engine designed specifically for challenging field environments (2G connectivity, intermittent power, offline farms in Maharashtra and beyond):

```
┌────────────────────────────────────────────────────────────────────────┐
│                      LAYER 1: ON-DEVICE EDGE (FLUTTER)                 │
│  • Smart Viewfinder with Laplacian Blur & CIELAB Quality Gate         │
│  • Dynamic-Range-Quantized (DRQ) MobileNetV2 INT8 Model (~2.6 MB)       │
│  • Multi-Region Isolate Inference & Normalized Shannon Entropy OOD Gate │
│  • Latency: < 200 ms | Zero network required for initial triage       │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
           Non-blocking Background   │   Local USB adb reverse / LAN
           Fire-and-Sync (Base64)    │   Async Stream (Port 8000)
                                     ▼
┌────────────────────────────────────┴───────────────────────────────────┐
│              LAYER 2: CLOUD INTEL & VAULT (FIREBASE SPARK)              │
│  • Cloud Firestore with unlimited offline SQLite persistence           │
│  • Thumbnail Base64 (< 80 KB) document storage (zero Storage costs)    │
│  • ICAR IPM Protocols (3-tier: Cultural, Biological, Chemical Lock)    │
│  • GeoHash5 privacy clustering & FCM regional outbreak alerts          │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│              LAYER 3: WORKSTATION AI (WINDOWS FASTAPI)                 │
│  • Keras Functional MobileNetV2 with tf.GradientTape Grad-CAM          │
│  • OpenCV CIELAB Necrosis & Chlorosis quantification                   │
│  • Seamless hot-patching of thermal heatmaps into Flutter UI & Cloud   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Directory Structure

```
d:\FloraX\
├── android/                         # Production Android wrapper (Gradle 8.14, OpenJDK 21, API 21+)
├── assets/
│   └── models/
│       ├── florax_disease_v1_drq.tflite    # 2.6 MB INT8 on-device model (69 raw classes)
│       ├── labels.txt                      # 69 raw taxonomy labels
│       ├── class_alias_map.json            # 69 raw -> 50 canonical ICAR class mapping
│       └── model_meta.json                 # OOD entropy thresholds & normalization parameters
├── backend_vision/                  # Windows FastAPI Keras Grad-CAM Microservice
│   ├── main.py                     # FastAPI application & GradientTape Grad-CAM engine
│   ├── smoke_test.py               # Comprehensive engine and endpoint smoke verification
│   ├── requirements.txt            # Lean Python dependencies
│   └── weights/                    # Keras model weights and taxonomy configuration
│       ├── florax_disease_v1_gradcam.keras  # 9.9 MB Keras model
│       ├── labels.txt
│       ├── class_alias_map.json
│       └── model_meta.json
├── data_pipeline/                   # Agronomic Database & ICAR Vault Tools
│   ├── seed_firestore_icar_vault.py        # Seeds Firestore with 50 ICAR IPM protocols
│   └── serviceAccountKey.json              # Local Admin SDK key (STRICTLY GIT-IGNORED)
├── functions/                       # Firebase Cloud Functions (v2) for outbreak surge alerts
│   ├── index.js
│   └── package.json
├── lib/                             # Flutter Mobile Client Source
│   ├── core/                        # Theme, configuration, and Firebase security initialization
│   ├── domain/models/               # Immutable models (LeafScanRecord, IcarIpmProtocol, etc.)
│   ├── presentation/                # UI Screens (Viewfinder, Radar, Progression, KVK Sheet)
│   ├── repositories/                # Firestore & Ecosystem repositories
│   └── services/                    # Vision isolates, Weather, Voice, Sync & FCM services
├── test/                            # Comprehensive integration and clinical safety test suite
│   ├── florax_architecture_test.dart
│   └── leafguard_16_feature_audit_test.dart
├── firestore.rules                  # Strict RBAC & App Check Firestore rules
├── firestore.indexes.json           # Composite indexes for spatial outbreak queries
├── firebase.json                    # Firebase CLI & FlutterFire platform linkage
├── start_windows_backend.bat        # Automated 1-click Windows backend launcher + adb reverse
└── pubspec.yaml                     # Lean Flutter dependencies & asset registrations
```

---

## 3. Setup & Getting Started

### Prerequisites
- **Flutter SDK**: `>= 3.19.0` (Recommended: Flutter 3.47.6 / Dart 3.13.5)
- **Java Development Kit**: OpenJDK 17 or OpenJDK 21
- **Python**: 3.11.x (TensorFlow Windows compatibility)
- **Android Device**: Physical phone with USB Debugging enabled or Android Emulator

### A. Flutter Mobile Client Setup
1. Fetch packages:
   ```bash
   flutter pub get
   ```
2. Verify static analysis and run the test suite:
   ```bash
   flutter analyze
   flutter test
   ```
3. Run on a connected Android phone:
   ```bash
   flutter run -d <device_id>
   ```

### B. Firebase Credentials Placement (`serviceAccountKey.json`)
> [!IMPORTANT]
> **Zero-Secret Commitment Policy**: `serviceAccountKey.json` is strictly ignored by `.gitignore` and **must never be committed to Git**.

Teammates cloning the repository must place their project service account key at:
```
d:\FloraX\data_pipeline\serviceAccountKey.json
```
To generate a key:
1. Open the [Firebase Console](https://console.firebase.google.com/) for `florax-leafguard`.
2. Navigate to **Project Settings** > **Service accounts**.
3. Click **Generate new private key** and save it as `serviceAccountKey.json` inside `data_pipeline/`.

### C. Seed Cloud Firestore ICAR IPM Knowledge Vault
To populate Firestore with the 50 ICAR-verified crop disease protocols:
```bash
cd data_pipeline
python seed_firestore_icar_vault.py
```

### D. Windows Vision Backend (FastAPI + Grad-CAM)
1. Automated launch:
   Simply double-click or run:
   ```cmd
   start_windows_backend.bat
   ```
   *This batch script automatically activates the virtual environment, detects any connected Android device via ADB, configures `adb reverse tcp:8000 tcp:8000`, and starts Uvicorn on `http://127.0.0.1:8000`.*

2. Manual launch:
   ```bash
   cd backend_vision
   uv venv venv --python 3.11
   uv pip install -r requirements.txt -p venv
   .\venv\Scripts\python.exe main.py
   ```

3. Run smoke verification:
   ```bash
   .\venv\Scripts\python.exe smoke_test.py
   ```

---

## 4. Key Clinical & Performance Guardrails

1. **Non-Blocking Shutter Path**: `ScanPipelineStage.completed` is emitted immediately (< 200 ms) upon local Isolate inference. Firestore writes and Cloud Grad-CAM requests run asynchronously in the background via `unawaited(...)`.
2. **KVK Agronomist Safety Gate**: Any diagnosis with confidence `< 75%` or Out-Of-Distribution (OOD) entropy is automatically locked out of chemical pesticide recommendations, staging a review ticket in `/kvk_escalations`.
3. **GeoHash5 Location Privacy**: GPS coordinates are truncated to 5-character hashes (~4.9 km radius) before writing to Firestore, ensuring farmer land privacy while enabling regional outbreak alerting.
4. **Firebase Spark Compliance**: Full-resolution JPEGs remain on local disk (`scans/${scanId}.jpg`); only optimized base64 thumbnails (< 80 KB) are synced to Firestore documents, fitting safely within the 1 MiB document limit with zero cloud storage costs.

---

## 5. License & Attribution
Proprietary & Confidential — Developed for **FloraX / LeafGuard** Agricultural Diagnostic Initiative.  
All agronomic advisories conform to ICAR, PlantVillage, and State Agricultural University (SAU) protocols.
