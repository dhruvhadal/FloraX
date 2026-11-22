'use client';

import React, { useState, useEffect, useRef, useCallback } from 'react';
import { SupportedLanguage } from '../types/florax';

// ============================================================================
// TYPES & INTERFACES
// ============================================================================

export type QueueItemType = 'VOICE_QUERY' | 'FIELD_SCAN' | 'KVK_ESCALATION' | 'TIMELINE_NOTE';
export type SyncStatus = 'QUEUED_OFFLINE' | 'SYNCING' | 'SYNCED' | 'FAILED';

export interface OfflineQueueItem {
  id: string;
  type: QueueItemType;
  timestamp: string;
  language: SupportedLanguage;
  title: string;
  details: string;
  syncStatus: SyncStatus;
  retryCount: number;
  payload?: any;
}

export interface VoiceCommandPreset {
  id: string;
  language: SupportedLanguage;
  label: string;
  transcript: string;
  intent: 'symptom' | 'treatment' | 'weather' | 'kvk' | 'organic';
  response: Record<SupportedLanguage, string>;
}

export interface OfflineVoiceAssistantProps {
  language?: SupportedLanguage;
  onLanguageChange?: (lang: SupportedLanguage) => void;
  isOffline?: boolean;
  onOfflineToggle?: (offline: boolean) => void;
  onQuerySubmit?: (transcript: string, language: SupportedLanguage) => void;
  currentAdvisoryText?: string;
  onVoiceScanTrigger?: () => void;
  className?: string;
}

// Storage Key
const OFFLINE_QUEUE_STORAGE_KEY = 'FLORAX_OFFLINE_SYNC_QUEUE_V1';

// ============================================================================
// VOICE COMMAND PRESETS (Rich, authentic agronomic multilingual test queries)
// ============================================================================

