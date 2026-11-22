import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/models/florax_models.dart';

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

  static FarmerLanguage fromCode(String code) {
    switch (code.toLowerCase()) {
      case 'hi':
      case 'hi-in':
        return FarmerLanguage.hindi;
      case 'en':
      case 'en-in':
        return FarmerLanguage.english;
      case 'mr':
      case 'mr-in':
      default:
        return FarmerLanguage.marathi;
    }
  }
}

/// Comprehensive Localization Dictionary for Daylight Kisan Design System
class FarmerLocalization {
  final FarmerLanguage lang;
  const FarmerLocalization(this.lang);

  // Bottom Navigation
  String get tabScan => lang == FarmerLanguage.marathi ? 'स्कॅन' : (lang == FarmerLanguage.hindi ? 'स्कैन' : 'Scan');
  String get tabMyCrops => lang == FarmerLanguage.marathi ? 'माझी पिके' : (lang == FarmerLanguage.hindi ? 'मेरी फसलें' : 'My Crops');
  String get tabAlerts => lang == FarmerLanguage.marathi ? 'सतर्कता' : (lang == FarmerLanguage.hindi ? 'अलर्ट्स' : 'Alerts');
  String get tabExperts => lang == FarmerLanguage.marathi ? 'तज्ज्ञ' : (lang == FarmerLanguage.hindi ? 'विशेषज्ञ' : 'Experts');
  String get partnerPortal => lang == FarmerLanguage.marathi ? 'संस्था पोर्टल' : (lang == FarmerLanguage.hindi ? 'संस्थान पोर्टल' : 'Partner Portal');

  // Scanner (Screen 1)
  String get holdLeafSteady => lang == FarmerLanguage.marathi ? 'पान स्थिर धरा' : (lang == FarmerLanguage.hindi ? 'पत्ती स्थिर रखें' : 'Hold leaf steady');
  String get gallery => lang == FarmerLanguage.marathi ? 'गॅलरी' : (lang == FarmerLanguage.hindi ? 'गैलरी' : 'Gallery');
  String get flash => lang == FarmerLanguage.marathi ? 'फ्लॅश' : (lang == FarmerLanguage.hindi ? 'फ्लैश' : 'Flash');
  String get capture => lang == FarmerLanguage.marathi ? 'फोटो काढा' : (lang == FarmerLanguage.hindi ? 'फोटो लें' : 'Capture');
  String get retakeTitle => lang == FarmerLanguage.marathi ? 'स्पष्ट फोटो आवश्यक' : (lang == FarmerLanguage.hindi ? 'स्पष्ट फोटो आवश्यक' : 'Clear Photo Needed');
  String get retakeSubtitle => lang == FarmerLanguage.marathi 
      ? 'रोगाचे अचूक निदान होण्यासाठी पानाच्या मध्यभागी स्वच्छ प्रकाशात फोटो घ्या.' 
      : (lang == FarmerLanguage.hindi 
          ? 'सटीक रोग पहचान के लिए पत्ती के केंद्र में अच्छी रोशनी में फोटो लें.' 
          : 'Hold phone steady in daylight and align leaf in frame.');
  String get tryAgain => lang == FarmerLanguage.marathi ? 'पुन्हा प्रयत्न करा' : (lang == FarmerLanguage.hindi ? 'दोबारा कोशिश करें' : 'Try Again');

