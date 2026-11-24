import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported Farmer Dialects & Languages
enum FarmerLanguage {
  marathi('mr', 'mr-IN', 'मराठी', 'मरा'),
  hindi('hi', 'hi-IN', 'हिन्दी', 'हिं'),
  english('en', 'en-IN', 'English', 'EN');

  final String code;
  final String ttsLocale;
  final String displayName;
  final String shortCode;

  const FarmerLanguage(this.code, this.ttsLocale, this.displayName, this.shortCode);

  Locale get locale => Locale(code);

  static FarmerLanguage fromCode(String code) {
    switch (code.toLowerCase().trim()) {
      case 'hi':
      case 'hi-in':
      case 'hin':
        return FarmerLanguage.hindi;
      case 'en':
      case 'en-in':
      case 'eng':
        return FarmerLanguage.english;
      case 'mr':
      case 'mr-in':
      case 'mar':
      default:
        return FarmerLanguage.marathi;
    }
  }
}

/// Reactive StateNotifier for Root Locale Synchronization
class LocaleNotifier extends StateNotifier<FarmerLanguage> {
  final FlutterTts? _tts;

  LocaleNotifier(super.initial, {FlutterTts? tts})
      : _tts = tts ?? (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST') ? null : FlutterTts()) {
    _initTts();
  }

  Future<void> _initTts() async {
    if (_tts == null) return;
    try {
      await _tts!.setLanguage(state.ttsLocale);
    } catch (_) {}
  }

  /// Sets active language, persists to SharedPreferences, syncs to Firestore, and updates TTS
  Future<void> setLanguage(FarmerLanguage lang, {String? farmerMobile}) async {
    state = lang;

    // 1. Persist to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language_code', lang.code);
      await prefs.setBool('has_selected_language', true);
    } catch (e) {
      debugPrint('[LocaleNotifier] Failed to persist selected_language_code: $e');
    }

    // 2. Background sync to Firestore
    if (farmerMobile != null && farmerMobile.trim().isNotEmpty) {
      try {
        final mobile = farmerMobile.trim();
        unawaited(
          FirebaseFirestore.instance.collection('farmers').doc(mobile).set({
            'preferredLanguage': lang.code,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        );
      } catch (e) {
        debugPrint('[LocaleNotifier] Firestore language sync deferred: $e');
      }
    }

    // 3. Update Text-To-Speech engine locale immediately
    if (_tts != null) {
      try {
        await _tts!.setLanguage(lang.ttsLocale);
      } catch (_) {}
    }
  }

  /// Convenience method for setting language by string code ('en', 'hi', 'mr')
  Future<void> setLocale(String code, {String? farmerMobile}) async {
    final lang = FarmerLanguage.fromCode(code);
    await setLanguage(lang, farmerMobile: farmerMobile);
  }
}

/// Initial language override provider (used for pre-loading from SharedPreferences before runApp)
final initialLanguageOverrideProvider = Provider<FarmerLanguage>((ref) {
  return FarmerLanguage.marathi;
});

/// Initial boolean override for first-launch language state
final hasSelectedLanguageOverrideProvider = Provider<bool>((ref) {
  return false;
});

/// StateNotifier for tracking whether farmer has completed first-launch language selection
class HasSelectedLanguageNotifier extends StateNotifier<bool> {
  HasSelectedLanguageNotifier(super.initial);

  Future<void> setHasSelected(bool val) async {
    state = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_selected_language', val);
    } catch (e) {
      debugPrint('[HasSelectedLanguageNotifier] Error saving flag: $e');
    }
  }
}

/// Reactive provider for hasSelectedLanguage
final hasSelectedLanguageProvider =
    StateNotifierProvider<HasSelectedLanguageNotifier, bool>((ref) {
  final initial = ref.watch(hasSelectedLanguageOverrideProvider);
  return HasSelectedLanguageNotifier(initial);
});

/// Reactive single source of truth for farmer's active language
final activeFarmerLanguageProvider = StateNotifierProvider<LocaleNotifier, FarmerLanguage>((ref) {
  final initial = ref.watch(initialLanguageOverrideProvider);
  return LocaleNotifier(initial);
});

/// Global Provider for Farmer Localization Dictionary
final farmerLocalizationProvider = Provider<FarmerLocalization>((ref) {
  final lang = ref.watch(activeFarmerLanguageProvider);
  return FarmerLocalization(lang);
});

/// Full 100% key-parity localization dictionary for KisanSetu
class FarmerLocalization {
  final FarmerLanguage lang;
  const FarmerLocalization(this.lang);

  /// Key lookup with fallback
  String tr(String key) {
    final map = _dictionaries[lang.code] ?? _dictionaries['mr']!;
    if (map.containsKey(key)) {
      return map[key]!;
    }
    // Fallback to English dictionary if key missing in target dialect
    final enMap = _dictionaries['en']!;
    return enMap[key] ?? key;
  }

  // Common UI & Navigation
  String get appTitle => tr('app_title');
  String get tabScan => tr('tab_scan');
  String get tabMyCrops => tr('tab_my_crops');
  String get tabAlerts => tr('tab_alerts');
  String get tabExperts => tr('tab_experts');
  String get partnerPortal => tr('partner_portal');
  String get btnSubmit => tr('btn_submit');
  String get btnCancel => tr('btn_cancel');
  String get btnSave => tr('btn_save');
  String get btnUpdate => tr('btn_update');
  String get btnBack => tr('btn_back');
  String get btnClose => tr('btn_close');
  String get btnRetry => tr('btn_retry');
  String get btnNext => tr('btn_next');
  String get btnContinue => tr('btn_continue');
  String get loading => tr('loading');

  // Scanner Screen
  String get holdLeafSteady => tr('hold_leaf_steady');
  String get gallery => tr('gallery');
  String get flash => tr('flash');
  String get capture => tr('capture');
  String get retakeTitle => tr('retake_title');
  String get retakeSubtitle => tr('retake_subtitle');
  String get tryAgain => tr('try_again');

  // Diagnosis Details Screen
  String get diagnosisResult => tr('diagnosis_result');
  String get leafPhotoTab => tr('leaf_photo_tab');
  String get damageSpotTab => tr('damage_spot_tab');
  String get listenResult => tr('listen_result');
  String get stopListening => tr('stop_listening');
  String get severityLow => tr('severity_low');
  String get severityMedium => tr('severity_medium');
  String get severityHigh => tr('severity_high');
  String get severityCritical => tr('severity_critical');
  String get seeCureSteps => tr('see_cure_steps');
  String get askExpertFree => tr('ask_expert_free');
  String get scientistDetails => tr('scientist_details');
  String get healthyVerdict => tr('healthy_verdict');

  // Treatment Steps
  String get cureGuideTitle => tr('cure_guide_title');
  String get step1Title => tr('step1_title');
  String get step2Title => tr('step2_title');
  String get step3Title => tr('step3_title');
  String get safetyLockTitle => tr('safety_lock_title');
  String get safetyLockDesc => tr('safety_lock_desc');
  String get verifyWithKvk => tr('verify_with_kvk');
  String get icarAttribution => tr('icar_attribution');

  // Recovery & Crops
  String get myCropsTitle => tr('my_crops_title');
  String get gettingBetter => tr('getting_better');
  String get needsCheck => tr('needs_check');
  String get scanSameCropAgain => tr('scan_same_crop_again');
  String get viewProgressGraph => tr('view_progress_graph');
  String get pastScans => tr('past_scans');

  // Alerts & Map
  String get alertsTitle => tr('alerts_title');
  String get rainDoNotSpray => tr('rain_do_not_spray');
  String get clearSafeToSpray => tr('clear_safe_to_spray');
  String get centerOnMyFarm => tr('center_on_my_farm');
  String get nearbyOutbreaks => tr('nearby_outbreaks');
  String get kmAway => tr('km_away');

  // Experts Directory
  String get needHelpDoctor => tr('need_help_doctor');
  String get callButton => tr('call_button');
  String get sendLeafPhoto => tr('send_leaf_photo');
  String get filterAll => tr('filter_all');
  String get filterPaddy => tr('filter_paddy');
  String get filterTomato => tr('filter_tomato');
  String get filterSugarcane => tr('filter_sugarcane');
  String get filterWheat => tr('filter_wheat');

  // Localized Crop Names
  String getLocalizedCropName(String crop) {
    final c = crop.toLowerCase().trim();
    if (c.contains('tomato')) return tr('crop_tomato');
    if (c.contains('potato')) return tr('crop_potato');
    if (c.contains('corn') || c.contains('maize')) return tr('crop_corn');
    if (c.contains('cotton')) return tr('crop_cotton');
    if (c.contains('sugarcane')) return tr('crop_sugarcane');
    if (c.contains('wheat')) return tr('crop_wheat');
    if (c.contains('rice') || c.contains('paddy')) return tr('crop_rice');
    if (c.contains('grape')) return tr('crop_grape');
    if (c.contains('apple')) return tr('crop_apple');
    if (c.contains('soybean')) return tr('crop_soybean');
    if (c.contains('pepper') || c.contains('chilli')) return tr('crop_chilli');
    return crop;
  }