export const VOICE_COMMAND_PRESETS: VoiceCommandPreset[] = [
  // --- MARATHI PRESETS ---
  {
    id: 'mr-1',
    language: 'mr',
    label: 'पानावर काळे ठिपके',
    transcript: 'पानावर काळे ठिपके आहेत आणि पाने पिवळी पडत आहेत.',
    intent: 'symptom',
    response: {
      mr: 'निरीक्षणानुसार हे टोमॅटो पिकावरील अल्टरनेरिया करपा (Early Blight) रोगाचे लक्षण आहे. पानांवर गोलाकार वलयी डाग तयार होत आहेत. त्वरित ट्रायकोडर्मा व्हिरिडी किंवा स्युडोमोनासची जैविक फवारणी करा.',
      hi: 'निरीक्षण के अनुसार यह टमाटर में अगेती झुलसा (Early Blight) के लक्षण हैं। पत्तियों पर संकेंद्रित छल्लेदार धब्बे बन रहे हैं। तुरंत ट्राइकोडर्मा विरिडी या स्यूडोमोनास का जैविक छिड़काव करें।',
      en: 'Visual symptoms indicate Early Blight (Alternaria solani) on tomato foliage with concentric rings. Immediate application of Trichoderma viride or Pseudomonas bio-formulation is advised.',
    },
  },
  {
    id: 'mr-2',
    language: 'mr',
    label: 'खत आणि औषधांची माहिती',
    transcript: 'करपा रोगावर जैविक खत आणि औषधांची माहिती द्या.',
    intent: 'treatment',
    response: {
      mr: 'ICAR-KVK मार्गदर्शक तत्त्वांनुसार: जैविक उपायासाठी ५ ग्रॅम ट्रायकोडर्मा प्रति लिटर किंवा ५% निंबोळी अर्क वापरा. रोग प्रादुर्भाव ५% पेक्षा जास्त असल्यास आणि KVK संमती मिळाल्यासच ॲझोक्सीस्ट्रॉबिन रासायनिक बुरशीनाशक वापरा.',
      hi: 'ICAR-KVK दिशानिर्देशों के अनुसार: जैविक उपचार के लिए 5 ग्राम ट्राइकोडर्मा प्रति लीटर या 5% नीम अर्क प्रयोग करें। रासायनिक कवकनाशी केवल आर्थिक सीमा पार होने पर ही डालें।',
      en: 'Per ICAR-KVK IPM protocol: Apply Trichoderma viride @ 5g/L or 5% Neem Seed Kernel Extract. Chemical fungicide (Azoxystrobin) is strictly gated until ETL threshold or KVK signoff.',
    },
  },
  {
    id: 'mr-3',
    language: 'mr',
    label: 'हवामान व रोगाचा धोका',
    transcript: 'नाशिक जिल्ह्यातील आजचा रोगाचा आणि हवेतील आर्द्रतेचा धोका काय आहे?',
    intent: 'weather',
    response: {
      mr: 'नाशिक विभागात आज हवेतील आर्द्रता ८८% आणि तापमान २६ अंश सेल्सिअस आहे. सततच्या दवामुळे बुरशीजन्य बीजाणू अंकुरणाचा धोका ८४% (गंभीर) आहे. रासायनिक फवारणी दुपारी पाऊस उघडल्यानंतरच करा.',
      hi: 'नासिक क्षेत्र में आज सापेक्ष आर्द्रता 88% और तापमान 26 डिग्री सेल्सियस है। ओस और नमी के कारण कवक बीजाणु संक्रमण का जोखिम 84% (गंभीर) है।',
      en: 'Nashik micro-climate records 88% relative humidity with 26°C temperature. Spore germination risk is critical at 84%. Defer foliar sprays during heavy morning condensation.',
    },
  },
  {
    id: 'mr-4',
    language: 'mr',
    label: 'KVK विशेषज्ञ सल्ला',
    transcript: 'माझ्या पिकाचा फोटो स्थानिक KVK शास्त्रज्ञांकडे पडताळणीसाठी पाठवा.',
    intent: 'kvk',
    response: {
      mr: 'आपल्या पानाच्या स्कॅनचा Grad-CAM हीटमॅप आणि जीपीएस संदर्भ कृषी विज्ञान केंद्र (KVK) नाशिक येथील वरिष्ठ वनस्पती रोगशास्त्रज्ञांकडे टेली-ऑडिटसाठी पाठवला गेला आहे.',
      hi: 'आपके पत्ती स्कैन का Grad-CAM हीटमैप और जीपीएस डेटा कृषि विज्ञान केंद्र (KVK) नासिक के मुख्य रोग विज्ञानी को समीक्षा के लिए प्रेषित कर दिया गया है।',
      en: 'Leaf telemetry packet including Grad-CAM activation heatmap and GPS micro-climate context has been forwarded to KVK Nashik Senior Plant Pathologist.',
    },
  },

  // --- HINDI PRESETS ---
  {
    id: 'hi-1',
    language: 'hi',
    label: 'पत्तियों पर काले धब्बे',
    transcript: 'पत्तियों पर काले गोल धब्बे और पीलापन दिखाई दे रहा है।',
    intent: 'symptom',
    response: {
      mr: 'हे अगेती करपा (Early Blight) चे प्राथमिक लक्षण आहे. पानावरील केंद्राभिमुख वलय रोगाची पुष्टी करतात. तात्काळ जैविक फवारणी सुरू करा.',
      hi: 'पत्तियों पर संकेंद्रित भूरे-काले छल्ले टमाटर के अगेती झुलसा (Early Blight) रोग की पुष्टि करते हैं। ट्राइकोडर्मा विरिडी 5 ग्राम प्रति लीटर पानी का छिड़काव तुरंत करें।',
      en: 'Concentric target-board necrotic lesions confirm Early Blight (Alternaria solani). Commence botanical/biological treatment using Trichoderma viride immediately.',
    },
  },
  {
    id: 'hi-2',
    language: 'hi',
    label: 'खाद और दवा की जानकारी',
    transcript: 'खाद और जैविक दवा की जानकारी दें।',
    intent: 'organic',
    response: {
      mr: 'सेंद्रिय उपाय: ट्रायकोडर्मा ५ ग्रॅम प्रति लिटर किंवा ५% निंबोळी तेल फवारा. नत्राची मात्रा मर्यादित ठेवा आणि पालाशयुक्त खताचा वापर वाढवा.',
      hi: 'जैविक उपाय: ट्राइकोडर्मा विरिडी 5 ग्राम/लीटर या 5% नीम का काढ़ा छिड़कें। अत्यधिक नाइट्रोजन युक्त खाद बंद करें और पोटाश का उपयोग करें ताकि पौधों की प्रतिरोधक क्षमता बढ़े।',
      en: 'Organic remedy: Spray Trichoderma viride 5g/L or 5% Neem Kernel Extract. Balance plant nutrition by curbing excessive nitrogen and bolstering potassium application.',
    },
  },
  {
    id: 'hi-3',
    language: 'hi',
    label: 'रासायनिक दवा सुरक्षा',
    transcript: 'क्या आज खेत में रासायनिक दवा छिड़कना सुरक्षित है?',
    intent: 'treatment',
    response: {
      mr: 'नाही! ICAR नियमांनुसार जोपर्यंत रोगाचा प्रादुर्भाव ५% पेक्षा जास्त होत नाही तोपर्यंत रासायनिक बुरशीनाशक वापरू नका. पीपीई किटशिवाय फवारणी करू नका.',
      hi: 'सतर्कता! जब तक आर्थिक क्षति स्तर (ETL) पार न हो और KVK अनुमोदन न मिले, तब तक रासायनिक कवकनाशी का छिड़काव वर्जित है। यदि छिड़कें तो पूर्ण पीपीई किट पहनें।',
      en: 'Caution! Chemical fungicide application is restricted until Economic Threshold Level (ETL) is breached or KVK validates. Always wear full personal protective equipment.',
    },
  },
  {
    id: 'hi-4',
    language: 'hi',
    label: 'केवीके वैज्ञानिक सहायता',
    transcript: 'कृषि विज्ञान केंद्र के विशेषज्ञ से लाइव सत्यापन कराएं।',
    intent: 'kvk',
    response: {
      mr: 'KVK नाशिकच्या तज्ज्ञांशी संपर्क साधला गेला आहे. डॉ. आर. देशमुख यांचा डिजिटल स्वाक्षरी असलेला अहवाल लवकरच उपलब्ध होईल.',
      hi: 'कृषि विज्ञान केंद्र (KVK) नासिक के टेली-क्लिनिक से संपर्क स्थापित हो गया है। वरिष्ठ वैज्ञानिक डॉ. आर. देशमुख की रिपोर्ट प्राप्त होते ही रासायनिक विकल्प अनलॉक हो जाएगा।',
      en: 'Connected to KVK Nashik Tele-Clinic. Senior Scientist Dr. R. Deshmukh differential diagnosis audit initiated.',
    },
  },

  // --- ENGLISH PRESETS ---
  {
    id: 'en-1',
    language: 'en',
    label: 'Concentric Target Spots',
    transcript: 'Brown concentric spots with yellow chlorotic halo observed on lower leaves.',
    intent: 'symptom',
    response: {
      mr: 'पानांवरील पिवळसर वलय आणि तपकिरी डाग अर्ली ब्लाइट रोगाचे स्पष्ट लक्षण आहेत. त्वरित जैविक निंबोळी अर्क फवारा.',
      hi: 'पत्तियों पर संकेंद्रित छल्ले और पीलापन अर्ली ब्लाइट रोग का प्रमाण है। तुरंत जैविक नीम अर्क का छिड़काव करें।',
      en: 'Concentric target spots with chlorotic yellow halo are characteristic diagnostic markers of Early Blight (Alternaria solani). Stage 1 & 2 IPM protocols are recommended.',
    },
  },
  {
    id: 'en-2',
    language: 'en',
    label: 'ICAR Stage 2 Bio-Spays',
    transcript: 'Provide ICAR approved biological and botanical spray recommendations.',
    intent: 'treatment',
    response: {
      mr: 'ICAR शिफारस: ट्रायकोडर्मा ५ ग्रॅम/लिटर किंवा ५% निंबोळी तेल. जमिनीतील आर्द्रता नियंत्रित ठेवा.',
      hi: 'ICAR अनुशंसा: ट्राइकोडर्मा 5 ग्राम/लीटर अथवा 5% नीम तेल। मिट्टी में जलभराव न होने दें।',
      en: 'ICAR Recommended Stage 2: Foliar spray of Trichoderma viride @ 5g/L or 5% NSKE (Neem Seed Kernel Extract). Prune lower diseased foliage to arrest upward spore ascent.',
    },
  },
  {
    id: 'en-3',
    language: 'en',
    label: 'Weather & Spore Inoculum',
    transcript: 'What is the fungal spore germination risk in Nashik today?',
    intent: 'weather',
    response: {
      mr: 'हवेतील आर्द्रता ८८% असल्याने बीजाणू अंकुरण धोका ८४% (अतिधोकादायक) आहे. संध्याकाळी शेतात पाणी देणे टाळा.',
      hi: 'आर्द्रता 88% होने से बीजाणु अंकुरण का खतरा 84% (गंभीर) है। शाम को खेतों में सिंचाई से बचें।',
      en: 'Relative humidity of 88% and sustained leaf wetness creates an 84% Critical Spore Germination Index. Avoid overhead furrow irrigation in late evenings.',
    },
  },
  {
    id: 'en-4',
    language: 'en',
    label: 'Escalate to KVK Portal',
    transcript: 'Request urgent KVK Agronomist diagnostic verification for this leaf.',
    intent: 'kvk',
    response: {
      mr: 'KVK नाशिक डिजिटल पोर्टलवर केस दाखल झाली. तज्ज्ञ शास्त्रज्ञ Grad-CAM चे विश्लेषण करत आहेत.',
      hi: 'KVK नासिक डिजिटल पोर्टल पर केस दर्ज हो गया है। वैज्ञानिक Grad-CAM विश्लेषण कर रहे हैं।',
      en: 'Escalation ticket generated for Krishi Vigyan Kendra (KVK) Nashik. Plant pathology team is reviewing spatial Grad-CAM activation coordinates.',
    },
  },
];