  // Diagnosis (Screen 2)
  String get diagnosisResult => lang == FarmerLanguage.marathi ? 'पीक निदान अहवाल' : (lang == FarmerLanguage.hindi ? 'फसल रोग परिणाम' : 'Diagnosis Result');
  String get leafPhotoTab => lang == FarmerLanguage.marathi ? 'पानाचा फोटो' : (lang == FarmerLanguage.hindi ? 'पत्ती फोटो' : 'Leaf Photo');
  String get damageSpotTab => lang == FarmerLanguage.marathi ? 'रोगग्रस्त जागा (AI)' : (lang == FarmerLanguage.hindi ? 'रोग ग्रस्त भाग (AI)' : 'Damage Spot (AI)');
  String get listenResult => lang == FarmerLanguage.marathi ? 'निदान ऐका' : (lang == FarmerLanguage.hindi ? 'परिणाम सुनें' : 'Listen to Result');
  String get stopListening => lang == FarmerLanguage.marathi ? 'थांबवा' : (lang == FarmerLanguage.hindi ? 'रोकें' : 'Stop');
  String get severityLow => lang == FarmerLanguage.marathi ? 'कमी प्रसार' : (lang == FarmerLanguage.hindi ? 'कम असर' : 'Low');
  String get severityMedium => lang == FarmerLanguage.marathi ? 'मध्यम प्रसार' : (lang == FarmerLanguage.hindi ? 'मध्यम असर' : 'Medium');
  String get severityHigh => lang == FarmerLanguage.marathi ? 'गंभीर प्रसार' : (lang == FarmerLanguage.hindi ? 'गंभीर असर' : 'High');
  String get seeCureSteps => lang == FarmerLanguage.marathi ? 'उपाय पाहा ->' : (lang == FarmerLanguage.hindi ? 'उपाय देखें ->' : 'See Cure Steps ->');
  String get askExpertFree => lang == FarmerLanguage.marathi ? 'खात्री नाही — तज्ज्ञांचा सल्ला घ्या (मोफत)' : (lang == FarmerLanguage.hindi ? 'पूरी तरह निश्चित नहीं — विशेषज्ञ से पूछें (मुफ्त)' : 'Not 100% Sure — Ask an Expert Free');
  String get scientistDetails => lang == FarmerLanguage.marathi ? '🔬 शास्त्रज्ञ / AI तांत्रिक तपशील' : (lang == FarmerLanguage.hindi ? '🔬 वैज्ञानिक / AI तकनीकी विवरण' : '🔬 Scientist / AI Details');
  String get healthyVerdict => lang == FarmerLanguage.marathi ? 'पीक निरोगी आहे' : (lang == FarmerLanguage.hindi ? 'फसल स्वस्थ है' : 'Crop is Healthy');

  // Treatment / Cure Guide (Screen 3)
  String get cureGuideTitle => lang == FarmerLanguage.marathi ? 'पायरी-पायरीने उपाय' : (lang == FarmerLanguage.hindi ? 'चरण-दर-चरण उपचार' : 'Step-by-Step Cure Guide');
  String get step1Title => lang == FarmerLanguage.marathi ? 'पायरी १: शेती मशागत व स्वच्छता' : (lang == FarmerLanguage.hindi ? 'चरण १: खेत की देखरेख व सफाई' : 'Step 1: Field Care');
  String get step2Title => lang == FarmerLanguage.marathi ? 'पायरी २: सेंद्रिय / जैविक फवारणी' : (lang == FarmerLanguage.hindi ? 'चरण २: प्राकृतिक / जैविक छिड़काव' : 'Step 2: Natural / Bio Spray');
  String get step3Title => lang == FarmerLanguage.marathi ? 'पायरी ३: सुरक्षित रासायनिक औषध' : (lang == FarmerLanguage.hindi ? 'चरण ३: सुरक्षित रासायनिक दवा' : 'Step 3: Safe Medicine');
  String get dosageTank => lang == FarmerLanguage.marathi ? '💧 १५ लिटर पंप टाकी' : (lang == FarmerLanguage.hindi ? '💧 १५ लीटर पंप टैंक' : '💧 15L Pump Tank');
  String get dosageDose => lang == FarmerLanguage.marathi ? '🥄 योग्य प्रमाण' : (lang == FarmerLanguage.hindi ? '🥄 अनुशंसित मात्रा' : '🥄 Recommended Dose');
  String get dosageTime => lang == FarmerLanguage.marathi ? '🕒 सकाळी किंवा संध्याकाळी' : (lang == FarmerLanguage.hindi ? '🕒 सुबह या शाम' : '🕒 Morning / Evening');
  String get dosagePpe => lang == FarmerLanguage.marathi ? '🧤 मास्क व हातमोजे वापरा' : (lang == FarmerLanguage.hindi ? '🧤 मास्क और दस्ताने पहनें' : '🧤 Wear Mask & Gloves');
  String get safetyLockTitle => lang == FarmerLanguage.marathi ? 'रासायनिक औषध सुरक्षिततेसाठी लॉक आहे' : (lang == FarmerLanguage.hindi ? 'रासायनिक दवा सुरक्षा कारणों से लॉक है' : 'Chemical Spray Locked for Safety');
  String get safetyLockDesc => lang == FarmerLanguage.marathi 
      ? 'कमी खात्री किंवा अन्नद्रव्य कमतरतेमुळे विनाकारण रासायनिक फवारणी टाळा. आधी केव्हीके तज्ज्ञांकडून खात्री करून घ्या.'
      : (lang == FarmerLanguage.hindi 
          ? 'कम आत्मविश्वास या पोषण की कमी के कारण अनावश्यक रासायनिक छिड़काव से बचें. पहले केवीके विशेषज्ञ से पुष्टि करें.'
          : 'Chemical spray is locked to prevent misapplication. Verify with an accredited KVK agronomist first.');
  String get verifyWithKvk => lang == FarmerLanguage.marathi ? 'केव्हीके तज्ज्ञांशी संपर्क साधा' : (lang == FarmerLanguage.hindi ? 'केवीके विशेषज्ञ से संपर्क करें' : 'Verify with KVK Expert');
  String get icarAttribution => lang == FarmerLanguage.marathi ? 'आय सी ए आर संदर्भ व सुरक्षितता माहिती' : (lang == FarmerLanguage.hindi ? 'आईसीएआर संदर्भ व सुरक्षा जानकारी' : 'ICAR Reference & Safety Info');

