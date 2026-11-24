# KisanSetu v2.0 — Srujan 2026 Release (`Track T1 | Problem AI-05`)

**KisanSetu** is an offline-first, clinically guarded crop pathology diagnostic and agronomy bridge built for **Srujan 2026 (in association with L&T EduTech) — Track T1: Artificial Intelligence | Problem AI-05: Crop Disease Identification**.

---

## 📦 What Is Inside `KisanSetu_Final_Release.apk`

- **Universal Android Binary (`158.90 MB` / `166,615,233` bytes):** Bundles native `arm64-v8a` and `armeabi-v7a` LiteRT (`libtensorflowlite_jni.so`) libraries (`minSdk 26`, Android 8.0+).
- **Uncompressed On-Device Edge AI Model:** Ships `assets/models/florax_v2_45c_fp16.tflite` (`11.41 MB`, `EfficientNetV2-B0` FP16, `45` canonical classes across 9 crops, 6 abiotic nutrient deficiencies, and 1 non-leaf OOD class) stored uncompressed (`ZIP_STORED`) for zero-copy `mmap` execution.
- **Bundled ICAR / SAU Knowledge Vault:** Embeds `48` localized 3-tier IPM treatment protocols (`assets/data/offline_icar_protocols.json`) covering Cultural Sanitation, Biological (`AgriSage Organics`), and ICAR/CIB&RC Chemical guidelines.
- **Trilingual UI & Audio Support:** Synchronized **English (`EN`)**, **Hindi (`हिन्दी`)**, and **Marathi (`मराठी`)** interface with offline `flutter_tts` audio guidance and instant cutoff on exit.
- **4-State Clinical Safety Engine:** Deterministic safety locks block chemical fungicide recommendations on non-leaf OOD captures, abiotic nutrient deficiencies (`0 g/L`), and uncertain biotic predictions (`< 75%` confidence) routed to KVK Agri Experts.

---

## 🌾 100% Offline Capabilities (Zero Rural Internet Required)

You can evaluate core diagnostics in **Airplane Mode**:
1. **First-Launch Language Selection (`EN | हिन्दी | मराठी`)** and local profile session persistence.
2. **45-Class Leaf Disease & Nutrient Deficiency Scanning** via Camera or Gallery (`< 200 ms` isolate inference with 2-View TTA).
3. **100% Non-Leaf OOD Rejection** preventing false diagnoses on soil, hands, or background objects.
4. **Full 3-Tier ICAR/SAU Cure Guides** & **Audio Narration** read offline from bundled assets.
5. **Scan-Driven My Crops Field Diary**, **Seeded KVK Agri Experts**, **Seeded Regional Outbreak Alerts**, and **Offline GPS Coordinate Fallback**.
6. *(Optional Workstation XAI)* Connect via USB `adb reverse tcp:8000 tcp:8000` or LAN to `backend_vision` to view live **Keras `tf.GradientTape` Grad-CAM** thermal overlays and OpenCV CIELAB lesion ratios.

---

## 📲 Android Installation Instructions (Sideloading)

1. Download **`KisanSetu_Final_Release.apk`** from the **Assets** section below onto your Android device (`Android 8.0+`).
2. Tap the downloaded `.apk` file from your notification shade or **Files** app.
3. If prompted by Android security:
   - Tap **Settings** on the *"For your security, your phone currently isn't allowed to install unknown apps from this source"* dialog.
   - Enable **Allow from this source** for your browser / file manager, then press **Back**.
4. Tap **Install** and open **KisanSetu** from your app drawer.
5. Grant **Camera** and **Location** permissions when prompted for field scanning and district-aware outbreak alerts.

---

## 🔐 SHA-256 Checksum Verification

Verify binary integrity before installation:

| Artifact | Size | SHA-256 Digest |
|---|---|---|
| `KisanSetu_Final_Release.apk` | `158.90 MB` (`166,615,233` bytes) | `7B1F17FF17119E5C8904E1F83561503CEA55BD620C3342A1E4A20AFF2DC70B5F` |

*(If rebuilding locally, replace the digest above using one of the commands below:)*

```powershell
# Windows (PowerShell)
Get-FileHash .\releases\KisanSetu_Final_Release.apk -Algorithm SHA256
```

```bash
# Linux / macOS
sha256sum KisanSetu_Final_Release.apk
```