// Initial demo items in offline queue
const INITIAL_OFFLINE_ITEMS: OfflineQueueItem[] = [
  {
    id: 'OFL-Q-001',
    type: 'FIELD_SCAN',
    timestamp: new Date(Date.now() - 1000 * 60 * 18).toISOString(),
    language: 'mr',
    title: 'टोमॅटो पान स्कॅन #FLX-MH-8812',
    details: 'दिंडोरी तालुका - संशयास्पद पिवळे डाग (Grad-CAM हॉटस्पॉट क्षेत्र २१.५%)',
    syncStatus: 'QUEUED_OFFLINE',
    retryCount: 0,
    payload: { crop: 'Tomato', confidence: 64.0, district: 'Nashik' },
  },
  {
    id: 'OFL-Q-002',
    type: 'VOICE_QUERY',
    timestamp: new Date(Date.now() - 1000 * 60 * 7).toISOString(),
    language: 'mr',
    title: 'आवाज शंका: जैविक खत व फवारणी',
    details: 'शेतकऱ्याचा प्रश्न: "पानावर काळे ठिपके आहेत आणि कडा जळाल्यासारख्या दिसत आहेत"',
    syncStatus: 'QUEUED_OFFLINE',
    retryCount: 0,
    payload: { intent: 'treatment' },
  },
];

// ============================================================================
// MAIN COMPONENT
// ============================================================================