  // Recovery Tracker (Screen 4)
  String get myCropsTitle => lang == FarmerLanguage.marathi ? 'माझी पिके व सुधारणा' : (lang == FarmerLanguage.hindi ? 'मेरी फसलें व सुधार' : 'My Crops & Recovery Tracker');
  String get gettingBetter => lang == FarmerLanguage.marathi ? 'सुधारणा होत आहे' : (lang == FarmerLanguage.hindi ? 'सुधार हो रहा है' : 'Getting Better');
  String get needsCheck => lang == FarmerLanguage.marathi ? 'तपासणी आवश्यक' : (lang == FarmerLanguage.hindi ? 'जांच आवश्यक' : 'Needs Check');
  String get scanSameCropAgain => lang == FarmerLanguage.marathi ? '+ याच पिकाचा पुन्हा फोटो काढा' : (lang == FarmerLanguage.hindi ? '+ इसी फसल का दोबारा फोटो लें' : '+ Scan Same Crop Again');
  String get viewProgressGraph => lang == FarmerLanguage.marathi ? 'प्रगती आलेख पाहा' : (lang == FarmerLanguage.hindi ? 'प्रगति ग्राफ देखें' : 'View Progress Graph');
  String get pastScans => lang == FarmerLanguage.marathi ? 'मागील स्कॅन' : (lang == FarmerLanguage.hindi ? 'पुराने स्कैन' : 'Past Scans');

  // Alerts & Map (Screen 5)
  String get alertsTitle => lang == FarmerLanguage.marathi ? 'हवामान व रोग सतर्कता' : (lang == FarmerLanguage.hindi ? 'मौसम व रोग अलर्ट' : 'Nearby Outbreak Alerts');
  String get rainDoNotSpray => lang == FarmerLanguage.marathi ? '🌧️ आज पाऊस — फवारणी करू नका' : (lang == FarmerLanguage.hindi ? '🌧️ आज बारिश — छिड़काव न करें' : '🌧️ Rain Today — Do Not Spray');
  String get clearSafeToSpray => lang == FarmerLanguage.marathi ? '☀️ स्वच्छ हवामान — फवारणीस अनुकूल' : (lang == FarmerLanguage.hindi ? '☀️ साफ मौसम — छिड़काव के लिए सुरक्षित' : '☀️ Clear — Safe to Spray');
  String get centerOnMyFarm => lang == FarmerLanguage.marathi ? 'माझे शेत' : (lang == FarmerLanguage.hindi ? 'मेरा खेत' : 'My Farm');
  String get nearbyOutbreaks => lang == FarmerLanguage.marathi ? 'जवळपासचे रोग अलर्ट' : (lang == FarmerLanguage.hindi ? 'आसपास के रोग अलर्ट' : 'Nearby Outbreak Reports');
  String get kmAway => lang == FarmerLanguage.marathi ? 'किमी अंतरावर' : (lang == FarmerLanguage.hindi ? 'किमी दूर' : 'km away');

