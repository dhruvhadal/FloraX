import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../domain/models/florax_models.dart';

/// Semantic farmer intent extracted from vernacular speech
enum FarmerVoiceIntentType {
  diagnoseSymptom, // Tab 0: Scanner
  checkWeather,    // Tab 1: Outbreak Radar
  inquireTreatment, // Tab 2: Progression & Recovery
  contactKvkExpert, // Tab 3: Expert Directory
  ngoConnect,      // Tab 4: LeafGuard Connect NGOs
  unknown;

  int get targetTabIndex {
    switch (this) {
      case FarmerVoiceIntentType.diagnoseSymptom:
        return 0;
      case FarmerVoiceIntentType.checkWeather:
        return 1;
      case FarmerVoiceIntentType.inquireTreatment:
        return 2;
      case FarmerVoiceIntentType.contactKvkExpert:
        return 3;
      case FarmerVoiceIntentType.ngoConnect:
        return 4;
      case FarmerVoiceIntentType.unknown:
        return -1;
    }
  }

  String get label {
    switch (this) {
      case FarmerVoiceIntentType.diagnoseSymptom:
        return 'DIAGNOSE_SYMPTOM';
      case FarmerVoiceIntentType.checkWeather:
        return 'CHECK_WEATHER';
      case FarmerVoiceIntentType.inquireTreatment:
        return 'INQUIRE_TREATMENT';
      case FarmerVoiceIntentType.contactKvkExpert:
        return 'CONTACT_KVK_EXPERT';
      case FarmerVoiceIntentType.ngoConnect:
        return 'NGO_CONNECT';
      case FarmerVoiceIntentType.unknown:
        return 'UNKNOWN';
    }
  }
}

/// Structured intent parsed from farmer spoken utterance
@immutable
class ParsedVoiceIntent {
  final FarmerVoiceIntentType intentType;
  final String rawTranscription;
  final List<String> detectedKeywords;
  final String suggestedAction;

  int get targetTabIndex => intentType.targetTabIndex;

  const ParsedVoiceIntent({
    required this.intentType,
    required this.rawTranscription,
    required this.detectedKeywords,
    required this.suggestedAction,
  });
}

/// Reactive State for the Voice Assistant
@immutable
class VernacularVoiceState {
  final bool isListening;
  final bool isSpeaking;
  final bool isAvailable;
  final String currentTranscription;
  final ParsedVoiceIntent? lastIntent;
  final String activeLanguageCode; // 'mr-IN', 'hi-IN', 'en-IN'

  const VernacularVoiceState({
    required this.isListening,
    required this.isSpeaking,
    required this.isAvailable,
    required this.currentTranscription,
    this.lastIntent,
    this.activeLanguageCode = 'mr-IN',
  });

  VernacularVoiceState copyWith({
    bool? isListening,
    bool? isSpeaking,
    bool? isAvailable,
    String? currentTranscription,
    ParsedVoiceIntent? lastIntent,
    String? activeLanguageCode,
  }) {
    return VernacularVoiceState(
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isAvailable: isAvailable ?? this.isAvailable,
      currentTranscription: currentTranscription ?? this.currentTranscription,
      lastIntent: lastIntent ?? this.lastIntent,
      activeLanguageCode: activeLanguageCode ?? this.activeLanguageCode,
    );
  }
}