  // Localized Disease Names
  String getLocalizedDiseaseName(String canonicalId) {
    final id = canonicalId.toLowerCase().trim();
    final key = 'disease_$id';
    final val = tr(key);
    if (val != key) return val;

    // Fallback for formatted canonical names
    final cleaned = canonicalId
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
    return cleaned;
  }

  String localizeCropName(String crop) => getLocalizedCropName(crop);
  String localizeDiseaseName(String canonicalId) => getLocalizedDiseaseName(canonicalId);

  // ===========================================================================
  // COMPLETE TRI-LINGUAL STATIC DICTIONARIES (EN / HI / MR)
  // ===========================================================================
  static const Map<String, Map<String, String>> _dictionaries = {
    // -------------------------------------------------------------------------
    // 1. MARATHI (मराठी) - Primary Target Dialect
    // -------------------------------------------------------------------------
    'mr': {
      'app_title': 'किसानसेतू',
      'tab_scan': 'स्कॅन',
      'tab_my_crops': 'माझी पिके',
      'tab_alerts': 'सतर्कता',
      'tab_experts': 'तज्ज्ञ',
      'partner_portal': 'संस्था पोर्टल',
      'btn_submit': 'अर्ज सबमिट करा',
      'btn_cancel': 'रद्द करा',
      'btn_save': 'जतन करा',
      'btn_update': 'अपडेट करा',
      'btn_back': 'मागे जा',
      'btn_close': 'बंद करा',
      'btn_retry': 'पुन्हा प्रयत्न करा',
      'btn_next': 'पुढे जा',
      'btn_continue': 'पुढे सुरू ठेवा',
      'loading': 'लोड होत आहे...',

      // Welcome & Registration Screen
      'welcome_title': 'किसानसेतू मध्ये आपले स्वागत आहे',
      'welcome_subtitle': 'AI पीक रोग निदान, हवामान अंदाज व सरकारी योजना पोर्टल',
      'enter_mobile': 'आपला १० अंकी मोबाईल नंबर टाका',
      'mobile_hint': 'उदा. ९८२२०१२३४५',
      'enter_name': 'शेतकऱ्याचे पूर्ण नाव',
      'name_hint': 'उदा. रमेश पाटील',
      'select_district': 'जिल्हा निवडा',
      'select_state': 'राज्य निवडा',
      'login_btn': 'थेट लॉगिन करा',
      'register_btn': 'नोंदणी करा व सुरू करा',
      'secure_passwordless': 'सुरक्षित ऑफलाइन ओळख (विना पासवर्ड OTP)',

      // App Permissions Flow Screen
      'permissions_title': 'परवानग्या व प्राधान्ये',
      'permissions_subtitle': 'किसानसेतूच्या अचूक सेवेसाठी खालील परवानग्या आवश्यक आहेत',
      'step_language': '१. भाषा निवडा',
      'step_location': '२. लोकेशन परवानगी (GPS)',
      'step_camera': '३. कॅमेरा व स्टोरेज परवानगी',
      'location_desc': 'स्थानिक हवामान, फवारणी सल्ला आणि रोग अलर्टसाठी',
      'camera_desc': 'पिकांच्या पानांचे फोटो काढून AI रोग निदानासाठी',
      'location_granted': 'लोकेशन सुरू आहे (GPS सक्रिय)',
      'camera_granted': 'कॅमेरा परवानगी मंजूर',
      'grant_location': 'लोकेशन परवानगी द्या',
      'grant_camera': 'कॅमेरा परवानगी द्या',
      'audio_guide_play': 'ऑडिओ मार्गदर्शन ऐका',
      'audio_guide_stop': 'मार्गदर्शन थांबवा',

      // Home Dashboard Screen
      'home_greeting': 'नमस्कार, शेतकरी मित्र',
      'home_scan_hero_title': 'पिकांच्या पानांचे AI निदान',
      'home_scan_hero_desc': 'पानाचा फोटो घ्या आणि त्वरित ICAR प्रमाणित उपाय मिळवा',
      'tap_to_scan': 'स्कॅनर सुरू करा',
      'weather_advisory_good': 'फवारणीसाठी हवामान अनुकूल आहे',
      'weather_advisory_rain': 'पावसाची शक्यता — आज फवारणी करू नका',
      'quick_links': 'महत्त्वाच्या शेतकरी सेवा',
      'quick_weather': 'हवामान अंदाज',
      'quick_schemes': 'सरकारी योजना',
      'quick_npk': 'खत गणक (NPK)',
      'quick_history': 'मागील तपासण्या',
      'quick_experts': 'तज्ज्ञ सल्ला',
      'quick_guides': 'सेंद्रिय मार्गदर्शक',
      'outbreak_alert_badge': 'रोग उद्रेक सतर्कता',

      // Scanner Screen
      'hold_leaf_steady': 'पान स्थिर धरा',
      'gallery': 'गॅलरी',
      'flash': 'फ्लॅश',
      'capture': 'फोटो काढा',
      'retake_title': 'स्पष्ट फोटो आवश्यक',
      'retake_subtitle': 'रोगाचे अचूक निदान होण्यासाठी पानाच्या मध्यभागी स्वच्छ प्रकाशात फोटो घ्या.',
      'try_again': 'पुन्हा प्रयत्न करा',
      'processing_leaf': 'पानाचे AI विश्लेषण सुरू आहे...',

      // Diagnosis Details Screen
      'diagnosis_result': 'पीक निदान अहवाल',
      'leaf_photo_tab': 'पानाचा फोटो',
      'damage_spot_tab': 'रोगग्रस्त जागा (AI)',
      'listen_result': 'निदान ऐका',
      'stop_listening': 'थांबवा',
      'severity_low': 'कमी प्रसार',
      'severity_medium': 'मध्यम प्रसार',
      'severity_high': 'गंभीर प्रसार',
      'severity_critical': 'अति-गंभीर प्रसार',
      'see_cure_steps': 'पायरी-पायरीने उपाय पाहा',
      'ask_expert_free': 'खात्री नाही — तज्ज्ञांचा सल्ला घ्या (मोफत)',
      'scientist_details': '🔬 शास्त्रज्ञ / AI तांत्रिक तपशील',
      'healthy_verdict': 'पीक निरोगी आहे',
      'confidence_score': 'AI खात्री प्रमाण',
      'offline_edge_mode': 'ऑफलाइन एज मोड (४५ पिके सक्षम)',

      // Clinical 4-State Safety Banners
      'banner_confirmed_biotic': 'निश्चित जैविक रोग: प्रमाणित उपचार खालीलप्रमाणे आहेत',
      'banner_needs_review': 'संभाव्य लक्षण: अचूकतेसाठी केव्हीके तज्ज्ञ पडताळणी आवश्यक',
      'banner_abiotic': 'अन्नद्रव्य कमतरता: रासायनिक औषध फवारू नका, योग्य खते द्या',
      'banner_ood': 'अस्पष्ट पान: कृपया पानाचा स्वच्छ व जवळून फोटो घ्या',

      // Step-by-step Treatment Guide
      'cure_guide_title': 'पायरी-पायरीने उपाय',
      'step1_title': 'पायरी १: शेती मशागत व स्वच्छता',
      'step2_title': 'पायरी २: सेंद्रिय व जैविक फवारणी',
      'step3_title': 'पायरी ३: सुरक्षित रासायनिक औषध',
      'dosage_tank': '💧 १५ लिटर पंप टाकी',
      'dosage_dose': '🥄 योग्य प्रमाण',
      'dosage_time': '🕒 सकाळी किंवा संध्याकाळी फवारणी करा',
      'dosage_ppe': '🧤 मास्क व हातमोजे वापरा',
      'safety_lock_title': 'रासायनिक औषध सुरक्षिततेसाठी लॉक आहे',
      'safety_lock_desc': 'कमी खात्री किंवा अन्नद्रव्य कमतरतेमुळे विनाकारण रासायनिक फवारणी टाळा. आधी केव्हीके तज्ज्ञांकडून खात्री करून घ्या.',
      'verify_with_kvk': 'केव्हीके तज्ज्ञांशी संपर्क साधा',
      'icar_attribution': 'आय सी ए आर संदर्भ व सुरक्षितता माहिती',

      // Recovery Tracker & My Crops
      'my_crops_title': 'माझी पिके व शेत रोजनिशी',
      'getting_better': 'सुधारणा होत आहे',
      'needs_check': 'तपासणी आवश्यक',
      'scan_same_crop_again': '+ याच पिकाचा पुन्हा फोटो काढा',
      'view_progress_graph': 'प्रगती आलेख पाहा',
      'past_scans': 'मागील स्कॅन नोंदी',

      // Regional Outbreak Radar
      'alerts_title': 'हवामान व रोग सतर्कता',
      'rain_do_not_spray': '🌧️ आज पाऊस — फवारणी करू नका',
      'clear_safe_to_spray': '☀️ स्वच्छ हवामान — फवारणीस अनुकूल',
      'center_on_my_farm': 'माझे शेत',
      'nearby_outbreaks': 'जवळपासचे रोग अलर्ट',
      'km_away': 'किमी अंतरावर',
      'radar_title': 'रोग उद्रेक रडार व उष्णतानकाशा',
      'radar_subtitle': 'तुमच्या परिसरातील सक्रिय रोग प्रादुर्भाव',
      'radius_km': 'किमी परिसर',

      // Agricultural Experts Directory
      'need_help_doctor': 'मदत हवी आहे? पीक डॉक्टरांशी बोला',
      'call_button': '📞 फोन करा',
      'send_leaf_photo': '💬 पाटीचा फोटो पाठवा',
      'filter_all': 'सर्व',
      'filter_paddy': 'भात',
      'filter_tomato': 'टोमॅटो',
      'filter_sugarcane': 'ऊस',
      'filter_wheat': 'गहू',
      'experts_title': 'ICAR प्रमाणित कृषी शास्त्रज्ञ',
      'expert_available': 'सल्ला देण्यासाठी उपलब्ध',

      // User Profile Screen
      'user_profile_title': 'शेतकरी प्रोफाइल व ओळख',
      'farmer_name_label': 'नाव',
      'mobile_label': 'मोबाईल',
      'location_label': 'स्थान',
      'update_via_gps': 'GPS द्वारे अपडेट करा',
      'verified_farmer_badge': '✓ ICAR प्रमाणित शेतकरी',
      'settings_section': 'अ‍ॅप सेटिंग्ज व प्राधान्ये',
      'voice_guidance_toggle': 'व्हॉइस मार्गदर्शन (Kisan Vani)',
      'weather_notifications_toggle': 'हवामान व रोग सूचना',
      'helpline_support': 'शेतकरी हेल्पलाइन व मदत कक्ष',
      'kisan_call_center': 'किसान कॉल सेंटर (भारत सरकार) - १८००-१८०-१५५१',
      'logout_btn': 'लॉगआउट करा',

      // Side Navigation Drawer
      'menu_home': 'मुख्य पृष्ठ',
      'menu_scan': 'नवीन पीक स्कॅन',
      'menu_history': 'स्कॅन इतिहास',
      'menu_my_crops': 'माझी पिके',
      'menu_radar': 'रोग उद्रेक रडार',
      'menu_experts': 'कृषी शास्त्रज्ञ',
      'menu_schemes': 'NGO मदत (NGO Support)',
      'menu_weather': 'हवामान अंदाज',
      'menu_npk': 'NPK खत गणक',
      'menu_profile': 'माझी प्रोफाइल',
      'menu_help': 'शेतकरी मदत व संपर्क',
      'offline_status_active': 'ऑफलाइन डेटाबेस सक्रिय',

      // Assistance Hub & Applications
      'assistance_hub_title': 'किसानसेतू मदत केंद्र (Assistance Hub)',
      'assistance_hub_subtitle': 'पीक नुकसान भरपाई, खते, अवजारे व तज्ज्ञ तांत्रिक मदत',
      'apply_now': 'अर्ज करा',
      'application_submitted': 'अर्ज यशस्वीरीत्या सादर केला!',
      'ticket_id': 'अर्ज क्रमांक',
      'aid_category_financial': 'आर्थिक नुकसान भरपाई',
      'aid_category_equipment': 'कृषी यंत्रे व अवजारे अनुदान',
      'aid_category_inputs': 'बियाणे व सेंद्रिय खते',
      'aid_category_emergency': 'आपत्कालीन पीक विमा दावा',
      'aid_category_technical': 'तांत्रिक मार्गदर्शन व माती परीक्षण',
      'aid_category_ngo': 'NGO व CSR संस्था साहाय्य',
      'claim_amount': 'अपेक्षित रक्कम',
      'acreage': 'शेती क्षेत्र (एकर)',
      'damage_percentage': 'नुकसान प्रमाण (%)',
      'required_documents': 'आवश्यक कागदपत्रे',
      'select_support_type': 'मदतीचा प्रकार निवडा',
      'select_ngo': 'नोंदणीकृत NGO निवडा',

      // Crops
      'crop_tomato': 'टोमॅटो',
      'crop_potato': 'बटाटा',
      'crop_corn': 'मका',
      'crop_cotton': 'कापूस',
      'crop_sugarcane': 'ऊस',
      'crop_wheat': 'गहू',
      'crop_rice': 'भात',
      'crop_grape': 'द्राक्षे',
      'crop_apple': 'सफरचंद',
      'crop_soybean': 'सोयाबीन',
      'crop_chilli': 'मिरची',

      // Common Diseases
      'disease_tomato_early_blight': 'टोमॅटो अगेती करपा',
      'disease_tomato_late_blight': 'टोमॅटो पिछेती करपा',
      'disease_tomato_septoria_leaf_spot': 'टोमॅटो सेप्टोरिया पानावरील डाग',
      'disease_tomato_bacterial_spot': 'टोमॅटो जिवाणूजन्य डाग',
      'disease_potato_early_blight': 'बटाटा अगेती करपा',
      'disease_potato_late_blight': 'बटाटा पिछेती करपा',
      'disease_abiotic_nitrogen_deficiency': 'नायट्रोजन (नत्र) कमतरता',
      'disease_abiotic_phosphorus_deficiency': 'फॉस्फरस (स्फुरद) कमतरता',
      'disease_abiotic_potassium_deficiency': 'पोटॅशियम (पालाश) कमतरता',
      'disease_not_a_leaf_background': 'पानाचा स्पष्ट फोटो नाही',
      'disease_healthy': 'निरोगी पीक',

      // Supplementary Presentation & Modal Keys
      'reference_id': 'संदर्भ क्रमांक:',
      'track_status': 'स्थिती तपासा',
      'urgent_claim_registered': 'आपत्कालीन दावा नोंदवला गेला!',
      'doc_type': 'दस्तऐवज प्रकार:',
      'compliance_status': 'अनुपालन स्थिती:',
      'security_policy': 'सुरक्षा धोरण:',
      'zero_raw_id_storage': 'कोणताही मूळ ओळख क्रमांक साठवला जात नाही',
      'verified_on_record': 'प्रमाणित व नोंदणीकृत',
      'pending_verification': 'पडताळणी प्रलंबित',
      'mark_as_pending': 'प्रलंबित म्हणून चिन्हांकित करा',
      'mark_as_verified': 'सत्यापित म्हणून चिन्हांकित करा',
      'close_telemetry_drawer': 'टेलीमेट्री ड्रॉवर बंद करा',
      'safety_ppe_precaution': 'सुरक्षा व PPE खबरदारी:',
      'standard_icar_sufficient': 'मानक ICAR मशागत व जैविक पद्धती पुरेशा आहेत.',
      'reset_scanner': 'स्कॅनर रीसेट करा',
      'view_report': 'अहवाल पाहा',
      'ask_kvk_expert': 'KVK तज्ज्ञांना विचारा',
      'pathogen_label': 'रोगकारक:',
      'active_cases_label': 'सक्रिय पुष्ट रुग्णसंख्या:',
      'icar_advisory_title': 'ICAR शिफारस केलेली प्रतिबंधात्मक सल्लागार:',
      'acknowledge_advisory': 'सल्ला मान्य करा',
      'location_calibrated': 'स्थान निश्चित केले',
      'continue_to_app': 'किसानसेतू सुरू करा',
      'profile_updated_gps': 'GPS द्वारे प्रोफाइल अपडेट केली',
      'open_smart_camera': 'स्मार्ट कॅमेरा उघडा',
      'start_first_scan': 'पहिले पीक स्कॅन करा',
      'first_scan_desc': 'पिकाच्या पानांचा फोटो काढून पहिले रोग निदान मिळवा.',
      'scan_another_crop': 'दुसरे पीक स्कॅन करा',
      'improving_status': '↑ सुधारणा होत आहे',
      'condition_label': 'स्थिती',
      'recovery_progress': 'सुधारणा प्रगती',
      'day_label': 'दिवस',
      'recheck_crop': 'या पिकाची पुन्हा तपासणी करा',
      'select_crop': 'पीक निवडा',
      'land_area': 'शेती क्षेत्र',
      'unit': 'एकक',
      'unit_acre': 'एकर',
      'unit_guntha': 'गुंठा',
      'soil_fertility_status': 'माती परीक्षण सुपीकता पातळी:',
      'fertility_low': 'कमी',
      'fertility_medium': 'मध्यम',
      'fertility_high': 'जास्त',
      'no_matching_icar_guide': 'कोणतीही जुळणारी ICAR मार्गदर्शिका सापडली नाही',
      'pathological_etiology': 'रोगाचे कारण व प्रकार:',
      'key_diagnostic_symptoms': 'प्रमुख रोग निदान लक्षणे:',
      'cultural_preventive_practices': 'मशागत व प्रतिबंधात्मक उपाय:',
      'icar_spraying_practices': 'ICAR फवारणी सर्वोत्तम पद्धती',
      'spray_tip_1': '• उष्णतेमुळे होणारा ऱ्हास टाळण्यासाठी सकाळी ९ पूर्वी किंवा संध्याकाळी ४:३० नंतर फवारणी करा.',
      'spray_tip_2': '• शेजारच्या पिकांवर फवारा उडू नये म्हणून वाऱ्याचा वेग १५ किमी/तासापेक्षा जास्त असताना कधीही फवारणी करू नका.',
      'spray_tip_3': '• फवारणीनंतर २ तासांत पाऊस पडल्यास औषध वाहून जाते, त्यामुळे पुन्हा फवारणी करावी लागू शकते.',
      'copied_to_clipboard': 'क्लिपबोर्डवर कॉपी केले',
      'ticket_registered': 'तक्रार / चौकशी नोंदवली गेली',
      'ticket_registered_desc': 'तुमची तक्रार नोंदवली गेली आहे. KVK कृषी तज्ज्ञ लवकरच याचे पुनरावलोकन करतील.',
      'ticket_saved_offline': 'ऑफलाइन सेव्ह केले. इंटरनेट उपलब्ध झाल्यावर सिंक होईल.',
      'issue_category': 'समस्येचा प्रकार',
      'describe_question': 'तुमचा प्रश्न किंवा निरीक्षण सांगा',
      'describe_question_hint': 'दिसलेली लक्षणे, शेताचे स्थान किंवा अ‍ॅप समस्या लिहा...',
      'contact_phone_optional': 'संपर्क फोन / व्हॉट्सअ‍ॅप (ऐच्छिक)',
      'submit_ticket_kvk': 'KVK डेस्कला तिकीट सादर करा',
      'search_expert_hint': 'तज्ज्ञांचे नाव, संस्था किंवा जिल्हा शोधा...',
      'call_desk': 'कॉल करा',
      'calling_expert': 'कॉल जोडत आहे',
      'request_second_opinion': 'दुसरा सल्ला मागा',
      'assigned_expert': 'नियुक्त तज्ज्ञ',
      'expert_institution': 'संस्था',
      'attached_scan_id': 'जोडलेला स्कॅन आयडी',
      'preliminary_diagnosis': 'AI प्राथमिक निदान',
      'add_expert_notes': 'शास्त्रज्ञांसाठी नोंदी किंवा दिसलेली लक्षणे जोडा:',
      'expert_notes_hint': 'उदा. सलग पाऊस पडल्यानंतर ३ दिवसांपूर्वी पाने पिवळी पडू लागली...',
      'submit_second_opinion': 'दुसरा सल्ला अर्ज सादर करा',
      'second_opinion_submitted': 'तज्ज्ञांकडे अर्ज सादर केला! तुम्हाला लवकरच सल्ला मिळेल.',
      'expert_label': 'तज्ज्ञ',
      'query_label': 'प्रश्न',
      'response_label': 'उत्तर',
      'no_schemes_found': 'या श्रेणीत कोणतीही योजना उपलब्ध नाही',
      'view_all': 'सर्व पाहा',
      'apply_for_scheme': 'या योजनेसाठी अर्ज करा',
      'could_not_access_image': 'फोटो उघडता आला नाही',
      'attach_crop_damage_photo': 'नुकसानग्रस्त पिकाचा फोटो जोडा',
      'capture_with_camera': 'कॅमेऱ्याने फोटो काढा',
      'select_from_gallery': 'गॅलरीतून निवडा',
      'submission_queued_offline': 'अर्ज ऑफलाइन सेव्ह केला. इंटरनेट सुरू झाल्यावर सबमिट होईल.',
      'affected_crops_hint': 'उदा. टोमॅटो, कापूस, ऊस, कांदा',
      'calamity_desc_hint': 'आपत्तीची तारीख, नुकसान झालेले क्षेत्र किंवा पाणी साचल्याची माहिती लिहा...',
      'acreage_hint': 'उदा. २.५',
      'equipment_desc_hint': 'उदा. बॅटरीवर चालणारा १६ लिटर क्षमतेचा नॅपसॅक स्प्रेअर...',
      'crops_hint': 'उदा. टोमॅटो, कापूस, ऊस, सोयाबीन',
      'acreage_num_hint': 'उदा. २',
      'inputs_desc_hint': 'उदा. करपा प्रतिबंधक संकरित बियाणे किंवा जैविक बुरशीनाशक...',
      'financial_desc_hint': 'उदा. रोगामुळे झालेल्या नुकसानीनंतर २ एकर टोमॅटोमध्ये ठिबक सिंचनासाठी अनुदान...',
      'select_ngo_validation': 'कृपया यादीतून प्रमाणित NGO निवडा',
      'search_ngo_hint': 'नाव, जिल्हा किंवा पिनकोडद्वारे NGO शोधा...',
      'no_ngo_found': 'या शोधाशी जुळणारी NGO सापडली नाही',
      'ngo_desc_hint': 'तुमच्या शेताची सध्याची परिस्थिती, झालेले नुकसान किंवा आवश्यक मदत सांगा...',
      'tech_desc_hint': 'उदा. टोमॅटोच्या पानांवर पिवळ्या शिरा दिसत आहेत, सेंद्रिय फवारणीच्या अंतराबाबत मार्गदर्शन हवे...',
    },

    // -------------------------------------------------------------------------
    // 2. HINDI (हिन्दी)
    // -------------------------------------------------------------------------
    'hi': {
      'app_title': 'किसानसेतु',
      'tab_scan': 'स्कैन',
      'tab_my_crops': 'मेरी फसलें',
      'tab_alerts': 'अलर्ट्स',
      'tab_experts': 'विशेषज्ञ',
      'partner_portal': 'संस्थान पोर्टल',
      'btn_submit': 'आवेदन जमा करें',
      'btn_cancel': 'रद्द करें',
      'btn_save': 'सुरक्षित करें',
      'btn_update': 'अपडेट करें',
      'btn_back': 'पीछे जाएं',
      'btn_close': 'बंद करें',
      'btn_retry': 'पुनः प्रयास करें',
      'btn_next': 'आगे बढ़ें',
      'btn_continue': 'आगे जारी रखें',
      'loading': 'लोड हो रहा है...',

      // Welcome & Registration Screen
      'welcome_title': 'किसानसेतु में आपका स्वागत है',
      'welcome_subtitle': 'AI फसल रोग पहचान, मौसम सलाह व सरकारी योजना पोर्टल',
      'enter_mobile': 'अपना १० अंकों का मोबाइल नंबर दर्ज करें',
      'mobile_hint': 'उदा. ९८२२०१२३४५',
      'enter_name': 'किसान का पूरा नाम',
      'name_hint': 'उदा. रमेश पाटील',
      'select_district': 'ज़िला चुनें',
      'select_state': 'राज्य चुनें',
      'login_btn': 'सीधे लॉगिन करें',
      'register_btn': 'पंजीकरण करें व शुरू करें',
      'secure_passwordless': 'सुरक्षित ऑफ़लाइन पहचान (पासवर्ड रहित OTP)',

      // App Permissions Flow Screen
      'permissions_title': 'अनुमतियाँ व प्राथमिकताएँ',
      'permissions_subtitle': 'सटीक सेवा के लिए कृपया निम्नलिखित अनुमतियाँ प्रदान करें',
      'step_language': '१. भाषा चुनें',
      'step_location': '२. लोकेशन अनुमति (GPS)',
      'step_camera': '३. कैमरा व स्टोरेज अनुमति',
      'location_desc': 'स्थानीय मौसम, छिड़काव परामर्श और बीमारी अलर्ट के लिए',
      'camera_desc': 'फसल की पत्तियों के फोटो लेकर AI रोग निदान हेतु',
      'location_granted': 'लोकेशन सक्रिय है (GPS ऑन)',
      'camera_granted': 'कैमरा अनुमति स्वीकृत',
      'grant_location': 'लोकेशन अनुमति दें',
      'grant_camera': 'कैमरा अनुमति दें',
      'audio_guide_play': 'ऑडियो मार्गदर्शन सुनें',
      'audio_guide_stop': 'मार्गदर्शन रोकें',

      // Home Dashboard Screen
      'home_greeting': 'नमस्ते, किसान मित्र',
      'home_scan_hero_title': 'पत्तियों की AI रोग जांच',
      'home_scan_hero_desc': 'पत्ती का फोटो लें और तुरंत ICAR सत्यापित समाधान पाएं',
      'tap_to_scan': 'स्कैनर शुरू करें',
      'weather_advisory_good': 'छिड़काव के लिए मौसम अनुकूल है',
      'weather_advisory_rain': 'बारिश की संभावना — आज छिड़काव न करें',
      'quick_links': 'प्रमुख किसान सेवाएं',
      'quick_weather': 'मौसम पूर्वानुमान',
      'quick_schemes': 'सरकारी योजनाएं',
      'quick_npk': 'खाद कैलकुलेटर (NPK)',
      'quick_history': 'पुराने स्कैन',
      'quick_experts': 'विशेषज्ञ सलाह',
      'quick_guides': 'जैविक मार्गदर्शिका',
      'outbreak_alert_badge': 'रोग प्रकोप चेतावनी',

      // Scanner Screen
      'hold_leaf_steady': 'पत्ती स्थिर रखें',
      'gallery': 'गैलरी',
      'flash': 'फ्लैश',
      'capture': 'फोटो लें',
      'retake_title': 'स्पष्ट फोटो आवश्यक',
      'retake_subtitle': 'सटीक रोग पहचान के लिए पत्ती के केंद्र में अच्छी रोशनी में फोटो लें.',
      'try_again': 'दोबारा कोशिश करें',
      'processing_leaf': 'पत्ती का AI विश्लेषण जारी है...',

      // Diagnosis Details Screen
      'diagnosis_result': 'फसल रोग परिणाम',
      'leaf_photo_tab': 'पत्ती फोटो',
      'damage_spot_tab': 'रोग ग्रस्त भाग (AI)',
      'listen_result': 'परिणाम सुनें',
      'stop_listening': 'रोकें',
      'severity_low': 'कम असर',
      'severity_medium': 'मध्यम असर',
      'severity_high': 'गंभीर असर',
      'severity_critical': 'अति-गंभीर असर',
      'see_cure_steps': 'चरण-दर-चरण उपचार देखें',
      'ask_expert_free': 'पूरी तरह निश्चित नहीं — विशेषज्ञ से पूछें (मुफ्त)',
      'scientist_details': '🔬 वैज्ञानिक / AI तकनीकी विवरण',
      'healthy_verdict': 'फसल स्वस्थ है',
      'confidence_score': 'AI सटीकता स्तर',
      'offline_edge_mode': 'ऑफ़लाइन एज मोड (४५ फसलें सक्षम)',

      // Clinical 4-State Safety Banners
      'banner_confirmed_biotic': 'पुष्ट जैविक बीमारी: प्रमाणित उपचार नीचे दिए गए हैं',
      'banner_needs_review': 'संभावित लक्षण: सटीकता हेतु केवीके विशेषज्ञ समीक्षा आवश्यक',
      'banner_abiotic': 'पोषण की कमी: रासायनिक दवा न छिड़कें, संतुलित खाद दें',
      'banner_ood': 'अस्पष्ट पत्ती: कृपया पत्ती का स्पष्ट फोटो लें',

      // Step-by-step Treatment Guide
      'cure_guide_title': 'चरण-दर-चरण उपचार',
      'step1_title': 'चरण १: खेत की देखरेख व सफाई',
      'step2_title': 'चरण २: प्राकृतिक / जैविक छिड़काव',
      'step3_title': 'चरण ३: सुरक्षित रासायनिक दवा',
      'dosage_tank': '💧 १५ लीटर पंप टैंक',
      'dosage_dose': '🥄 अनुशंसित मात्रा',
      'dosage_time': '🕒 सुबह या शाम छिड़काव करें',
      'dosage_ppe': '🧤 मास्क और दस्ताने पहनें',
      'safety_lock_title': 'रासायनिक दवा सुरक्षा कारणों से लॉक है',
      'safety_lock_desc': 'कम आत्मविश्वास या पोषण की कमी के कारण अनावश्यक रासायनिक छिड़काव से बचें. पहले केवीके विशेषज्ञ से पुष्टि करें.',
      'verify_with_kvk': 'केवीके विशेषज्ञ से संपर्क करें',
      'icar_attribution': 'आईसीएआर संदर्भ व सुरक्षा जानकारी',

      // Recovery Tracker & My Crops
      'my_crops_title': 'मेरी फसलें व डायरी',
      'getting_better': 'सुधार हो रहा है',
      'needs_check': 'जांच आवश्यक',
      'scan_same_crop_again': '+ इसी फसल का दोबारा फोटो लें',
      'view_progress_graph': 'प्रगति ग्राफ देखें',
      'past_scans': 'पुराने स्कैन रिकॉर्ड',

      // Regional Outbreak Radar
      'alerts_title': 'मौसम व रोग अलर्ट',
      'rain_do_not_spray': '🌧️ आज बारिश — छिड़काव न करें',
      'clear_safe_to_spray': '☀️ साफ मौसम — छिड़काव के लिए सुरक्षित',
      'center_on_my_farm': 'मेरा खेत',
      'nearby_outbreaks': 'आसपास के रोग अलर्ट',
      'km_away': 'किमी दूर',
      'radar_title': 'रोग प्रकोप रडार व हीटमैप',
      'radar_subtitle': 'आपके क्षेत्र में सक्रिय रोग संक्रमण',
      'radius_km': 'किमी दायरा',

      // Agricultural Experts Directory
      'need_help_doctor': 'मदद चाहिए? फसल डॉक्टर से बात करें',
      'call_button': '📞 कॉल करें',
      'send_leaf_photo': '💬 पत्ती फोटो भेजें',
      'filter_all': 'सभी',
      'filter_paddy': 'धान',
      'filter_tomato': 'टमाटर',
      'filter_sugarcane': 'गन्ना',
      'filter_wheat': 'गेहूं',
      'experts_title': 'ICAR सत्यापित कृषि वैज्ञानिक',
      'expert_available': 'सलाह देने हेतु उपलब्ध',

      // User Profile Screen
      'user_profile_title': 'किसान प्रोफाइल व पहचान',
      'farmer_name_label': 'नाम',
      'mobile_label': 'मोबाइल',
      'location_label': 'स्थान',
      'update_via_gps': 'GPS से अपडेट करें',
      'verified_farmer_badge': '✓ ICAR सत्यापित किसान',
      'settings_section': 'ऐप सेटिंग्स व प्राथमिकताएं',
      'voice_guidance_toggle': 'आवाज मार्गदर्शन (Kisan Vani)',
      'weather_notifications_toggle': 'मौसम व बीमारी अलर्ट',
      'helpline_support': 'किसान सहायता केंद्र व हेल्पलाइन',
      'kisan_call_center': 'किसान कॉल सेंटर (भारत सरकार) - १८००-१८०-१५५१',
      'logout_btn': 'लॉगआउट करें',

      // Side Navigation Drawer
      'menu_home': 'मुख्य पृष्ठ',
      'menu_scan': 'नई फसल जांच',
      'menu_history': 'स्कैन इतिहास',
      'menu_my_crops': 'मेरी फसलें',
      'menu_radar': 'रोग प्रकोप रडार',
      'menu_experts': 'कृषि वैज्ञानिक',
      'menu_schemes': 'NGO सहायता (NGO Support)',
      'menu_weather': 'मौसम पूर्वानुमान',
      'menu_npk': 'NPK खाद कैलकुलेटर',
      'menu_profile': 'मेरी प्रोफाइल',
      'menu_help': 'किसान सहायता व संपर्क',
      'offline_status_active': 'ऑफ़लाइन डेटाबेस सक्रिय',

      // Assistance Hub & Applications
      'assistance_hub_title': 'किसानसेतु सहायता केंद्र (Assistance Hub)',
      'assistance_hub_subtitle': 'फसल नुकसान मुआवजा, खाद, उपकरण व वैज्ञानिक सहायता',
      'apply_now': 'आवेदन करें',
      'application_submitted': 'आवेदन सफलतापूर्वक जमा किया गया!',
      'ticket_id': 'आवेदन क्रमांक',
      'aid_category_financial': 'वित्तीय नुकसान मुआवजा',
      'aid_category_equipment': 'कृषि यंत्र व उपकरण सब्सिडी',
      'aid_category_inputs': 'बीज व जैविक खाद सहायता',
      'aid_category_emergency': 'आपातकालीन फसल बीमा दावा',
      'aid_category_technical': 'वैज्ञानिक मार्गदर्शन व मृदा परीक्षण',
      'aid_category_ngo': 'NGO व CSR संस्थान सहायता',
      'claim_amount': 'अनुमानित राशि',
      'acreage': 'खेत का क्षेत्रफल (एकड़)',
      'damage_percentage': 'नुकसान प्रतिशत (%)',
      'required_documents': 'आवश्यक दस्तावेज',
      'select_support_type': 'सहायता का प्रकार चुनें',
      'select_ngo': 'पंजीकृत NGO चुनें',

      // Crops
      'crop_tomato': 'टमाटर',
      'crop_potato': 'आलू',
      'crop_corn': 'मक्का',
      'crop_cotton': 'कपास',
      'crop_sugarcane': 'गन्ना',
      'crop_wheat': 'गेहूं',
      'crop_rice': 'धान',
      'crop_grape': 'अंगूर',
      'crop_apple': 'सेब',
      'crop_soybean': 'सोयाबीन',
      'crop_chilli': 'मिर्च',

      // Common Diseases
      'disease_tomato_early_blight': 'टमाटर अगेती झुलसा',
      'disease_tomato_late_blight': 'टमाटर पछेती झुलसा',
      'disease_tomato_septoria_leaf_spot': 'टमाटर सेप्टोरिया पत्ती धब्बा',
      'disease_tomato_bacterial_spot': 'टमाटर जीवाणु धब्बा',
      'disease_potato_early_blight': 'आलू अगेती झुलसा',
      'disease_potato_late_blight': 'आलू पछेती झुलसा',
      'disease_abiotic_nitrogen_deficiency': 'नाइट्रोजन पोषक तत्व की कमी',
      'disease_abiotic_phosphorus_deficiency': 'फास्फोरस पोषक तत्व की कमी',
      'disease_abiotic_potassium_deficiency': 'पोटेशियम पोषक तत्व की कमी',
      'disease_not_a_leaf_background': 'पत्ती का स्पष्ट फोटो नहीं',
      'disease_healthy': 'स्वस्थ फसल',

      // Supplementary Presentation & Modal Keys
      'reference_id': 'संदर्भ संख्या:',
      'track_status': 'स्थिति ट्रैक करें',
      'urgent_claim_registered': 'आपातकालीन दावा पंजीकृत!',
      'doc_type': 'दस्तावेज़ प्रकार:',
      'compliance_status': 'अनुपालन स्थिति:',
      'security_policy': 'सुरक्षा नीति:',
      'zero_raw_id_storage': 'कोई भी मूल पहचान पत्र संग्रहीत नहीं किया जाता',
      'verified_on_record': 'सत्यापित व रिकॉर्ड पर',
      'pending_verification': 'सत्यापन लंबित',
      'mark_as_pending': 'लंबित चिह्नित करें',
      'mark_as_verified': 'सत्यापित चिह्नित करें',
      'close_telemetry_drawer': 'टेलीमेट्री ड्रॉअर बंद करें',
      'safety_ppe_precaution': 'सुरक्षा व पीपीई सावधानी:',
      'standard_icar_sufficient': 'मानक ICAR कृषि व जैविक पद्धतियां पर्याप्त हैं.',
      'reset_scanner': 'स्कैनर रीसेट करें',
      'view_report': 'रिपोर्ट देखें',
      'ask_kvk_expert': 'KVK विशेषज्ञ से पूछें',
      'pathogen_label': 'रोगज़नक़:',
      'active_cases_label': 'सक्रिय पुष्ट मामले:',
      'icar_advisory_title': 'ICAR अनुशंसित एहतियाती सलाह:',
      'acknowledge_advisory': 'सलाह स्वीकार करें',
      'location_calibrated': 'स्थान कैलिब्रेट किया गया',
      'continue_to_app': 'किसानसेतु में आगे बढ़ें',
      'profile_updated_gps': 'GPS द्वारा प्रोफाइल अपडेट की गई',
      'open_smart_camera': 'स्मार्ट कैमरा खोलें',
      'start_first_scan': 'पहला फसल स्कैन करें',
      'first_scan_desc': 'फसल की पत्ती का फोटो लेकर पहला रोग निदान प्राप्त करें.',
      'scan_another_crop': 'दूसरी फसल स्कैन करें',
      'improving_status': '↑ सुधार हो रहा है',
      'condition_label': 'स्थिति',
      'recovery_progress': 'सुधार प्रगति',
      'day_label': 'दिन',
      'recheck_crop': 'इस फसल की पुन: जांच करें',
      'select_crop': 'फसल चुनें',
      'land_area': 'भूमि क्षेत्र',
      'unit': 'इकाई',
      'unit_acre': 'एकड़',
      'unit_guntha': 'गुंठा',
      'soil_fertility_status': 'मृदा परीक्षण उर्वरता स्तर:',
      'fertility_low': 'कम',
      'fertility_medium': 'मध्यम',
      'fertility_high': 'अधिक',
      'no_matching_icar_guide': 'कोई मेल खाने वाली ICAR गाइड नहीं मिली',
      'pathological_etiology': 'रोग का कारण व प्रकार:',
      'key_diagnostic_symptoms': 'प्रमुख रोग निदान लक्षण:',
      'cultural_preventive_practices': 'कृषि एवं निवारक उपाय:',
      'icar_spraying_practices': 'ICAR छिड़काव सर्वोत्तम पद्धतियां',
      'spray_tip_1': '• गर्मी से दवा का असर कम न हो, इसलिए सुबह ९ बजे से पहले या शाम ४:३० के बाद छिड़काव करें.',
      'spray_tip_2': '• पड़ोसी फसलों पर छिड़काव बहने से रोकने के लिए १५ किमी/घंटा से अधिक हवा होने पर कभी छिड़काव न करें.',
      'spray_tip_3': '• छिड़काव के २ घंटे के भीतर बारिश होने पर जैविक दवा धुल सकती है, पुनः छिड़काव की आवश्यकता हो सकती है.',
      'copied_to_clipboard': 'क्लिपबोर्ड पर कॉपी किया गया',
      'ticket_registered': 'शिकायत / पूछताछ पंजीकृत',
      'ticket_registered_desc': 'आपकी शिकायत दर्ज कर ली गई है। केवीके कृषि विशेषज्ञ शीघ्र इसकी समीक्षा करेंगे।',
      'ticket_saved_offline': 'ऑफ़लाइन सुरक्षित किया गया। इंटरनेट उपलब्ध होने पर सिंक होगा।',
      'issue_category': 'समस्या की श्रेणी',
      'describe_question': 'अपना प्रश्न या अवलोकन बताएं',
      'describe_question_hint': 'देखे गए लक्षण, खेत का स्थान या ऐप की समस्या लिखें...',
      'contact_phone_optional': 'संपर्क फोन / व्हाट्सएप (वैकल्पिक)',
      'submit_ticket_kvk': 'KVK डेस्क को टिकट जमा करें',
      'search_expert_hint': 'विशेषज्ञ का नाम, संस्थान या जिला खोजें...',
      'call_desk': 'कॉल करें',
      'calling_expert': 'कॉल जोड़ रहे हैं',
      'request_second_opinion': 'दूसरी राय का अनुरोध करें',
      'assigned_expert': 'नियुक्त विशेषज्ञ',
      'expert_institution': 'संस्थान',
      'attached_scan_id': 'संलग्न स्कैन आईडी',
      'preliminary_diagnosis': 'AI प्रारंभिक निदान',
      'add_expert_notes': 'वैज्ञानिक के लिए नोट्स या देखे गए लक्षण जोड़ें:',
      'expert_notes_hint': 'उदा. लगातार बारिश के बाद ३ दिन पहले पत्तियां पीली पड़ने लगीं...',
      'submit_second_opinion': 'दूसरी राय का टिकट जमा करें',
      'second_opinion_submitted': 'विशेषज्ञ को टिकट जमा किया गया! आपको शीघ्र सलाह मिलेगी।',
      'expert_label': 'विशेषज्ञ',
      'query_label': 'प्रश्न',
      'response_label': 'उत्तर',
      'no_schemes_found': 'इस श्रेणी में कोई योजना उपलब्ध नहीं है',
      'view_all': 'सभी देखें',
      'apply_for_scheme': 'इस योजना के लिए आवेदन करें',
      'could_not_access_image': 'फोटो लोड नहीं हो सका',
      'attach_crop_damage_photo': 'क्षतिग्रस्त फसल का फोटो संलग्न करें',
      'capture_with_camera': 'कैमरे से फोटो खींचें',
      'select_from_gallery': 'गैलरी से चुनें',
      'submission_queued_offline': 'आवेदन ऑफ़लाइन सुरक्षित किया गया। इंटरनेट आने पर सबमिट होगा।',
      'affected_crops_hint': 'उदा. टमाटर, कपास, गन्ना, प्याज',
      'calamity_desc_hint': 'आपदा की तारीख, जलभराव या प्रभावित क्षेत्र का विवरण लिखें...',
      'acreage_hint': 'उदा. २.५',
      'equipment_desc_hint': 'उदा. बैटरी चालित १६ लीटर नैपसैक स्प्रेयर...',
      'crops_hint': 'उदा. टमाटर, कपास, गन्ना, सोयाबीन',
      'acreage_num_hint': 'उदा. २',
      'inputs_desc_hint': 'उदा. रोग प्रतिरोधी संकरित बीज या जैविक कवकनाशी...',
      'financial_desc_hint': 'उदा. बीमारी से नुकसान के बाद २ एकड़ टमाटर में ड्रिप सिंचाई हेतु सब्सिडी...',
      'select_ngo_validation': 'कृपया सूची से सत्यापित NGO चुनें',
      'search_ngo_hint': 'नाम, जिला या पिनकोड द्वारा NGO खोजें...',
      'no_ngo_found': 'खोज से मेल खाती कोई NGO नहीं मिली',
      'ngo_desc_hint': 'अपनी वर्तमान स्थिति, नुकसान या आवश्यक सहायता का विवरण लिखें...',
      'tech_desc_hint': 'उदा. टमाटर की पत्तियों में पीली नसें दिख रही हैं, जैविक छिड़काव पर मार्गदर्शन चाहिए...',
    },

    // -------------------------------------------------------------------------
    // 3. ENGLISH
    // -------------------------------------------------------------------------
    'en': {
      'app_title': 'KisanSetu',
      'tab_scan': 'Scan',
      'tab_my_crops': 'My Crops',
      'tab_alerts': 'Alerts',
      'tab_experts': 'Experts',
      'partner_portal': 'Partner Portal',
      'btn_submit': 'Submit Application',
      'btn_cancel': 'Cancel',
      'btn_save': 'Save',
      'btn_update': 'Update',
      'btn_back': 'Back',
      'btn_close': 'Close',
      'btn_retry': 'Try Again',
      'btn_next': 'Next',
      'btn_continue': 'Continue',
      'loading': 'Loading...',

      // Welcome & Registration Screen
      'welcome_title': 'Welcome to KisanSetu',
      'welcome_subtitle': 'AI Crop Health Diagnostic & Agronomic Advisory',
      'enter_mobile': 'Enter 10-Digit Mobile Number',
      'mobile_hint': 'e.g. 9822012345',
      'enter_name': 'Full Farmer Name',
      'name_hint': 'e.g. Ramesh Patil',
      'select_district': 'Select District',
      'select_state': 'Select State',
      'login_btn': 'Instant Login',
      'register_btn': 'Register & Start',
      'secure_passwordless': 'Secure Offline Identity (Passwordless OTP)',

      // App Permissions Flow Screen
      'permissions_title': 'App Permissions & Setup',
      'permissions_subtitle': 'KisanSetu requires these permissions for accurate on-field diagnostics',
      'step_language': '1. Choose Preferred Language',
      'step_location': '2. Location Access (GPS)',
      'step_camera': '3. Camera & Storage Access',
      'location_desc': 'Enables hyper-local weather alerts, spray delays, and outbreak mapping',
      'camera_desc': 'Enables leaf photography for on-device AI pathology diagnosis',
      'location_granted': 'Location Active (GPS Calibrated)',
      'camera_granted': 'Camera Access Granted',
      'grant_location': 'Grant Location Access',
      'grant_camera': 'Grant Camera Access',
      'audio_guide_play': 'Play Audio Guidance',
      'audio_guide_stop': 'Stop Guidance',

      // Home Dashboard Screen
      'home_greeting': 'Hello, Kisan Mitra',
      'home_scan_hero_title': 'AI Foliar Leaf Pathology Scan',
      'home_scan_hero_desc': 'Photograph leaf foliage for instant ICAR-verified agronomic remedies',
      'tap_to_scan': 'Tap to Scan Leaf',
      'weather_advisory_good': 'Conditions favorable for spray application',
      'weather_advisory_rain': 'Rain forecast — Delay chemical spray today',
      'quick_links': 'Essential Agronomic Services',
      'quick_weather': 'Weather Forecast',
      'quick_schemes': 'Govt Schemes',
      'quick_npk': 'NPK Calculator',
      'quick_history': 'Scan History',
      'quick_experts': 'Expert Help',
      'quick_guides': 'Organic Guides',
      'outbreak_alert_badge': 'Regional Outbreak Alerts',

      // Scanner Screen
      'hold_leaf_steady': 'Hold leaf steady',
      'gallery': 'Gallery',
      'flash': 'Flash',
      'capture': 'Capture Photo',
      'retake_title': 'Clear Photo Needed',
      'retake_subtitle': 'Hold phone steady in daylight and align leaf in frame.',
      'try_again': 'Try Again',
      'processing_leaf': 'Running On-Device Edge ML Inference...',

      // Diagnosis Details Screen
      'diagnosis_result': 'Diagnosis Result',
      'leaf_photo_tab': 'Leaf Photo',
      'damage_spot_tab': 'Damage Spot (AI)',
      'listen_result': 'Listen to Result',
      'stop_listening': 'Stop',
      'severity_low': 'Low Spread',
      'severity_medium': 'Medium Spread',
      'severity_high': 'High Spread',
      'severity_critical': 'Critical Severity',
      'see_cure_steps': 'See Step-by-Step Remedies',
      'ask_expert_free': 'Not 100% Sure — Ask an Expert Free',
      'scientist_details': '🔬 Scientist / AI Details',
      'healthy_verdict': 'Crop is Healthy',
      'confidence_score': 'AI Confidence Score',
      'offline_edge_mode': 'Offline Edge Mode (45-Class LiteRT)',

      // Clinical 4-State Safety Banners
      'banner_confirmed_biotic': 'Confirmed Biotic Pathology: Verified ICAR IPM treatment protocol available',
      'banner_needs_review': 'Ambiguous Symptoms: Verification with accredited KVK agronomist required',
      'banner_abiotic': 'Abiotic Nutrient Deficiency: Do not apply fungicides; correct soil nutrition',
      'banner_ood': 'Non-Foliar Subject: Please photograph an active crop leaf foliage in frame',

      // Step-by-step Treatment Guide
      'cure_guide_title': 'Step-by-Step Treatment Guide',
      'step1_title': 'Step 1: Cultural Sanitation & Agronomy',
      'step2_title': 'Step 2: Natural & Bio-formulations',
      'step3_title': 'Step 3: Safe Targeted Chemistry',
      'dosage_tank': '💧 15L Knapsack Tank',
      'dosage_dose': '🥄 Recommended Dose',
      'dosage_time': '🕒 Apply in morning or late evening',
      'dosage_ppe': '🧤 Wear Protective Gloves & Mask',
      'safety_lock_title': 'Chemical Spray Locked for Safety',
      'safety_lock_desc': 'Chemical spray is locked to prevent misapplication. Verify with an accredited KVK agronomist first.',
      'verify_with_kvk': 'Connect with KVK Agronomist',
      'icar_attribution': 'ICAR Reference & Safety Protocol',

      // Recovery Tracker & My Crops
      'my_crops_title': 'My Crops & Field Diary',
      'getting_better': 'Getting Better',
      'needs_check': 'Needs Check',
      'scan_same_crop_again': '+ Scan Same Crop Again',
      'view_progress_graph': 'View Progress Graph',
      'past_scans': 'Scan History & Telemetry',

      // Regional Outbreak Radar
      'alerts_title': 'Nearby Outbreak Alerts',
      'rain_do_not_spray': '🌧️ Rain Today — Do Not Spray',
      'clear_safe_to_spray': '☀️ Clear — Safe to Spray',
      'center_on_my_farm': 'My Farm',
      'nearby_outbreaks': 'Nearby Outbreak Reports',
      'km_away': 'km away',
      'radar_title': 'Outbreak Radar & Spatial Heatmap',
      'radar_subtitle': 'Active localized disease surges near your field',
      'radius_km': 'km Radius',

      // Agricultural Experts Directory
      'need_help_doctor': 'Need Help? Talk to a Crop Doctor',
      'call_button': '📞 Call',
      'send_leaf_photo': '💬 Send Leaf Photo',
      'filter_all': 'All',
      'filter_paddy': 'Paddy',
      'filter_tomato': 'Tomato',
      'filter_sugarcane': 'Sugarcane',
      'filter_wheat': 'Wheat',
      'experts_title': 'ICAR Verified Agricultural Experts',
      'expert_available': 'Available for Consultation',

      // User Profile Screen
      'user_profile_title': 'Farmer Identity & Settings',
      'farmer_name_label': 'Name',
      'mobile_label': 'Mobile',
      'location_label': 'Location',
      'update_via_gps': 'Update via GPS',
      'verified_farmer_badge': '✓ Verified ICAR Farmer',
      'settings_section': 'Application Settings & Preferences',
      'voice_guidance_toggle': 'Vernacular Voice Assistance (Kisan Vani)',
      'weather_notifications_toggle': 'Weather & Outbreak Push Alerts',
      'helpline_support': 'Farmer Helplines & Support Desk',
      'kisan_call_center': 'Kisan Call Center (Govt. of India) - 1800-180-1551',
      'logout_btn': 'Log Out',

      // Side Navigation Drawer
      'menu_home': 'Home Dashboard',
      'menu_scan': 'New Crop Scan',
      'menu_history': 'Scan History',
      'menu_my_crops': 'My Crops & Health',
      'menu_radar': 'Outbreak Radar',
      'menu_experts': 'Agri Experts',
      'menu_schemes': 'NGO Support',
      'menu_weather': 'Weather Advisory',
      'menu_npk': 'NPK Calculator',
      'menu_profile': 'My Profile',
      'menu_help': 'Farmer Help & Support',
      'offline_status_active': 'Offline Database Active',

      // Assistance Hub & Applications
      'assistance_hub_title': 'KisanSetu Assistance Hub',
      'assistance_hub_subtitle': 'Crop loss compensation, equipment subsidy, bio-inputs & technical support',
      'apply_now': 'Apply Now',
      'application_submitted': 'Application Submitted Successfully!',
      'ticket_id': 'Application Ticket ID',
      'aid_category_financial': 'Financial Crop Loss Relief',
      'aid_category_equipment': 'Farm Machinery & Implements',
      'aid_category_inputs': 'Certified Seeds & Bio-Inputs',
      'aid_category_emergency': 'Emergency PMFBY Insurance Claim',
      'aid_category_technical': 'Soil Health & Technical Support',
      'aid_category_ngo': 'NGO & CSR Partner Support',
      'claim_amount': 'Estimated Claim Amount',
      'acreage': 'Farm Area (Acres)',
      'damage_percentage': 'Foliar Damage (%)',
      'required_documents': 'Required Documentation',
      'select_support_type': 'Select Assistance Category',
      'select_ngo': 'Select Registered NGO Partner',

      // Crops
      'crop_tomato': 'Tomato',
      'crop_potato': 'Potato',
      'crop_corn': 'Corn / Maize',
      'crop_cotton': 'Cotton',
      'crop_sugarcane': 'Sugarcane',
      'crop_wheat': 'Wheat',
      'crop_rice': 'Rice / Paddy',
      'crop_grape': 'Grape',
      'crop_apple': 'Apple',
      'crop_soybean': 'Soybean',
      'crop_chilli': 'Chilli / Pepper',

      // Common Diseases
      'disease_tomato_early_blight': 'Tomato Early Blight',
      'disease_tomato_late_blight': 'Tomato Late Blight',
      'disease_tomato_septoria_leaf_spot': 'Tomato Septoria Leaf Spot',
      'disease_tomato_bacterial_spot': 'Tomato Bacterial Spot',
      'disease_potato_early_blight': 'Potato Early Blight',
      'disease_potato_late_blight': 'Potato Late Blight',
      'disease_abiotic_nitrogen_deficiency': 'Nitrogen Nutrient Deficiency',
      'disease_abiotic_phosphorus_deficiency': 'Phosphorus Nutrient Deficiency',
      'disease_abiotic_potassium_deficiency': 'Potassium Nutrient Deficiency',
      'disease_not_a_leaf_background': 'Clear Foliage Photo Needed',
      'disease_healthy': 'Healthy Foliage',

      // Supplementary Presentation & Modal Keys
      'reference_id': 'Reference ID:',
      'track_status': 'Track Status',
      'urgent_claim_registered': 'Urgent Claim Registered!',
      'doc_type': 'Document Type:',
      'compliance_status': 'Compliance Status:',
      'security_policy': 'Security Policy:',
      'zero_raw_id_storage': 'Zero Raw ID Storage',
      'verified_on_record': 'Verified & On-Record',
      'pending_verification': 'Pending Verification',
      'mark_as_pending': 'Mark as Pending',
      'mark_as_verified': 'Mark as Verified',
      'close_telemetry_drawer': 'Close Telemetry Drawer',
      'safety_ppe_precaution': 'Safety & PPE Precaution:',
      'standard_icar_sufficient': 'Standard ICAR cultural and biological practices are sufficient.',
      'reset_scanner': 'Reset Scanner',
      'view_report': 'View Report',
      'ask_kvk_expert': 'Ask KVK Expert',
      'pathogen_label': 'Pathogen:',
      'active_cases_label': 'Active Confirmed Cases:',
      'icar_advisory_title': 'ICAR Recommended Precautionary Advisory:',
      'acknowledge_advisory': 'Acknowledge Advisory',
      'location_calibrated': 'Location calibrated',
      'continue_to_app': 'Continue to KisanSetu',
      'profile_updated_gps': 'Profile updated via GPS',
      'open_smart_camera': 'Open Smart Camera',
      'start_first_scan': 'Start First Scan',
      'first_scan_desc': 'Point your camera at crop foliage to record your first diagnosis.',
      'scan_another_crop': 'Scan Another Crop',
      'improving_status': '↑ Improving',
      'condition_label': 'Condition',
      'recovery_progress': 'Recovery Progress',
      'day_label': 'Day',
      'recheck_crop': 'Scan This Crop Again (Re-check)',
      'select_crop': 'Select Crop',
      'land_area': 'Land Area',
      'unit': 'Unit',
      'unit_acre': 'Acre',
      'unit_guntha': 'Guntha',
      'soil_fertility_status': 'Soil Test Fertility Status:',
      'fertility_low': 'Low',
      'fertility_medium': 'Medium',
      'fertility_high': 'High',
      'no_matching_icar_guide': 'No matching ICAR protocol found',
      'pathological_etiology': 'Pathological Etiology:',
      'key_diagnostic_symptoms': 'Key Diagnostic Symptoms:',
      'cultural_preventive_practices': 'Cultural & Preventive Practices:',
      'icar_spraying_practices': 'ICAR Spraying Best Practices',
      'spray_tip_1': '• Spray either before 9:00 AM or after 4:30 PM to minimize heat degradation.',
      'spray_tip_2': '• Never spray when wind speed exceeds 15 km/h to prevent spray drift onto neighboring crops.',
      'spray_tip_3': '• If rain occurs within 2 hours of spraying, biological foliar wash-off may require re-application.',
      'copied_to_clipboard': 'copied to clipboard',
      'ticket_registered': 'Ticket Registered',
      'ticket_registered_desc': 'Your grievance/query has been recorded. A KVK specialist will review it promptly.',
      'ticket_saved_offline': 'Saved offline. Ticket will synchronize once connectivity is restored.',
      'issue_category': 'Issue Category',
      'describe_question': 'Describe your question or observation',
      'describe_question_hint': 'Enter symptoms observed, field location, or app issue...',
      'contact_phone_optional': 'Contact Phone / WhatsApp (Optional)',
      'submit_ticket_kvk': 'SUBMIT TICKET TO KVK DESK',
      'search_expert_hint': 'Search expert name, institution, or district...',
      'call_desk': 'Call Desk',
      'calling_expert': 'Calling',
      'request_second_opinion': 'Request 2nd Opinion',
      'assigned_expert': 'Assigned Expert',
      'expert_institution': 'Institution',
      'attached_scan_id': 'Attached Scan ID',
      'preliminary_diagnosis': 'AI Preliminary Diagnosis',
      'add_expert_notes': 'Add Notes or Observed Symptoms for the Scientist:',
      'expert_notes_hint': 'e.g. Yellowing started 3 days ago after continuous rain...',
      'submit_second_opinion': 'Submit 2nd-Opinion Ticket',
      'second_opinion_submitted': 'Ticket submitted to expert! You will receive advisory notification.',
      'expert_label': 'Expert',
      'query_label': 'Query',
      'response_label': 'Response',
      'no_schemes_found': 'No programs match this category filter',
      'view_all': 'View All',
      'apply_for_scheme': 'Apply for this Scheme',
      'could_not_access_image': 'Could not access image',
      'attach_crop_damage_photo': 'Attach Damaged Crop Photo Evidence',
      'capture_with_camera': 'Capture with Camera',
      'select_from_gallery': 'Select from Gallery',
      'submission_queued_offline': 'Submission queued offline. Will sync once connected.',
      'affected_crops_hint': 'e.g. Tomato, Cotton, Sugarcane, Onion',
      'calamity_desc_hint': 'Describe calamity incident date, acreage washed out, or waterlogging depth...',
      'acreage_hint': 'e.g. 2.5',
      'equipment_desc_hint': 'e.g. Battery-operated dual nozzle knapsack sprayer with 16L capacity...',
      'crops_hint': 'e.g. Tomato, Cotton, Sugarcane, Soybean',
      'acreage_num_hint': 'e.g. 2',
      'inputs_desc_hint': 'e.g. Hybrid seed variety resistant to leaf curl, or bio-fungicide pack...',
      'financial_desc_hint': 'e.g. Subsidy for drip installation in 2-acre tomato field after disease loss...',
      'select_ngo_validation': 'Please select a verified NGO partner from the list',
      'search_ngo_hint': 'Search NGO by name, district, or pin code...',
      'no_ngo_found': 'No verified NGO found matching your search',
      'ngo_desc_hint': 'Describe your current farming situation, damage incurred, or support required...',
      'tech_desc_hint': 'e.g. Yellow veins on tomato leaves, need guidance on organic spray intervals...',
    },
  };
}