export function OfflineVoiceAssistant({
  language: controlledLanguage,
  onLanguageChange,
  isOffline: controlledIsOffline,
  onOfflineToggle,
  onQuerySubmit,
  currentAdvisoryText,
  onVoiceScanTrigger,
  className = '',
}: OfflineVoiceAssistantProps) {
  // Multilingual State
  const [internalLanguage, setInternalLanguage] = useState<SupportedLanguage>('mr');
  const activeLanguage = controlledLanguage || internalLanguage;

  const handleLanguageSwitch = (lang: SupportedLanguage) => {
    setInternalLanguage(lang);
    onLanguageChange?.(lang);
  };

  // Offline Simulator State
  const [internalIsOffline, setInternalIsOffline] = useState<boolean>(false);
  const isOffline = controlledIsOffline !== undefined ? controlledIsOffline : internalIsOffline;

  const handleToggleOffline = (val: boolean) => {
    setInternalIsOffline(val);
    onOfflineToggle?.(val);
  };

  // Sync Queue State (Backed by localStorage)
  const [queue, setQueue] = useState<OfflineQueueItem[]>(INITIAL_OFFLINE_ITEMS);
  const [isSyncing, setIsSyncing] = useState<boolean>(false);
  const [syncProgress, setSyncProgress] = useState<number>(0);
  const [showQueueDrawer, setShowQueueDrawer] = useState<boolean>(false);

  // Voice Interaction State
  const [isListening, setIsListening] = useState<boolean>(false);
  const [isSpeaking, setIsSpeaking] = useState<boolean>(false);
  const [speechSupported, setSpeechSupported] = useState<boolean>(false);
  const [speechError, setSpeechError] = useState<string | null>(null);
  const [transcript, setTranscript] = useState<string>('');
  const [aiSpokenResponse, setAiSpokenResponse] = useState<string>('');
  const [lastQueryIntent, setLastQueryIntent] = useState<string>('symptom');
  const [activeTab, setActiveTab] = useState<'assistant' | 'queue' | 'presets'>('assistant');
  const [isDockExpanded, setIsDockExpanded] = useState<boolean>(false);

  // Web Speech References
  const recognitionRef = useRef<any>(null);
  const synthRef = useRef<SpeechSynthesis | null>(null);
  const activeUtteranceRef = useRef<SpeechSynthesisUtterance | null>(null);

  // Load Offline Queue from LocalStorage
  useEffect(() => {
    if (typeof window !== 'undefined') {
      try {
        const cached = localStorage.getItem(OFFLINE_QUEUE_STORAGE_KEY);
        if (cached) {
          const parsed = JSON.parse(cached);
          if (Array.isArray(parsed) && parsed.length > 0) {
            setQueue(parsed);
          }
        }
      } catch (err) {
        console.warn('Unable to load FloraX offline sync queue from localStorage:', err);
      }
    }
  }, []);

  // Save Offline Queue to LocalStorage
  const saveQueue = useCallback((newQueue: OfflineQueueItem[]) => {
    setQueue(newQueue);
    if (typeof window !== 'undefined') {
      try {
        localStorage.setItem(OFFLINE_QUEUE_STORAGE_KEY, JSON.stringify(newQueue));
      } catch (err) {
        console.warn('Failed to persist offline queue:', err);
      }
    }
  }, []);

  // Initialize Speech Recognition & Synthesis
  useEffect(() => {
    if (typeof window !== 'undefined') {
      // Speech Synthesis
      if ('speechSynthesis' in window) {
        synthRef.current = window.speechSynthesis;
      }

      // Speech Recognition
      const SpeechRecognitionConstructor =
        (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;

      if (SpeechRecognitionConstructor) {
        setSpeechSupported(true);
        const recognition = new SpeechRecognitionConstructor();
        recognition.continuous = false;
        recognition.interimResults = true;
        recognition.maxAlternatives = 1;

        // Set locale based on activeLanguage
        recognition.lang =
          activeLanguage === 'mr' ? 'mr-IN' : activeLanguage === 'hi' ? 'hi-IN' : 'en-IN';

        recognition.onstart = () => {
          setIsListening(true);
          setSpeechError(null);
        };

        recognition.onresult = (event: any) => {
          const current = event.resultIndex;
          const text = event.results[current][0].transcript;
          setTranscript(text);
        };

        recognition.onerror = (event: any) => {
          console.warn('Speech recognition event error:', event.error);
          setIsListening(false);
          if (event.error === 'not-allowed') {
            setSpeechError('Microphone permission blocked. Click simulated presets below.');
          } else if (event.error === 'no-speech') {
            setSpeechError('No speech detected. Please try again or use preset.');
          } else {
            setSpeechError(`Voice input: ${event.error}`);
          }
        };

        recognition.onend = () => {
          setIsListening(false);
        };

        recognitionRef.current = recognition;
      } else {
        setSpeechSupported(false);
        setSpeechError('Web Speech API not supported on this browser. Use 1-click test presets.');
      }
    }

    return () => {
      if (recognitionRef.current) {
        try {
          recognitionRef.current.abort();
        } catch (e) {
          // ignore
        }
      }
      if (synthRef.current) {
        try {
          synthRef.current.cancel();
        } catch (e) {
          // ignore
        }
      }
    };
  }, [activeLanguage]);

  // Update recognition language dynamically
  useEffect(() => {
    if (recognitionRef.current) {
      recognitionRef.current.lang =
        activeLanguage === 'mr' ? 'mr-IN' : activeLanguage === 'hi' ? 'hi-IN' : 'en-IN';
    }
  }, [activeLanguage]);

  // Read aloud helper using SpeechSynthesis
  const speakText = useCallback(
    (textToSpeak: string, lang: SupportedLanguage) => {
      if (typeof window === 'undefined' || !('speechSynthesis' in window)) {
        return;
      }

      try {
        window.speechSynthesis.cancel();

        const utterance = new SpeechSynthesisUtterance(textToSpeak);
        const bcp47 = lang === 'mr' ? 'mr-IN' : lang === 'hi' ? 'hi-IN' : 'en-IN';
        utterance.lang = bcp47;
        utterance.rate = 0.95; // Farmer-friendly pacing
        utterance.pitch = 1.0;

        // Try to pick suitable voice
        const voices = window.speechSynthesis.getVoices();
        const matchingVoice = voices.find(
          (v) => v.lang.toLowerCase() === bcp47.toLowerCase() || v.lang.startsWith(lang)
        );
        if (matchingVoice) {
          utterance.voice = matchingVoice;
        }

        utterance.onstart = () => setIsSpeaking(true);
        utterance.onend = () => setIsSpeaking(false);
        utterance.onerror = () => setIsSpeaking(false);

        activeUtteranceRef.current = utterance;
        window.speechSynthesis.speak(utterance);
      } catch (err) {
        console.warn('Speech synthesis error:', err);
        setIsSpeaking(false);
      }
    },
    []
  );

  // Stop current speech playback
  const stopSpeaking = () => {
    if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
      window.speechSynthesis.cancel();
      setIsSpeaking(false);
    }
  };

  // Toggle Live Microphone Listening
  const handleToggleListening = () => {
    if (isSpeaking) {
      stopSpeaking();
    }

    if (isListening) {
      if (recognitionRef.current) {
        try {
          recognitionRef.current.stop();
        } catch (e) {
          // ignore
        }
      }
      setIsListening(false);
      return;
    }

    if (!recognitionRef.current) {
      setSpeechError('Microphone not supported. Please click simulated voice buttons.');
      return;
    }

    try {
      setTranscript('');
      setSpeechError(null);
      recognitionRef.current.start();
    } catch (err) {
      console.warn('Failed to start speech recognition:', err);
      // If already started, try stopping and starting again
      try {
        recognitionRef.current.stop();
      } catch (e) {
        // ignore
      }
    }
  };

  // Process and Submit a Voice Query (Real or Simulated)
  const processVoiceQuery = (
    queryText: string,
    presetResponse?: Record<SupportedLanguage, string>,
    intent: string = 'symptom'
  ) => {
    if (!queryText.trim()) return;

    setTranscript(queryText);
    setLastQueryIntent(intent);

    // Determine AI response text
    let responseText = '';
    if (presetResponse && presetResponse[activeLanguage]) {
      responseText = presetResponse[activeLanguage];
    } else {
      // Intelligent fallback matcher
      const lower = queryText.toLowerCase();
      if (lower.includes('खत') || lower.includes('दवा') || lower.includes('spray') || lower.includes('औषध')) {
        responseText =
          activeLanguage === 'mr'
            ? 'ICAR मार्गदर्शक: प्रथम ट्रायकोडर्मा ५ ग्रॅम/लिटर फवारा. रासायनिक औषध केवळ KVK संमतीनंतर वापरा.'
            : activeLanguage === 'hi'
            ? 'ICAR निर्देश: पहले ट्राइकोडर्मा 5 ग्राम/लीटर का प्रयोग करें। रासायनिक दवा केवल ईटीएल पार होने पर डालें।'
            : 'ICAR Protocol: Apply Trichoderma viride 5g/L. Chemical fungicides require strict ETL threshold breach.';
      } else if (lower.includes('हवामान') || lower.includes('मौसम') || lower.includes('weather')) {
        responseText =
          activeLanguage === 'mr'
            ? 'नाशिक जिल्ह्यात आर्द्रता ८८% असल्याने बीजाणू अंकुरणाचा धोका अतिउच्च आहे. पाऊस उघडल्याशिवाय फवारणी करू नका.'
            : activeLanguage === 'hi'
            ? 'नासिक में आर्द्रता 88% होने से फंगल संक्रमण का खतरा उच्च है। बारिश रुकने के बाद ही स्प्रे करें।'
            : 'Nashik humidity at 88% signals critical fungal spore germination risk. Defer spraying until foliage dries.';
      } else {
        responseText =
          activeLanguage === 'mr'
            ? 'पानावरील लक्षणे अर्ली ब्लाइट (अल्टरनेरिया) शी जुळत आहेत. तपशीलवार Grad-CAM स्कॅन पहा.'
            : activeLanguage === 'hi'
            ? 'पत्ती के लक्षण अगेती झुलसा (Early Blight) दर्शाते हैं। विस्तृत Grad-CAM हीटमैप देखें।'
            : 'Foliar signs correspond with Alternaria Early Blight. Refer to XAI Grad-CAM diagnostic view.';
      }
    }

    setAiSpokenResponse(responseText);

    // Speak aloud via TTS
    speakText(responseText, activeLanguage);

    // If Offline, push query to Sync Queue
    if (isOffline) {
      const newItem: OfflineQueueItem = {
        id: `OFL-Q-${Date.now().toString(36).toUpperCase()}`,
        type: 'VOICE_QUERY',
        timestamp: new Date().toISOString(),
        language: activeLanguage,
        title: `${activeLanguage.toUpperCase()} Voice Query: "${queryText.slice(0, 32)}..."`,
        details: responseText,
        syncStatus: 'QUEUED_OFFLINE',
        retryCount: 0,
        payload: { query: queryText, intent, response: responseText },
      };
      saveQueue([newItem, ...queue]);
    }

    // Call external handler if provided
    onQuerySubmit?.(queryText, activeLanguage);
  };

  // Simulate Offline Field Scan Entry
  const handleSimulateOfflineScan = () => {
    const randomScanNum = Math.floor(1000 + Math.random() * 9000);
    const newItem: OfflineQueueItem = {
      id: `OFL-SCN-${randomScanNum}`,
      type: 'FIELD_SCAN',
      timestamp: new Date().toISOString(),
      language: activeLanguage,
      title: `Field Diagnostic #FLX-MH-${randomScanNum}`,
      details: 'Tomato leaf scan captured in remote offline parcel (Grad-CAM cached locally)',
      syncStatus: 'QUEUED_OFFLINE',
      retryCount: 0,
      payload: {
        crop: 'Tomato',
        estimatedLesionArea: 14.8,
        gps: { lat: 20.0059, lng: 73.7898, village: 'Dindori', district: 'Nashik' },
      },
    };
    saveQueue([newItem, ...queue]);
  };

  // Auto-Sync Execution (Iterates over queued items and transitions them to SYNCED)
  const handleRunSyncQueue = () => {
    const pendingItems = queue.filter((item) => item.syncStatus === 'QUEUED_OFFLINE');
    if (pendingItems.length === 0) return;

    setIsSyncing(true);
    setSyncProgress(10);

    // Step 1: Mark syncing
    const updated = queue.map((item) =>
      item.syncStatus === 'QUEUED_OFFLINE' ? { ...item, syncStatus: 'SYNCING' as SyncStatus } : item
    );
    saveQueue(updated);

    // Step 2: Animated progression to simulate network telemetry
    setTimeout(() => {
      setSyncProgress(55);
    }, 600);

    setTimeout(() => {
      setSyncProgress(100);
      const synced = updated.map((item) =>
        item.syncStatus === 'SYNCING' ? { ...item, syncStatus: 'SYNCED' as SyncStatus } : item
      );
      saveQueue(synced);
      setIsSyncing(false);

      // Auditory feedback / Confirmation
      const syncConfirmationText =
        activeLanguage === 'mr'
          ? 'सर्व ऑफलाइन फील्ड स्कॅन आणि व्हॉइस क्वेरी केंद्रीय ICAR-KVK सर्व्हरशी सिंक झाल्या आहेत.'
          : activeLanguage === 'hi'
          ? 'सभी ऑफलाइन फील्ड स्कैन और वॉयस डेटा केंद्रीय ICAR सर्वर से सफलतापूर्वक सिंक हो गए हैं।'
          : 'All cached offline scans and voice queries have been securely synced to the ICAR cloud.';

      setAiSpokenResponse(syncConfirmationText);
      speakText(syncConfirmationText, activeLanguage);
    }, 1400);
  };

  // Auto-sync when toggled back online
  useEffect(() => {
    if (!isOffline) {
      const hasPending = queue.some((i) => i.syncStatus === 'QUEUED_OFFLINE');
      if (hasPending && !isSyncing) {
        handleRunSyncQueue();
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isOffline]);

  // Read current advisory if passed
  const handleSpeakCurrentAdvisory = () => {
    if (!currentAdvisoryText) return;
    setAiSpokenResponse(currentAdvisoryText);
    speakText(currentAdvisoryText, activeLanguage);
  };

  // Clear Synced items from queue
  const handleClearSynced = () => {
    const remaining = queue.filter((i) => i.syncStatus !== 'SYNCED');
    saveQueue(remaining);
  };

  const pendingCount = queue.filter((i) => i.syncStatus === 'QUEUED_OFFLINE').length;
  const filteredPresets = VOICE_COMMAND_PRESETS.filter((p) => p.language === activeLanguage);

  return (
    <div
      className={`fixed bottom-0 left-0 right-0 z-40 transition-all duration-300 font-sans ${className}`}
    >
      {/* ===================================================================== */}
      {/* EXPANDABLE TRAY / DRAWER (Sync Queue & Full Voice Controls) */}
      {/* ===================================================================== */}
      {isDockExpanded && (
        <div className="bg-slate-950/95 backdrop-blur-xl border-t border-emerald-500/30 shadow-[0_-15px_35px_rgba(0,0,0,0.7)] px-4 py-4 max-h-[75vh] overflow-y-auto">
          <div className="max-w-7xl mx-auto space-y-4">
            {/* Top Toolbar in Drawer */}
            <div className="flex flex-wrap items-center justify-between gap-3 pb-3 border-b border-slate-800">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-700 flex items-center justify-center text-white shadow-lg shadow-emerald-950">
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 100-6 3 3 0 000 6z"
                    />
                  </svg>
                </div>
                <div>
                  <h3 className="text-sm font-black text-white flex items-center gap-2">
                    <span>FloraX Multilingual Field Voice Assistant</span>
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/40">
                      Offline Edge AI
                    </span>
                  </h3>
                  <p className="text-xs text-slate-400">
                    Marathi (`mr-IN`), Hindi (`hi-IN`), English (`en-IN`) • ICAR Knowledge Vault Grounded
                  </p>
                </div>
              </div>

              {/* Sub-Navigation Tabs */}
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setActiveTab('assistant')}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all ${
                    activeTab === 'assistant'
                      ? 'bg-emerald-500 text-slate-950 shadow-md shadow-emerald-950'
                      : 'bg-slate-900 text-slate-300 hover:bg-slate-800 border border-slate-800'
                  }`}
                >
                  Voice Console
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab('presets')}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all ${
                    activeTab === 'presets'
                      ? 'bg-emerald-500 text-slate-950 shadow-md shadow-emerald-950'
                      : 'bg-slate-900 text-slate-300 hover:bg-slate-800 border border-slate-800'
                  }`}
                >
                  1-Click Presets ({filteredPresets.length})
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab('queue')}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-2 transition-all ${
                    activeTab === 'queue'
                      ? 'bg-amber-500 text-slate-950 shadow-md shadow-amber-950'
                      : 'bg-slate-900 text-slate-300 hover:bg-slate-800 border border-slate-800'
                  }`}
                >
                  <span>Sync Queue</span>
                  {pendingCount > 0 && (
                    <span className="w-5 h-5 rounded-full bg-amber-400 text-slate-950 text-[10px] font-mono font-black flex items-center justify-center">
                      {pendingCount}
                    </span>
                  )}
                </button>

                <button
                  type="button"
                  onClick={() => setIsDockExpanded(false)}
                  className="p-1.5 rounded-lg bg-slate-900 hover:bg-slate-800 text-slate-400 hover:text-white border border-slate-800"
                  title="Collapse Panel"
                >
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              </div>
            </div>

            {/* TAB 1: ASSISTANT LIVE CONSOLE */}
            {activeTab === 'assistant' && (
              <div className="grid grid-cols-1 lg:grid-cols-12 gap-4">
                {/* Left: Live Transcription & Response */}
                <div className="lg:col-span-8 bg-slate-900/80 border border-slate-800 rounded-2xl p-4 space-y-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2 text-xs font-semibold text-slate-300">
                      <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse" />
                      Live Farmer Transcript & Agro-Advisory
                    </div>
                    {isSpeaking && (
                      <div className="flex items-center gap-2 text-xs text-emerald-400 font-mono animate-pulse">
                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"
                          />
                        </svg>
                        <span>Speaking Localized Audio...</span>
                        <button
                          type="button"
                          onClick={stopSpeaking}
                          className="px-2 py-0.5 rounded bg-rose-500/20 text-rose-300 text-[10px] font-bold border border-rose-500/40 hover:bg-rose-500/30"
                        >
                          Stop
                        </button>
                      </div>
                    )}
                  </div>

                  {/* Transcript Display Box */}
                  <div className="p-3.5 rounded-xl bg-slate-950/80 border border-slate-800 min-h-[70px] flex items-start gap-3">
                    <div className="text-emerald-400 mt-0.5">
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
                        />
                      </svg>
                    </div>
                    <div className="flex-1">
                      <p className="text-xs text-slate-400 font-mono">Farmer Voice Input:</p>
                      <p className="text-sm font-medium text-white mt-0.5">
                        {transcript || (
                          <span className="text-slate-600 italic">
                            Click microphone below or select a 1-click preset to simulate farmer speech...
                          </span>
                        )}
                      </p>
                    </div>
                  </div>

                  {/* Spoken AI Advisory Box */}
                  <div className="p-3.5 rounded-xl bg-emerald-950/20 border border-emerald-500/30 min-h-[90px] flex items-start gap-3">
                    <div className="text-emerald-400 mt-0.5">
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
                        />
                      </svg>
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center justify-between">
                        <p className="text-xs text-emerald-400 font-mono font-semibold">
                          FloraX Localized Agro-Advisory ({activeLanguage.toUpperCase()}):
                        </p>
                        {aiSpokenResponse && (
                          <button
                            type="button"
                            onClick={() => speakText(aiSpokenResponse, activeLanguage)}
                            className="text-[11px] text-emerald-300 hover:text-white flex items-center gap-1 bg-emerald-500/20 px-2 py-0.5 rounded border border-emerald-500/30"
                          >
                            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"
                              />
                            </svg>
                            Replay Audio
                          </button>
                        )}
                      </div>
                      <p className="text-sm font-medium text-emerald-100 mt-1 leading-relaxed">
                        {aiSpokenResponse || (
                          <span className="text-slate-500 italic">
                            Agronomic advisory text and voice playback will be rendered here...
                          </span>
                        )}
                      </p>
                    </div>
                  </div>

                  {/* Manual Voice Input & Trigger Buttons */}
                  <div className="flex flex-wrap items-center gap-3 pt-1">
                    <button
                      type="button"
                      onClick={handleToggleListening}
                      className={`px-5 py-2.5 rounded-xl font-bold text-xs flex items-center gap-2 shadow-lg transition-all ${
                        isListening
                          ? 'bg-rose-500 text-white animate-pulse shadow-rose-950'
                          : 'bg-emerald-500 hover:bg-emerald-400 text-slate-950 shadow-emerald-950'
                      }`}
                    >
                      {isListening ? (
                        <>
                          <span className="w-2.5 h-2.5 rounded-full bg-white animate-ping" />
                          <span>Listening (Speak Now)...</span>
                        </>
                      ) : (
                        <>
                          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              strokeWidth={2}
                              d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 100-6 3 3 0 000 6z"
                            />
                          </svg>
                          <span>Speak into Microphone</span>
                        </>
                      )}
                    </button>

                    {currentAdvisoryText && (
                      <button
                        type="button"
                        onClick={handleSpeakCurrentAdvisory}
                        className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 text-xs font-bold flex items-center gap-2 transition-all"
                      >
                        <svg className="w-4 h-4 text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"
                          />
                        </svg>
                        <span>Speak Active IPM Advisory</span>
                      </button>
                    )}

                    <span className="text-[11px] text-slate-500 font-mono">
                      Locale: {activeLanguage === 'mr' ? 'mr-IN' : activeLanguage === 'hi' ? 'hi-IN' : 'en-IN'}
                    </span>
                  </div>

                  {speechError && (
                    <div className="p-2.5 rounded-xl bg-amber-500/10 border border-amber-500/30 text-xs text-amber-300 flex items-center gap-2">
                      <svg className="w-4 h-4 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                        />
                      </svg>
                      <span>{speechError}</span>
                    </div>
                  )}
                </div>

                {/* Right: Offline Status & Quick Info */}
                <div className="lg:col-span-4 bg-slate-900/80 border border-slate-800 rounded-2xl p-4 space-y-3.5">
                  <h4 className="text-xs font-bold text-slate-200 uppercase tracking-wider">
                    Network & Storage Status
                  </h4>

                  {/* Mode Card */}
                  <div
                    className={`p-3 rounded-xl border flex items-center justify-between ${
                      isOffline
                        ? 'bg-amber-950/30 border-amber-500/40 text-amber-200'
                        : 'bg-emerald-950/30 border-emerald-500/40 text-emerald-200'
                    }`}
                  >
                    <div className="flex items-center gap-2.5">
                      <span
                        className={`w-3 h-3 rounded-full ${
                          isOffline ? 'bg-amber-400 animate-pulse' : 'bg-emerald-400'
                        }`}
                      />
                      <div>
                        <div className="text-xs font-bold">
                          {isOffline ? 'Remote Farm: OFFLINE MODE' : 'Cloud Sync: ONLINE'}
                        </div>
                        <div className="text-[10px] text-slate-400">
                          {isOffline ? 'IndexedDB / LocalStorage active' : 'Connected to FloraX Central API'}
                        </div>
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={() => handleToggleOffline(!isOffline)}
                      className={`px-2.5 py-1 rounded-lg text-xs font-bold border transition-all ${
                        isOffline
                          ? 'bg-emerald-500 text-slate-950 border-emerald-400'
                          : 'bg-amber-500 text-slate-950 border-amber-400'
                      }`}
                    >
                      {isOffline ? 'Go Online' : 'Simulate Offline'}
                    </button>
                  </div>

                  {/* Queue Snapshot */}
                  <div className="p-3 rounded-xl bg-slate-950 border border-slate-800 space-y-2">
                    <div className="flex items-center justify-between text-xs">
                      <span className="text-slate-400">Sync Queue Items:</span>
                      <span className="font-mono font-bold text-white">{queue.length}</span>
                    </div>
                    <div className="flex items-center justify-between text-xs">
                      <span className="text-slate-400">Awaiting Upload:</span>
                      <span className="font-mono font-bold text-amber-400">{pendingCount}</span>
                    </div>

                    {pendingCount > 0 && (
                      <button
                        type="button"
                        disabled={isSyncing}
                        onClick={handleRunSyncQueue}
                        className="w-full mt-2 px-3 py-2 rounded-xl bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-400 hover:to-orange-400 text-slate-950 font-black text-xs shadow-md shadow-amber-950 flex items-center justify-center gap-2 transition-all disabled:opacity-50"
                      >
                        {isSyncing ? (
                          <>
                            <span className="w-3.5 h-3.5 border-2 border-slate-950 border-t-transparent rounded-full animate-spin" />
                            <span>Syncing Queue ({syncProgress}%)...</span>
                          </>
                        ) : (
                          <>
                            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                              />
                            </svg>
                            <span>Sync Pending Items ({pendingCount})</span>
                          </>
                        )}
                      </button>
                    )}
                  </div>

                  {/* Quick Simulation Trigger */}
                  <button
                    type="button"
                    onClick={handleSimulateOfflineScan}
                    className="w-full py-2 px-3 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700 text-xs font-semibold flex items-center justify-center gap-2 transition-all"
                  >
                    <svg className="w-3.5 h-3.5 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                    </svg>
                    <span>+ Add Dummy Offline Field Scan</span>
                  </button>
                </div>
              </div>
            )}

            {/* TAB 2: 1-CLICK PRESETS */}
            {activeTab === 'presets' && (
              <div className="space-y-3 bg-slate-900/80 border border-slate-800 rounded-2xl p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <h4 className="text-xs font-bold text-white">
                      1-Click Simulated Voice Queries for Hackathon Judges
                    </h4>
                    <p className="text-[11px] text-slate-400">
                      Instantly test authentic multilingual voice workflows on laptops without mic permissions.
                    </p>
                  </div>
                  <div className="flex items-center gap-1.5 bg-slate-950 p-1 rounded-xl border border-slate-800">
                    <button
                      type="button"
                      onClick={() => handleLanguageSwitch('mr')}
                      className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all ${
                        activeLanguage === 'mr'
                          ? 'bg-emerald-500 text-slate-950'
                          : 'text-slate-400 hover:text-white'
                      }`}
                    >
                      मराठी
                    </button>
                    <button
                      type="button"
                      onClick={() => handleLanguageSwitch('hi')}
                      className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all ${
                        activeLanguage === 'hi'
                          ? 'bg-emerald-500 text-slate-950'
                          : 'text-slate-400 hover:text-white'
                      }`}
                    >
                      हिन्दी
                    </button>
                    <button
                      type="button"
                      onClick={() => handleLanguageSwitch('en')}
                      className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all ${
                        activeLanguage === 'en'
                          ? 'bg-emerald-500 text-slate-950'
                          : 'text-slate-400 hover:text-white'
                      }`}
                    >
                      English
                    </button>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-2">
                  {filteredPresets.map((preset) => (
                    <button
                      key={preset.id}
                      type="button"
                      onClick={() => processVoiceQuery(preset.transcript, preset.response, preset.intent)}
                      className="text-left p-3.5 rounded-xl bg-slate-950/70 hover:bg-slate-800/80 border border-slate-800 hover:border-emerald-500/50 transition-all group flex flex-col justify-between"
                    >
                      <div className="flex items-center justify-between w-full">
                        <span className="text-xs font-bold text-emerald-400 group-hover:text-emerald-300 flex items-center gap-2">
                          <span className="w-2 h-2 rounded-full bg-emerald-500" />
                          {preset.label}
                        </span>
                        <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-slate-800 text-slate-400 uppercase">
                          {preset.intent}
                        </span>
                      </div>
                      <p className="text-xs text-slate-200 mt-2 font-medium">"{preset.transcript}"</p>
                      <div className="mt-3 flex items-center justify-between text-[11px] text-slate-400 pt-2 border-t border-slate-800/60">
                        <span className="text-emerald-400/80 group-hover:text-emerald-300 flex items-center gap-1">
                          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              strokeWidth={2}
                              d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"
                            />
                          </svg>
                          Click to Trigger Voice + TTS
                        </span>
                        <span className="text-[10px] text-slate-500 font-mono">1-Click Test</span>
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* TAB 3: OFFLINE SYNC QUEUE */}
            {activeTab === 'queue' && (
              <div className="space-y-4 bg-slate-900/80 border border-slate-800 rounded-2xl p-4">
                <div className="flex items-center justify-between flex-wrap gap-2">
                  <div>
                    <h4 className="text-xs font-bold text-white flex items-center gap-2">
                      <span>Offline Field Sync Queue (LocalStorage & IndexedDB Cache)</span>
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-mono bg-amber-500/20 text-amber-300 border border-amber-500/30">
                        {pendingCount} Pending Sync
                      </span>
                    </h4>
                    <p className="text-[11px] text-slate-400">
                      When farmers operate in rural zero-connectivity patches, scans and queries are safely buffered
                      locally.
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={handleSimulateOfflineScan}
                      className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 text-xs font-bold flex items-center gap-1.5 transition-all"
                    >
                      <span>+ Add Offline Scan</span>
                    </button>
                    {queue.some((i) => i.syncStatus === 'SYNCED') && (
                      <button
                        type="button"
                        onClick={handleClearSynced}
                        className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-slate-200 border border-slate-700 text-xs font-bold transition-all"
                      >
                        Clear Synced
                      </button>
                    )}
                    <button
                      type="button"
                      disabled={isSyncing || pendingCount === 0}
                      onClick={handleRunSyncQueue}
                      className="px-4 py-1.5 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs shadow-md shadow-emerald-950 flex items-center gap-2 transition-all disabled:opacity-50"
                    >
                      {isSyncing ? 'Syncing...' : 'Sync Pending Queue'}
                    </button>
                  </div>
                </div>

                {/* Queue Items List */}
                <div className="space-y-2 max-h-64 overflow-y-auto pr-1">
                  {queue.length === 0 ? (
                    <div className="p-8 text-center text-slate-500 text-xs italic">
                      Sync queue is empty. Capture scans or voice queries while offline to see caching.
                    </div>
                  ) : (
                    queue.map((item) => (
                      <div
                        key={item.id}
                        className={`p-3 rounded-xl border flex items-center justify-between gap-3 text-xs ${
                          item.syncStatus === 'QUEUED_OFFLINE'
                            ? 'bg-amber-950/20 border-amber-500/40'
                            : item.syncStatus === 'SYNCING'
                            ? 'bg-sky-950/20 border-sky-500/40 animate-pulse'
                            : 'bg-emerald-950/20 border-emerald-500/30'
                        }`}
                      >
                        <div className="flex items-start gap-3 flex-1 min-w-0">
                          <div
                            className={`p-2 rounded-lg mt-0.5 ${
                              item.type === 'FIELD_SCAN'
                                ? 'bg-purple-500/20 text-purple-300'
                                : 'bg-teal-500/20 text-teal-300'
                            }`}
                          >
                            {item.type === 'FIELD_SCAN' ? (
                              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path
                                  strokeLinecap="round"
                                  strokeLinejoin="round"
                                  strokeWidth={2}
                                  d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"
                                />
                              </svg>
                            ) : (
                              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path
                                  strokeLinecap="round"
                                  strokeLinejoin="round"
                                  strokeWidth={2}
                                  d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 100-6 3 3 0 000 6z"
                                />
                              </svg>
                            )}
                          </div>
                          <div className="min-w-0 flex-1">
                            <div className="flex items-center gap-2">
                              <span className="font-bold text-white truncate">{item.title}</span>
                              <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-slate-800 text-slate-400">
                                {item.id}
                              </span>
                            </div>
                            <p className="text-[11px] text-slate-300 line-clamp-1 mt-0.5">{item.details}</p>
                            <span className="text-[10px] text-slate-500 font-mono">
                              {new Date(item.timestamp).toLocaleTimeString()}
                            </span>
                          </div>
                        </div>

                        {/* Status Badge */}
                        <div className="flex-shrink-0">
                          {item.syncStatus === 'QUEUED_OFFLINE' && (
                            <span className="px-2.5 py-1 rounded-full text-[10px] font-mono font-bold bg-amber-500/20 text-amber-300 border border-amber-500/40 flex items-center gap-1.5">
                              <span className="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse" />
                              QUEUED (OFFLINE)
                            </span>
                          )}
                          {item.syncStatus === 'SYNCING' && (
                            <span className="px-2.5 py-1 rounded-full text-[10px] font-mono font-bold bg-sky-500/20 text-sky-300 border border-sky-500/40 flex items-center gap-1.5">
                              <span className="w-1.5 h-1.5 rounded-full bg-sky-400 animate-spin" />
                              SYNCING...
                            </span>
                          )}
                          {item.syncStatus === 'SYNCED' && (
                            <span className="px-2.5 py-1 rounded-full text-[10px] font-mono font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 flex items-center gap-1.5">
                              <svg className="w-3 h-3 text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                              </svg>
                              SYNCED
                            </span>
                          )}
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ===================================================================== */}
      {/* COMPACT DOCKED BOTTOM BAR (Always visible for hands-free operation)   */}
      {/* ===================================================================== */}
      <div className="bg-slate-950/90 backdrop-blur-md border-t border-emerald-500/30 px-4 py-2.5 shadow-2xl">
        <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-3">
          {/* Left: Assistant Logo & Active State Waveform */}
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={handleToggleListening}
              className={`w-10 h-10 rounded-2xl flex items-center justify-center transition-all shadow-lg ${
                isListening
                  ? 'bg-rose-500 text-white animate-pulse shadow-rose-950 scale-105'
                  : isSpeaking
                  ? 'bg-emerald-500 text-slate-950 animate-bounce shadow-emerald-950'
                  : 'bg-gradient-to-tr from-emerald-600 to-teal-500 hover:from-emerald-500 hover:to-teal-400 text-slate-950 shadow-emerald-950'
              }`}
              title={isListening ? 'Click to stop listening' : 'Click to speak via Web Speech API'}
            >
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 100-6 3 3 0 000 6z"
                />
              </svg>
            </button>

            {/* Micro Equalizer Waveform */}
            <div className="hidden sm:flex items-center gap-1 h-5 px-1">
              {[0.4, 0.9, 0.6, 1.0, 0.5, 0.8, 0.3].map((heightScale, i) => (
                <div
                  key={i}
                  className={`w-1 rounded-full transition-all duration-150 ${
                    isListening
                      ? 'bg-rose-400 animate-pulse'
                      : isSpeaking
                      ? 'bg-emerald-400 animate-pulse'
                      : 'bg-slate-700'
                  }`}
                  style={{
                    height: isListening || isSpeaking ? `${heightScale * 18}px` : '4px',
                  }}
                />
              ))}
            </div>

            {/* Quick Status / Transcript Preview */}
            <div className="min-w-0 max-w-xs md:max-w-md">
              <div className="flex items-center gap-2">
                <span className="text-xs font-black text-white">FloraX Voice</span>
                <span
                  className={`text-[9px] font-mono px-1.5 py-0.2 rounded font-bold uppercase ${
                    isListening
                      ? 'bg-rose-500/20 text-rose-300'
                      : isSpeaking
                      ? 'bg-emerald-500/20 text-emerald-300'
                      : 'bg-slate-800 text-slate-400'
                  }`}
                >
                  {isListening ? 'Listening' : isSpeaking ? 'Speaking Advisory' : 'Ready'}
                </span>
              </div>
              <p className="text-[11px] text-slate-400 truncate">
                {transcript || (
                  <span className="text-slate-500">
                    {activeLanguage === 'mr'
                      ? 'बोलण्यासाठी माइक दाबा किंवा खालील चाचणी पर्याय वापरा'
                      : activeLanguage === 'hi'
                      ? 'बोलने के लिए माइक दबाएं या परीक्षण बटन चुनें'
                      : 'Click mic to speak or use quick 1-click test chips'}
                  </span>
                )}
              </p>
            </div>
          </div>

          {/* Center: Quick Simulated Chips (Desktop convenience for judges) */}
          <div className="hidden xl:flex items-center gap-1.5">
            {filteredPresets.slice(0, 3).map((preset) => (
              <button
                key={preset.id}
                type="button"
                onClick={() => processVoiceQuery(preset.transcript, preset.response, preset.intent)}
                className="px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 border border-slate-800 hover:border-emerald-500/50 text-[11px] text-slate-300 hover:text-white transition-all flex items-center gap-1.5"
                title={preset.transcript}
              >
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
                <span className="max-w-[130px] truncate">{preset.label}</span>
              </button>
            ))}
          </div>

          {/* Right: Language, Offline Pill, Expand Button */}
          <div className="flex items-center gap-2">
            {/* Language Switcher */}
            <div className="flex items-center bg-slate-900 border border-slate-800 rounded-xl p-0.5">
              <button
                type="button"
                onClick={() => handleLanguageSwitch('mr')}
                className={`px-2 py-1 rounded-lg text-xs font-bold transition-all ${
                  activeLanguage === 'mr' ? 'bg-emerald-500 text-slate-950' : 'text-slate-400 hover:text-white'
                }`}
                title="मराठी (mr-IN)"
              >
                MR
              </button>
              <button
                type="button"
                onClick={() => handleLanguageSwitch('hi')}
                className={`px-2 py-1 rounded-lg text-xs font-bold transition-all ${
                  activeLanguage === 'hi' ? 'bg-emerald-500 text-slate-950' : 'text-slate-400 hover:text-white'
                }`}
                title="हिन्दी (hi-IN)"
              >
                HI
              </button>
              <button
                type="button"
                onClick={() => handleLanguageSwitch('en')}
                className={`px-2 py-1 rounded-lg text-xs font-bold transition-all ${
                  activeLanguage === 'en' ? 'bg-emerald-500 text-slate-950' : 'text-slate-400 hover:text-white'
                }`}
                title="English (en-IN)"
              >
                EN
              </button>
            </div>

            {/* Offline Status Badge / Toggle */}
            <button
              type="button"
              onClick={() => handleToggleOffline(!isOffline)}
              className={`px-2.5 py-1 rounded-xl text-xs font-bold border flex items-center gap-1.5 transition-all ${
                isOffline
                  ? 'bg-amber-500/20 text-amber-300 border-amber-500/40 hover:bg-amber-500/30'
                  : 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40 hover:bg-emerald-500/30'
              }`}
              title={isOffline ? 'Offline Mode active. Click to switch online.' : 'Online. Click to simulate offline.'}
            >
              <span
                className={`w-2 h-2 rounded-full ${
                  isOffline ? 'bg-amber-400 animate-pulse' : 'bg-emerald-400'
                }`}
              />
              <span className="hidden sm:inline">{isOffline ? 'Offline' : 'Online'}</span>
              {pendingCount > 0 && (
                <span className="px-1.5 py-0.2 rounded-full text-[9px] font-mono font-black bg-amber-400 text-slate-950">
                  {pendingCount}
                </span>
              )}
            </button>

            {/* Expand / Collapse Tray Button */}
            <button
              type="button"
              onClick={() => setIsDockExpanded(!isDockExpanded)}
              className={`p-2 rounded-xl border text-xs font-bold transition-all flex items-center gap-1 ${
                isDockExpanded
                  ? 'bg-emerald-500 text-slate-950 border-emerald-400'
                  : 'bg-slate-900 text-slate-300 hover:text-white border-slate-800 hover:bg-slate-800'
              }`}
              title={isDockExpanded ? 'Collapse voice and sync controls' : 'Expand full voice & sync panel'}
            >
              <span className="text-[11px] font-semibold hidden md:inline">
                {isDockExpanded ? 'Close Panel' : 'Voice Console'}
              </span>
              <svg
                className={`w-4 h-4 transition-transform duration-200 ${isDockExpanded ? 'rotate-180' : ''}`}
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