  // Experts Directory (Screen 6)
  String get needHelpDoctor => lang == FarmerLanguage.marathi ? 'मदत हवी आहे? पीक डॉक्टरांशी बोला' : (lang == FarmerLanguage.hindi ? 'मदद चाहिए? फसल डॉक्टर से बात करें' : 'Need Help? Talk to a Crop Doctor');
  String get callButton => lang == FarmerLanguage.marathi ? '📞 फोन करा' : (lang == FarmerLanguage.hindi ? '📞 कॉल करें' : '📞 Call');
  String get sendLeafPhoto => lang == FarmerLanguage.marathi ? '💬 पाटीचा फोटो पाठवा' : (lang == FarmerLanguage.hindi ? '💬 पत्ती फोटो भेजें' : '💬 Send Leaf Photo');
  String get filterAll => lang == FarmerLanguage.marathi ? 'सर्व' : (lang == FarmerLanguage.hindi ? 'सभी' : 'All');
  String get filterPaddy => lang == FarmerLanguage.marathi ? 'भात' : (lang == FarmerLanguage.hindi ? 'धान' : 'Paddy');
  String get filterTomato => lang == FarmerLanguage.marathi ? 'टोमॅटो' : (lang == FarmerLanguage.hindi ? 'टमाटर' : 'Tomato');
  String get filterSugarcane => lang == FarmerLanguage.marathi ? 'ऊस' : (lang == FarmerLanguage.hindi ? 'गन्ना' : 'Sugarcane');
  String get filterWheat => lang == FarmerLanguage.marathi ? 'गहू' : (lang == FarmerLanguage.hindi ? 'गेहूं' : 'Wheat');

  // NGO / Partner Portal (Screen 7)
  String get ngoPortalTitle => lang == FarmerLanguage.marathi ? 'एनजीओ व शेतकरी उत्पादक संघ (FPO)' : (lang == FarmerLanguage.hindi ? 'एनजीओ और एफपीओ सहायता' : 'NGO & FPO Support Network');
  String get requestSupport => lang == FarmerLanguage.marathi ? 'मदत मागा' : (lang == FarmerLanguage.hindi ? 'सहायता मांगें' : 'Request Support');
  String get viewProgram => lang == FarmerLanguage.marathi ? 'योजना पाहा' : (lang == FarmerLanguage.hindi ? 'योजना देखें' : 'View Program');

  // KVK Console (Screen 8)
  String get kvkConsoleTitle => lang == FarmerLanguage.marathi ? 'केव्हीके शास्त्रज्ञ कन्सोल' : (lang == FarmerLanguage.hindi ? 'केवीके वैज्ञानिक कंसोल' : 'KVK Scientist Console');
  String get pendingReviews => lang == FarmerLanguage.marathi ? 'प्रलंबित तपासण्या' : (lang == FarmerLanguage.hindi ? 'लंबित समीक्षा' : 'Pending Reviews');
  String get activeOutbreaks => lang == FarmerLanguage.marathi ? 'सक्रिय उद्रेक' : (lang == FarmerLanguage.hindi ? 'सक्रिय अलर्ट' : 'Active Outbreaks');
  String get verifiedToday => lang == FarmerLanguage.marathi ? 'आज पडताळलेले' : (lang == FarmerLanguage.hindi ? 'आज सत्यापित' : 'Verified Today');
  String get approveAdvisory => lang == FarmerLanguage.marathi ? 'सल्ला मंजूर करा' : (lang == FarmerLanguage.hindi ? 'सलाह मंजूर करें' : 'Approve Advisory');
  String get overrideDiagnosis => lang == FarmerLanguage.marathi ? 'निदान बदला' : (lang == FarmerLanguage.hindi ? 'निदान बदलें' : 'Override Diagnosis');
}

/// Robust VoiceGuideService for Farmer Audio Playback & Voice Assistance
class VoiceGuideService extends ChangeNotifier {
  final FlutterTts _tts;
  bool _isSpeaking = false;
  FarmerLanguage _currentLanguage = FarmerLanguage.marathi;
  String? _currentlySpeakingText;

  VoiceGuideService([FlutterTts? tts]) : _tts = tts ?? FlutterTts() {
    _initTts();
  }

  bool get isSpeaking => _isSpeaking;
  FarmerLanguage get currentLanguage => _currentLanguage;
  FarmerLocalization get strings => FarmerLocalization(_currentLanguage);

  Future<void> _initTts() async {
    try {
      _tts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _currentlySpeakingText = null;
        notifyListeners();
      });

      _tts.setErrorHandler((dynamic msg) {
        debugPrint('[VoiceGuideService ERROR] $msg');
        _isSpeaking = false;
        _currentlySpeakingText = null;
        notifyListeners();
      });