/// Principal Offline-Ready Vernacular Voice Service (Kisan Vani)
///
/// Implements Speech-to-Text (STT) and Text-to-Speech (TTS) optimized for
/// Indian agricultural linguistic dialects (Marathi `mr-IN`, Hindi `hi-IN`, English `en-IN`).
class VernacularVoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isSpeechInitialized = false;
  bool _isTtsInitialized = false;

  /// Initializes both Speech-to-Text and Text-to-Speech hardware drivers
  Future<bool> initialize() async {
    try {
      // 1. Initialize Speech Recognizer
      _isSpeechInitialized = await _speech.initialize(
        onStatus: (status) => debugPrint('[FloraX Voice] STT Status: $status'),
        onError: (err) => debugPrint('[FloraX Voice ERROR] STT Error: $err'),
      );

      // 2. Configure TTS Engine
      await _tts.setSpeechRate(0.46); // Slightly slower cadence for rural accessibility
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _isTtsInitialized = true;
      debugPrint('[FloraX Voice] Kisan Vani Speech Engine initialized successfully.');
      return _isSpeechInitialized && _isTtsInitialized;
    } catch (e) {
      debugPrint('[FloraX Voice ERROR] Voice initialization failed: $e');
      return false;
    }
  }

  // ===========================================================================
  // 1. SPOKEN IPM ADVISORY NARRATOR
  // ===========================================================================

  /// Reads out the comprehensive 3-tier ICAR IPM treatment protocol aloud in
  /// the farmer's preferred regional language (Marathi, Hindi, or English).
  Future<void> speakIpmAdvisory({
    required IcarIpmProtocol protocol,
    String langCode = 'mr', // 'mr', 'hi', or 'en'
    required bool isChemicalLocked,
    double confidencePercent = 90.0,
  }) async {
    final String ttsLocale = _mapLangCodeToTtsLocale(langCode);
    await _tts.setLanguage(ttsLocale);

    final StringBuffer speechScript = StringBuffer();

    final String diseaseName = protocol.diseaseName[langCode] ??
        protocol.diseaseName['en'] ??
        protocol.scientificName;

    // Narrative builder based on language
    if (langCode == 'mr') {
      speechScript.writeln('रोग निदान: $diseaseName. सत्यता प्रमाण: ${confidencePercent.toStringAsFixed(0)} टक्के.');
      speechScript.writeln('आय सी ए आर शिफारशीत उपाय खालीलप्रमाणे आहेत:');

      // Tier 1: Cultural
      final culturalList = protocol.tier1Cultural['mr'] ?? protocol.tier1Cultural['en'] ?? [];
      if (culturalList.isNotEmpty) {
        speechScript.writeln('पहिली पायरी: मशागतीचे उपाय.');
        for (int i = 0; i < culturalList.length; i++) {
          speechScript.writeln('${i + 1}: ${culturalList[i]}.');
        }
      }

      // Tier 2: Biological
      final bioList = protocol.tier2Biological['mr'] ?? protocol.tier2Biological['en'] ?? [];
      if (bioList.isNotEmpty) {
        speechScript.writeln('दुसरी पायरी: जैविक आणि वनस्पतिजन्य उपाय.');
        for (int i = 0; i < bioList.length; i++) {
          speechScript.writeln('${i + 1}: ${bioList[i]}.');
        }
      }

      // Tier 3: Chemical
      speechScript.writeln('तिसरी पायरी: रासायनिक नियंत्रण.');
      if (isChemicalLocked) {
        speechScript.writeln('रासायनिक उपचार सध्या लॉक आहेत. केव्हीके शास्त्रज्ञांच्या पडताळणीनंतरच औषध अनलॉक होईल. तोपर्यंत जैविक उपाय करा.');
      } else {
        speechScript.writeln('औषधाचे नाव: ${protocol.tier3Chemical.formulationName}.');
        speechScript.writeln('प्रमाण: ${protocol.tier3Chemical.dosagePerLitre}.');
        speechScript.writeln('फळ काढणी प्रतीक्षा कालावधी: ${protocol.tier3Chemical.waitingPeriodDays} दिवस.');
        final ppeList = protocol.tier3Chemical.ppeWarnings['mr'] ?? [];
        if (ppeList.isNotEmpty) {
          speechScript.writeln('सुरक्षा सूचना: ${ppeList.first}.');
        }
      }
    } else if (langCode == 'hi') {
      speechScript.writeln('रोग निदान: $diseaseName. विश्वसनीयता: ${confidencePercent.toStringAsFixed(0)} प्रतिशत.');
      speechScript.writeln('आईसीएआर अनुशंसित उपचार इस प्रकार हैं:');

      // Tier 1: Cultural
      final culturalList = protocol.tier1Cultural['hi'] ?? protocol.tier1Cultural['en'] ?? [];
      if (culturalList.isNotEmpty) {
        speechScript.writeln('पहला चरण: कृषि क्रियाएं और स्वच्छता.');
        for (int i = 0; i < culturalList.length; i++) {
          speechScript.writeln('${i + 1}: ${culturalList[i]}.');
        }
      }

      // Tier 2: Biological
      final bioList = protocol.tier2Biological['hi'] ?? protocol.tier2Biological['en'] ?? [];
      if (bioList.isNotEmpty) {
        speechScript.writeln('दूसरा चरण: जैविक नियंत्रण.');
        for (int i = 0; i < bioList.length; i++) {
          speechScript.writeln('${i + 1}: ${bioList[i]}.');
        }
      }

      // Tier 3: Chemical
      speechScript.writeln('तीसरा चरण: रासायनिक नियंत्रण.');
      if (isChemicalLocked) {
        speechScript.writeln('रासायनिक दवाएं सुरक्षा नियमों के तहत लॉक हैं। केवीके विशेषज्ञ के अनुमोदन के बाद ही अनलॉक होंगी। कृपया जैविक उपचार करें।');
      } else {
        speechScript.writeln('अनुशंसित दवा: ${protocol.tier3Chemical.formulationName}.');
        speechScript.writeln('मात्रा: ${protocol.tier3Chemical.dosagePerLitre}.');
        speechScript.writeln('प्रतीक्षा अवधि: ${protocol.tier3Chemical.waitingPeriodDays} दिन.');
      }
    } else {
      // English Fallback
      speechScript.writeln('Diagnosis: $diseaseName. Confidence: ${confidencePercent.toStringAsFixed(0)} percent.');
      speechScript.writeln('Verified ICAR Treatment Protocol:');

      final culturalList = protocol.tier1Cultural['en'] ?? [];
      if (culturalList.isNotEmpty) {
        speechScript.writeln('Stage 1: Cultural and sanitation measures: ${culturalList.first}.');
      }

      final bioList = protocol.tier2Biological['en'] ?? [];
      if (bioList.isNotEmpty) {
        speechScript.writeln('Stage 2: Biological bio-agents: ${bioList.first}.');
      }

      if (isChemicalLocked) {
        speechScript.writeln('Stage 3: Chemical controls are locked pending KVK specialist review. Please apply recommended biological controls.');
      } else {
        speechScript.writeln('Stage 3: Chemical control: ${protocol.tier3Chemical.formulationName}, Dosage: ${protocol.tier3Chemical.dosagePerLitre}, Pre-harvest interval: ${protocol.tier3Chemical.waitingPeriodDays} days.');
      }
    }

    debugPrint('[FloraX Voice] Narrating IPM advisory script (${speechScript.length} chars)...');
    await _tts.speak(speechScript.toString());
  }

  // ===========================================================================
  // 1b. SPECIALIZED AUDIO NARRATORS (Feature #13)
  // ===========================================================================

  /// Speaks generic guidance or instructions aloud in regional language
  Future<void> speak(String text, {String langCode = 'mr'}) async {
    final String ttsLocale = _mapLangCodeToTtsLocale(langCode);
    await _tts.setLanguage(ttsLocale);
    await _tts.speak(text);
  }

  /// Reads aloud image quality failure reasons and retake instructions (Feature #5 & #13)
  Future<void> speakQualityCheckFailure(
    ImageQualityReport report, {
    String langCode = 'mr',
  }) async {
    final String ttsLocale = _mapLangCodeToTtsLocale(langCode);
    await _tts.setLanguage(ttsLocale);

    final String reasons = report.failureReasons.join('. ');
    final String script;

    if (langCode == 'mr') {
      script =
          'सावधान! फोटो गुणवत्ता तपासणी अयशस्वी झाली आहे. $reasons. अचूक निदानासाठी कृपया फोन स्थिर धरा आणि सूर्यप्रकाशात पुन्हा स्पष्ट फोटो काढा.';
    } else if (langCode == 'hi') {
      script =
          'सावधान! फोटो गुणवत्ता जांच विफल रही. $reasons. सटीक पहचान के लिए कृपया फोन स्थिर रखें और पर्याप्त रोशनी में दोबारा स्पष्ट फोटो लें.';
    } else {
      script =
          'Warning! Photo quality verification failed. $reasons. Please hold your camera steady in natural daylight and retake a clear photo.';
    }

    debugPrint('[FloraX Voice] Speaking quality failure guidance...');
    await _tts.speak(script);
  }

  /// Reads aloud quantified disease severity assessment (Feature #8 & #13)
  Future<void> speakSeverityAssessment(
    SeverityGrade grade,
    double lesionPercent, {
    String langCode = 'mr',
  }) async {
    final String ttsLocale = _mapLangCodeToTtsLocale(langCode);
    await _tts.setLanguage(ttsLocale);

    final String script;
    if (langCode == 'mr') {
      final String gradeText = grade == SeverityGrade.severe
          ? 'गंभीर'
          : (grade == SeverityGrade.moderate ? 'मध्यम' : 'सौम्य');
      script =
          'रोगाची तीव्रता: $gradeText पातळी. पानावरील बाधित क्षेत्र अंदाजे ${lesionPercent.toStringAsFixed(1)} टक्के आहे.';
    } else if (langCode == 'hi') {
      final String gradeText = grade == SeverityGrade.severe
          ? 'गंभीर'
          : (grade == SeverityGrade.moderate ? 'मध्यम' : 'हल्की');
      script =
          'रोग की गंभीरता: $gradeText स्तर. पत्ती पर प्रभावित क्षेत्र लगभग ${lesionPercent.toStringAsFixed(1)} प्रतिशत है.';
    } else {
      script =
          'Disease severity grade: ${grade.name.toUpperCase()}. Affected foliage surface is approximately ${lesionPercent.toStringAsFixed(1)} percent.';
    }

    await _tts.speak(script);
  }

  /// Reads aloud nutrient deficiency vs pathogen infection warnings (Feature #2 & #13)
  Future<void> speakNutrientVsDiseaseWarning(
    bool isAbiotic,
    String label, {
    String langCode = 'mr',
  }) async {
    final String ttsLocale = _mapLangCodeToTtsLocale(langCode);
    await _tts.setLanguage(ttsLocale);

    final String script;
    if (isAbiotic) {
      if (langCode == 'mr') {
        script =
            'महत्त्वाची सूचना! ही बुरशीची लागण नसून अन्नद्रव्यांची कमतरता आहे. रासायनिक बुरशीनाशक फवारू नका! शिफारशीत सूक्ष्मअन्नद्रव्ये किंवा कंपोस्ट खत वापरा.';
      } else if (langCode == 'hi') {
        script =
            'महत्वपूर्ण चेतावनी! यह फंगल संक्रमण नहीं बल्कि पोषक तत्वों की कमी है. रासायनिक कीटनाशक का छिड़काव न करें! अनुशंसित सूक्ष्म पोषक तत्व या जैविक खाद डालें.';
      } else {
        script =
            'Important advisory! This is an abiotic nutritional deficiency, not a fungal infection. Avoid spraying chemical fungicides! Apply recommended micronutrients or compost.';
      }
    } else {
      if (langCode == 'mr') {
        script =
            'जैविक संसर्ग आढळला आहे. आय सी ए आर एकात्मिक कीड व्यवस्थापन पायऱ्यांचे पालन करा.';
      } else if (langCode == 'hi') {
        script =
            'जैविक संक्रमण पाया गया है. आईसीएआर एकीकृत कीट प्रबंधन चरणों का पालन करें.';
      } else {
        script =
            'Pathogenic infection detected. Please follow verified ICAR Integrated Pest Management stages.';
      }
    }

    await _tts.speak(script);
  }

  /// Reads aloud differential diagnosis comparison (Feature #13)
  Future<void> speakDifferentialDiagnosis(
    List<DiseasePrediction> predictions, {
    String langCode = 'mr',
  }) async {
    if (predictions.isEmpty) return;

    final String ttsLocale = _mapLangCodeToTtsLocale(langCode);
    await _tts.setLanguage(ttsLocale);

    final primary = predictions.first;
    final secondary = predictions.length > 1 ? predictions[1] : null;

    final StringBuffer buffer = StringBuffer();
    if (langCode == 'mr') {
      buffer.write('मुख्य निदान: ${primary.scientificName}, सत्यता: ${(primary.confidence * 100).toStringAsFixed(0)} टक्के. ');
      if (secondary != null && secondary.confidence > 0.15) {
        buffer.write('दुसरा संभाव्य पर्याय: ${secondary.scientificName}, सत्यता: ${(secondary.confidence * 100).toStringAsFixed(0)} टक्के.');
      }
    } else if (langCode == 'hi') {
      buffer.write('प्राथमिक निदान: ${primary.scientificName}, विश्वसनीयता: ${(primary.confidence * 100).toStringAsFixed(0)} प्रतिशत. ');
      if (secondary != null && secondary.confidence > 0.15) {
        buffer.write('दूसरा संभावित विकल्प: ${secondary.scientificName}, विश्वसनीयता: ${(secondary.confidence * 100).toStringAsFixed(0)} प्रतिशत.');
      }
    } else {
      buffer.write('Primary diagnosis: ${primary.scientificName} with ${(primary.confidence * 100).toStringAsFixed(0)} percent confidence. ');
      if (secondary != null && secondary.confidence > 0.15) {
        buffer.write('Differential candidate: ${secondary.scientificName} with ${(secondary.confidence * 100).toStringAsFixed(0)} percent confidence.');
      }
    }

    await _tts.speak(buffer.toString());
  }

  // ===========================================================================
  // 2. SPOKEN FARMER INTENT PARSING ENGINE (Features #13 & #15)
  // ===========================================================================

  /// Starts speech recognition listening for hands-free farmer queries
  Future<void> startListening({
    required Function(ParsedVoiceIntent) onResult,
    String localeId = 'mr_IN',
  }) async {
    if (!_isSpeechInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    await _speech.listen(
      onResult: (result) {
        final String words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          final parsed = parseFarmerIntent(words);
          onResult(parsed);
        }
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  /// Parses Marathi, Hindi, and English spoken phrases to extract operational navigation intent
  ParsedVoiceIntent parseFarmerIntent(String spokenText) {
    final lower = spokenText.toLowerCase().trim();

    // --- High-Priority Explicit Commands ---
    // TAB 0: Scanner & XAI Diagnostics
    final scanLexicon = [
      'पान स्कॅन करा', 'स्कॅन करा', 'स्कॅन', 'पान तपासा', 'फोटो काढा', 'फोटो', 'पानावर रोग', 'लक्षणे',
      'पाने पिवळी', 'पिवळेपणा', 'काळे ठिपके', 'करपा', 'सुकणे', 'रोग निदान',
      'पत्ती स्कैन करें', 'स्कैन करें', 'स्कैन', 'पत्ती दिखाओ', 'फोटो लो', 'फोटो', 'रोग पहचान', 'लक्षण',
      'पीली पत्ती', 'पीलापन', 'काले धब्बे', 'झुलसा',
      'scan leaf', 'scan', 'take photo', 'diagnose leaf', 'diagnose', 'symptoms',
      'yellow leaves', 'black spots', 'blight', 'lesion',
    ];

    // TAB 1: Outbreak Radar & Micro-Climate Telemetry
    final weatherLexicon = [
      'हवामान किंवा रोग माहिती', 'हवामान माहिती', 'रोग माहिती', 'हवामान', 'पाऊस', 'हवामान अंदाज', 'प्रादुर्भाव', 'अलर्ट', 'नकाशा', 'ढगाळ', 'दव', 'थंडी', 'आर्द्रता',
      'मौसम या रोग जानकारी', 'रोग जानकारी', 'मौसम', 'बारिश', 'मौसम का हाल', 'अलर्ट', 'प्रकोप', 'नक्शा', 'बादल', 'तापमान', 'नमी',
      'outbreak alerts', 'outbreak', 'weather', 'rain', 'forecast', 'radar', 'temperature', 'humidity', 'spore risk', 'alerts',
    ];

    // TAB 2: Longitudinal Disease Progression & Treatment Recovery
    final recoveryLexicon = [
      'प्रगती दाखवा', 'प्रगती', 'रिकव्हरी', 'जुना रोग', 'सुधारणा', 'इतिहास', 'औषध उपाय', 'उपचार', 'फवारणी', 'कीटकनाशक', 'बुरशीनाशक', 'डोस',
      'प्रगति दिखाओ', 'प्रगति', 'रिकवरी', 'सुधार', 'पुराना रोग', 'दवा असर', 'इतिहास', 'इलाज', 'दवाई', 'छिड़काव', 'कीटनाशक',
      'track recovery', 'recovery', 'progression', 'history', 'treatment tracking', 'improvement', 'medicine', 'spray', 'treatment', 'dose', 'fungicide',
    ];

    // TAB 3: Verified Expert Directory & Second Opinion
    final expertLexicon = [
      'तज्ज्ञ किंवा डॉक्टर', 'तज्ज्ञ', 'डॉक्टर', 'शास्त्रज्ञ', 'दुसरे मत', 'सल्लागार', 'केव्हीके', 'सल्ला', 'अधिकारी', 'रोगतज्ज्ञ',
      'विशेषज्ञ या डॉक्टर', 'विशेषज्ञ', 'डॉक्टर', 'वैज्ञानिक', 'दूसरी राय', 'सलाहकार', 'केवीके', 'परामर्श', 'अस्पताल',
      'find expert', 'expert directory', 'expert', 'doctor', 'scientist', 'second opinion', 'agronomist', 'pathologist', 'consult', 'review',
    ];

    // TAB 4: LeafGuard Connect NGO Network & Schemes
    final ngoLexicon = [
      'ngo मदत', 'संस्था मदत', 'संस्था', 'मदत', 'योजना', 'अनुदान', 'एनजीओ', 'मदतनीस', 'मदत करा', 'मदत केंद्र',
      'ngo मदद', 'संस्था मदद', 'संस्था', 'सहायता', 'योजना', 'एनजीओ', 'मददगार', 'अनुदान',
      'ngo connect', 'ngo assistance', 'ngo', 'scheme', 'partner', 'assistance', 'grants', 'help',
    ];

    // Evaluation in order of specificity
    // 1. Scan Leaf (Tab 0)
    final matchedScan = scanLexicon.where((kw) => lower.contains(kw)).toList();
    if (matchedScan.isNotEmpty) {
      return ParsedVoiceIntent(
        intentType: FarmerVoiceIntentType.diagnoseSymptom,
        rawTranscription: spokenText,
        detectedKeywords: matchedScan,
        suggestedAction: 'NAVIGATE_TAB_0_SCANNER',
      );
    }

    // 2. Weather / Outbreak Alerts (Tab 1)
    final matchedWeather = weatherLexicon.where((kw) => lower.contains(kw)).toList();
    if (matchedWeather.isNotEmpty) {
      return ParsedVoiceIntent(
        intentType: FarmerVoiceIntentType.checkWeather,
        rawTranscription: spokenText,
        detectedKeywords: matchedWeather,
        suggestedAction: 'NAVIGATE_TAB_1_RADAR',
      );
    }

    // 3. Track Recovery / Treatment Progression (Tab 2)
    final matchedRecovery = recoveryLexicon.where((kw) => lower.contains(kw)).toList();
    if (matchedRecovery.isNotEmpty) {
      return ParsedVoiceIntent(
        intentType: FarmerVoiceIntentType.inquireTreatment,
        rawTranscription: spokenText,
        detectedKeywords: matchedRecovery,
        suggestedAction: 'NAVIGATE_TAB_2_PROGRESSION',
      );
    }

    // 4. Expert Directory & Second Opinion (Tab 3)
    final matchedExpert = expertLexicon.where((kw) => lower.contains(kw)).toList();
    if (matchedExpert.isNotEmpty) {
      return ParsedVoiceIntent(
        intentType: FarmerVoiceIntentType.contactKvkExpert,
        rawTranscription: spokenText,
        detectedKeywords: matchedExpert,
        suggestedAction: 'NAVIGATE_TAB_3_EXPERTS',
      );
    }

    // 5. LeafGuard Connect NGO Network (Tab 4)
    final matchedNgo = ngoLexicon.where((kw) => lower.contains(kw)).toList();
    if (matchedNgo.isNotEmpty) {
      return ParsedVoiceIntent(
        intentType: FarmerVoiceIntentType.ngoConnect,
        rawTranscription: spokenText,
        detectedKeywords: matchedNgo,
        suggestedAction: 'NAVIGATE_TAB_4_NGO',
      );
    }

    return ParsedVoiceIntent(
      intentType: FarmerVoiceIntentType.unknown,
      rawTranscription: spokenText,
      detectedKeywords: const [],
      suggestedAction: 'ATTACH_TO_VOICE_NOTE',
    );
  }

  static String _mapLangCodeToTtsLocale(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'mr':
        return 'mr-IN';
      case 'hi':
        return 'hi-IN';
      case 'en':
      default:
        return 'en-IN';
    }
  }

  void dispose() {
    _speech.cancel();
    _tts.stop();
  }
}

// =============================================================================
// RIVERPOD DEPENDENCY INJECTION PROVIDERS
// =============================================================================

/// Global Riverpod Provider for the Vernacular Voice Service
final vernacularVoiceServiceProvider = Provider<VernacularVoiceService>((ref) {
  final service = VernacularVoiceService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// StateNotifierProvider for reactive voice UI integration
final vernacularVoiceStateProvider =
    StateNotifierProvider<VernacularVoiceNotifier, VernacularVoiceState>((ref) {
  final service = ref.watch(vernacularVoiceServiceProvider);
  return VernacularVoiceNotifier(service);
});

class VernacularVoiceNotifier extends StateNotifier<VernacularVoiceState> {
  final VernacularVoiceService _service;

  VernacularVoiceNotifier(this._service)
      : super(const VernacularVoiceState(
          isListening: false,
          isSpeaking: false,
          isAvailable: false,
          currentTranscription: '',
          activeLanguageCode: 'mr-IN',
        )) {
    _init();
  }

  Future<void> _init() async {
    final available = await _service.initialize();
    state = state.copyWith(isAvailable: available);
  }

  void setLanguage(String code) {
    state = state.copyWith(activeLanguageCode: code);
  }

  Future<void> listen() async {
    if (state.isListening) {
      await _service.stopListening();
      state = state.copyWith(isListening: false);
      return;
    }

    state = state.copyWith(isListening: true, currentTranscription: '');

    await _service.startListening(
      localeId: state.activeLanguageCode.replaceAll('-', '_'),
      onResult: (parsedIntent) {
        state = state.copyWith(
          currentTranscription: parsedIntent.rawTranscription,
          lastIntent: parsedIntent,
        );
      },
    );
  }

  Future<void> stop() async {
    await _service.stopListening();
    await _service.stopSpeaking();
    state = state.copyWith(isListening: false, isSpeaking: false);
  }

  Future<void> speakProtocol(IcarIpmProtocol protocol, bool isChemicalLocked) async {
    state = state.copyWith(isSpeaking: true);
    final langPrefix = state.activeLanguageCode.split('-').first;
    await _service.speakIpmAdvisory(
      protocol: protocol,
      langCode: langPrefix,
      isChemicalLocked: isChemicalLocked,
    );
    state = state.copyWith(isSpeaking: false);
  }
}