      await _tts.setSpeechRate(0.48); // Slightly measured cadence for field clarity
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setLanguage(_currentLanguage.ttsLocale);
    } catch (e) {
      // Gracefully handle headless test environments where platform channels do not exist
      debugPrint('[VoiceGuideService Safe Init] TTS channel unavailable: $e');
    }
  }

  void setLanguage(FarmerLanguage lang) {
    _currentLanguage = lang;
    try {
      _tts.setLanguage(lang.ttsLocale);
    } catch (_) {}
    notifyListeners();
  }

  /// Speaks the given text aloud. If the same text is already being spoken, stops playback.
  Future<void> speak(String text, {FarmerLanguage? lang}) async {
    final targetLang = lang ?? _currentLanguage;
    if (_isSpeaking && _currentlySpeakingText == text) {
      await stop();
      return;
    }

    try {
      await stop();
      _currentlySpeakingText = text;
      _isSpeaking = true;
      notifyListeners();

      await _tts.setLanguage(targetLang.ttsLocale);
      final result = await _tts.speak(text);
      if (result != 1) {
        // Platform returned non-success or headless
        _isSpeaking = false;
        _currentlySpeakingText = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[VoiceGuideService Safe Speak] TTS speak safely handled: $e');
      _isSpeaking = false;
      _currentlySpeakingText = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('[VoiceGuideService Safe Stop] $e');
    } finally {
      _isSpeaking = false;
      _currentlySpeakingText = null;
      notifyListeners();
    }
  }

  /// Plain-language diagnosis summary generator
  String buildDiagnosisSpokenScript({
    required String cropName,
    required String conditionName,
    required double confidence,
    required bool isHealthy,
    required bool isAbiotic,
    required bool requiresKvk,
  }) {
    final confPct = (confidence * 100).toStringAsFixed(0);
    switch (_currentLanguage) {
      case FarmerLanguage.marathi:
        if (isHealthy) {
          return 'आनंदाची बातमी! तुमचे $cropName पीक पूर्णपणे निरोगी आहे. कोणतीही फवारणी करण्याची गरज नाही.';
        }
        if (isAbiotic) {
          return 'सावधान. $cropName पिकावर $conditionName ची लक्षणे आहेत. हा कोणताही संसर्गजन्य रोग नसून जमिनीतील अन्नद्रव्यांची कमतरता आहे. कीटकनाशके फवारू नका.';
        }
        if (requiresKvk) {
          return 'लक्ष द्या. $cropName पिकावर $conditionName असण्याची शक्यता $confPct टक्के आहे. पूर्ण खात्री नसल्यामुळे रासायनिक फवारणी लॉक केली आहे. जवळच्या केव्हीके डॉक्टरांचा मोफत सल्ला घ्या.';
        }
        return '$cropName पिकावर $conditionName रोग आढळला आहे. खात्री $confPct टक्के आहे. उपाय जाणून घेण्यासाठी उपाय बटणावर क्लिक करा.';

      case FarmerLanguage.hindi:
        if (isHealthy) {
          return 'बधाई हो! आपकी $cropName की फसल पूरी तरह स्वस्थ है। किसी कीटनाशक की आवश्यकता नहीं है।';
        }
        if (isAbiotic) {
          return 'ध्यान दें। $cropName में $conditionName के लक्षण मिले हैं। यह कोई फफूंद या कीड़ा नहीं है, बल्कि पोषक तत्व की कमी है। जहरीली दवा न छिड़कें।';
        }
        if (requiresKvk) {
          return 'सावधान। $cropName में $conditionName होने की संभावना $confPct प्रतिशत है। पूरी पुष्टि न होने के कारण रासायनिक दवा लॉक है। कृपया केवीके विशेषज्ञ से निःशुल्क सलाह लें।';
        }
        return '$cropName में $conditionName की पहचान हुई है। विश्वसनीयता $confPct प्रतिशत है। सुरक्षित उपाय जानने के लिए आगे बढ़ें।';

      case FarmerLanguage.english:
        if (isHealthy) {
          return 'Great news! Your $cropName crop is completely healthy. No treatment needed.';
        }
        if (isAbiotic) {
          return 'Attention. $conditionName detected on $cropName. This is a soil nutrient deficiency, not an infection. Do not spray chemical fungicides.';
        }
        if (requiresKvk) {
          return 'Notice. $conditionName detected with $confPct percent confidence. Chemical recommendations are locked for safety. Please call a KVK agronomist.';
        }
        return '$cropName is diagnosed with $conditionName at $confPct percent confidence. Tap see cure steps for treatment.';
    }
  }

  /// Plain-language cure steps spoken script
  String buildCureSpokenScript({
    required IcarIpmProtocol protocol,
    required bool isChemicalLocked,
  }) {
    final langCode = _currentLanguage.code;
    final cultural = protocol.tier1Cultural[langCode]?.firstOrNull ?? protocol.tier1Cultural['en']?.firstOrNull ?? '';
    final biological = protocol.tier2Biological[langCode]?.firstOrNull ?? protocol.tier2Biological['en']?.firstOrNull ?? '';
    final chemical = protocol.tier3Chemical.formulationName;
    final dosage = protocol.tier3Chemical.dosagePerLitre;

    switch (_currentLanguage) {
      case FarmerLanguage.marathi:
        final b = StringBuffer();
        b.writeln('पहिली पायरी: शेताची स्वच्छता आणि मशागत — $cultural.');
        b.writeln('दुसरी पायरी: सेंद्रिय व जैविक फवारणी — $biological.');
        if (isChemicalLocked) {
          b.writeln('तिसरी पायरी: रासायनिक औषध सध्या सुरक्षिततेसाठी लॉक आहे. तज्ज्ञांच्या सल्ल्याशिवाय विषारी औषध वापरू नका.');
        } else {
          b.writeln('तिसरी पायरी: सुरक्षित रासायनिक औषध — $chemical, प्रमाण: $dosage, आणि फवारणी करताना मास्क नक्की वापरा.');
        }
        return b.toString();

      case FarmerLanguage.hindi:
        final b = StringBuffer();
        b.writeln('पहला चरण: खेत की देखभाल व सफाई — $cultural.');
        b.writeln('दूसरा चरण: जैविक व नीम छिड़काव — $biological.');
        if (isChemicalLocked) {
          b.writeln('तीसरा चरण: रासायनिक दवा सुरक्षा नियमों के तहत लॉक है। पहले विशेषज्ञ की सलाह लें।');
        } else {
          b.writeln('तीसरा चरण: रासायनिक दवा — $chemical, मात्रा: $dosage. छिड़काव के समय मास्क जरूर पहनें।');
        }
        return b.toString();

      case FarmerLanguage.english:
        final b = StringBuffer();
        b.writeln('Step 1: Field sanitation — $cultural.');
        b.writeln('Step 2: Biological spray — $biological.');
        if (isChemicalLocked) {
          b.writeln('Step 3: Chemical controls are locked pending expert verification.');
        } else {
          b.writeln('Step 3: Recommended chemical spray — $chemical at $dosage. Wear protective gear.');
        }
        return b.toString();
    }
  }

  /// Weather & Alert spoken script
  String buildWeatherSpokenScript({
    required bool isRain,
    required String summary,
  }) {
    switch (_currentLanguage) {
      case FarmerLanguage.marathi:
        return isRain 
            ? 'आज तुमच्या परिसरात पावसाची शक्यता आहे. कोणतीही औषध फवारणी करू नका, कारण औषध वाहून जाऊन नुकसान होईल.'
            : 'आज हवामान स्वच्छ व कोरडे आहे. सकाळच्या वेळी पिकावर सुरक्षित फवारणी करण्यास अनुकूल दिवस आहे.';
      case FarmerLanguage.hindi:
        return isRain
            ? 'आज आपके क्षेत्र में वर्षा की संभावना है। कृपया कोई छिड़काव न करें।'
            : 'आज मौसम साफ और अनुकूल है। सुबह के समय छिड़काव सुरक्षित रूप से किया जा सकता है।';
      case FarmerLanguage.english:
        return isRain
            ? 'Rain is forecast for today. Do not spray chemicals as they will wash off.'
            : 'Weather is clear today. Safe conditions for foliar application.';
    }
  }
}

/// Global Riverpod Provider for Active Farmer Language
final activeFarmerLanguageProvider = StateProvider<FarmerLanguage>((ref) {
  return FarmerLanguage.marathi;
});

/// Global Riverpod Provider for VoiceGuideService synchronized with active language
final voiceGuideServiceProvider = ChangeNotifierProvider<VoiceGuideService>((ref) {
  final activeLang = ref.watch(activeFarmerLanguageProvider);
  final service = VoiceGuideService();
  service.setLanguage(activeLang);
  ref.onDispose(() => service.stop());
  return service;
});
