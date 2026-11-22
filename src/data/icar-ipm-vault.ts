/**
 * ============================================================================
 * FloraX - ICAR / KVK Integrated Pest Management (IPM) Knowledge Vault
 * ============================================================================
 * 
 * Verified regional agricultural repository conforming strictly to guidelines
 * published by the Indian Council of Agricultural Research (ICAR), Directorate
 * of Plant Protection, Quarantine & Storage (DPPQS), and Maharashtra State
 * Krishi Vigyan Kendras (KVK - MPKV Rahuri, Dr. BSKKV Dapoli, VNMKV Parbhani,
 * ICAR-CICR Nagpur, and ICAR-IISS).
 * 
 * Includes:
 * 1. Diagnostic Scenarios (High-confidence AI, Low-confidence KVK escalation)
 * 2. 3-Stage Multi-lingual IPM Advisories (Cultural, Biological, Chemical)
 * 3. Maharashtra District Epidemic Clusters (Nashik, Pune, Raigad, Satara, Nagpur)
 * 4. Multi-temporal Crop Health Progression Timelines
 */

import {
  DiagnosticResult,
  WeatherRiskPrediction,
  ProgressionRecord,
  VillageOutbreakCluster,
} from '../types/florax';

// ============================================================================
// SECTION 1: VERIFIED DIAGNOSTIC SCENARIOS & IPM ADVISORIES
// ============================================================================

/**
 * SCENARIO 1A: Tomato Early Blight (Alternaria solani) - High Confidence (>85%)
 * High-confidence computer vision detection on mature field foliage in Nashik district.
 */
export const TOMATO_EARLY_BLIGHT_HIGH_CONFIDENCE: DiagnosticResult = {
  scanId: 'FLX-SCAN-2026-TOM-081',
  timestamp: '2026-11-14T08:30:00.000Z',
  cropName: 'Tomato (Solanum lycopersicum)',
  topCandidates: [
    {
      id: 'DIS-TOM-ALT-SOLANI',
      name: {
        en: 'Tomato Early Blight',
        hi: 'टमाटर का अगेती झुलसा रोग',
        mr: 'टोमॅटोवरील लवकर येणारा करपा (अल्टरनेरिया)',
      },
      scientificName: 'Alternaria solani',
      confidence: 92.4,
      category: 'FUNGAL',
    },
    {
      id: 'DIS-TOM-SEPTORIA',
      name: {
        en: 'Septoria Leaf Spot',
        hi: 'सेप्टोरिया पर्ण धब्बा रोग',
        mr: 'सेप्टोरिया पानावरील ठिपके',
      },
      scientificName: 'Septoria lycopersici',
      confidence: 5.1,
      category: 'FUNGAL',
    },
    {
      id: 'DIS-TOM-BACT-SPECK',
      name: {
        en: 'Bacterial Speck',
        hi: 'जीवाणुज चित्ती रोग',
        mr: 'जिवाणूजन्य ठिपके रोग',
      },
      scientificName: 'Pseudomonas syringae pv. tomato',
      confidence: 2.5,
      category: 'BACTERIAL',
    },
  ],
  lesionAreaPercentage: 14.8,
  gradCamRegions: [
    {
      x: 34.5,
      y: 42.1,
      radius: 12.5,
      intensity: 0.94,
      label: 'Concentric target-board rings on lower leaflets',
    },
    {
      x: 62.8,
      y: 58.3,
      radius: 9.8,
      intensity: 0.88,
      label: 'Chlorotic yellow halo around expanding necrotic lesion',
    },
    {
      x: 48.2,
      y: 71.0,
      radius: 11.2,
      intensity: 0.82,
      label: 'Marginal leaf necrosis and petiole collar blighting',
    },
  ],
  requiresExpertVerification: false,
  verificationStatus: 'AI_VERIFIED',
  ipmAdvisory: {
    culturalMechanical: {
      en: [
        'Prune and destroy lower senescent and infected foliage displaying concentric lesions; carry pruned leaves out in bags and burn or bury in deep pits.',
        'Convert from overhead sprinkler to drip irrigation to keep leaf wetness below 2 consecutive hours.',
        'Adopt 2 to 3-year crop rotation with non-solanaceous crops such as maize, pearl millet, or marigold.',
        'Apply 5-7 cm organic paddy straw or silver-black polyethylene mulch (30 micron) to suppress soil splash dispersal of Alternaria conidia.',
        'Maintain plant spacing of 60 cm x 45 cm on raised beds to promote rapid canopy aeration.',
      ],
      hi: [
        'निचली और संकेंद्री छल्लों (टारगेट बोर्ड) से ग्रसित पत्तियों को काटकर खेत से बाहर निकालें और गड्ढे में दबाएं या जला दें।',
        'पत्तियों को गीला होने से बचाने के लिए फव्वारा सिंचाई बंद करें और केवल ड्रिप सिंचाई का प्रयोग करें।',
        'सोलानेसी कुल (आलू, बैंगन, मिर्च) को छोड़कर मक्का, बाजरा या गेंदा के साथ 2-3 साल का फसल चक्र अपनाएं।',
        'मिट्टी से बीजाणुओं के फैलाव को रोकने के लिए 30 माइक्रोन की मल्चिंग फिल्म या धान के पुआल की 5-7 सेमी मोटी परत बिछाएं।',
        'हवा के बेहतर संचार के लिए मेड़ों पर 60 सेमी x 45 सेमी की दूरी बनाए रखें।',
      ],
      mr: [
        'तळातील गोलाकार कडी (टारगेट बोर्ड) असलेली रोगट पाने तोडून गोणपाटात भरून शेताबाहेर खड्ड्यात गाडून किंवा जाळून नष्ट करा.',
        'पानांवर सतत ओलावा राहू नये म्हणून तुषार सिंचन पूर्णपणे थांबवून ठिबक सिंचनाचा वापर करा.',
        'सोलानेसी कुळाबाहेरील पिकांसोबत (उदा. मका, बाजरी, झेंडू) २ ते ३ वर्षे फेरपालट करा.',
        'जमिनीतून बुरशीचे बीजाणू उडून पानांवर येऊ नयेत म्हणून ३० मायक्रॉनची गादीवाफ्यावर प्लास्टिक मल्चिंग किंवा भाताच्या पेंढ्याचे आच्छादन करा.',
        'झाडांमध्ये ६० x ४५ सेमी अंतर ठेवून हवा खेळती राहील याची काळजी घ्या.',
      ],
    },
    biologicalBotanical: {
      en: [
        'Foliar spray of Trichoderma harzianum (2% WP @ 5-10 g/L) or Trichoderma viride @ 5 g/L during late afternoon hours.',
        'Spray bio-control agent Pseudomonas fluorescens (1% WP @ 5 g/L or 2.5 kg/ha in 500 L water) every 10-12 days.',
        'Preventative foliar spray of cold-pressed Neem Oil (Azadirachtin 10,000 ppm @ 2-3 mL/L) with agricultural non-ionic surfactant (0.5 mL/L).',
        'Apply enriched Farm Yard Manure (FYM 5 tonnes/ha mixed with 2.5 kg Trichoderma harzianum) to root rhizosphere zone.',
      ],
      hi: [
        'शाम के समय ट्राइकोडर्मा हार्ज़ियानम (2% WP @ 5-10 ग्राम/लीटर) या ट्राइकोडर्मा विरिडी @ 5 ग्राम/लीटर का पर्णीय छिड़काव करें।',
        'स्यूडोमोनास फ्लोरोसेंस (1% WP @ 5 ग्राम/लीटर या 2.5 किग्रा/हेक्टेयर) का 10-12 दिनों के अंतराल पर छिड़काव करें।',
        'निवारक उपाय के रूप में कड़ाही-निर्मित नीम तेल (एज़ाडिराक्टिन 10,000 ppm @ 2-3 मिली/लीटर) स्टिकर के साथ मिलाकर छिड़कें।',
        'जड़ों के आसपास ट्राइकोडर्मा से संवर्धित 5 टन गोबर की खाद (FYM) प्रति हेक्टेयर डालें।',
      ],
      mr: [
        'संध्याकाळच्या वेळी ट्रायकोडर्मा हार्झियानम (२% डब्ल्यूपी @ ५-१० ग्रॅम/लिटर) किंवा ट्रायकोडर्मा व्हिरिडी @ ५ ग्रॅम/लिटरची फवारणी करा.',
        'स्यूडोमोनास फ्लोरोसन्स (१% डब्ल्यूपी @ ५ ग्रॅम/लिटर) दर १० ते १२ दिवसांच्या अंतराने प्रतिबंधात्मक फवारा.',
        'प्रतिबंधात्मक उपाय म्हणून चांगल्या दर्जाचे निंबोळी तेल (अझाडिराक्टिन १०,००० पीपीएम @ २-३ मिली/लिटर) चिकट द्रव्यासोबत फवारा.',
        'प्रति हेक्टरी ५ टन चांगल्या कुजलेल्या शेणखतात २.५ किलो ट्रायकोडर्मा मिसळून मुळांच्या कार्यकक्षेत टाका.',
      ],
    },
    chemicalControl: {
      lockedByThreshold: false,
      productName: 'Mancozeb 75% WP or Azoxystrobin 18.2% + Difenoconazole 11.4% SC',
      dosagePerLitre: 'Mancozeb @ 2.5 g/L (protectant) OR Azoxystrobin + Difenoconazole @ 1.0 mL/L (curative)',
      waitingPeriodDays: 7,
      ppeWarnings: {
        en: [
          'Wear chemical-resistant nitrile gloves, tight-fitting eye goggles, and N95 particulate respirator mask.',
          'Never spray against prevailing wind direction; ensure application takes place between 06:30-09:30 AM or 04:30-06:30 PM.',
          'Triple-rinse empty pesticide containers, puncture bottom, and dispose in certified hazardous waste pits; never reuse.',
          'Strict 24-hour restricted field re-entry interval (REI) for field laborers and livestock.',
        ],
        hi: [
          'रासायनिक प्रतिरोधी नाइट्राइल दस्ताने, सुरक्षा चश्मा और N95 सुरक्षात्मक मास्क अवश्य पहनें।',
          'हवा की दिशा के विपरीत कभी छिड़काव न करें; सुबह 6:30-9:30 बजे या शाम 4:30-6:30 बजे के बीच ही छिड़काव करें।',
          'खाली कीटनाशक डिब्बों को तीन बार धोकर, पेंदी में छेद कर सुरक्षित रूप से नष्ट करें; घरेलू उपयोग में न लाएं।',
          'छिड़काव के बाद 24 घंटे तक खेत में मजदूरों और मवेशियों का प्रवेश पूर्णतः वर्जित रखें।',
        ],
        mr: [
          'रासायनिक प्रतिरोधक नायट्रिल हातमोजे, सुरक्षा गॉगल आणि N95 रेस्पिरेटर मास्क अनिवार्यपणे वापरा.',
          'वाऱ्याच्या विरुद्ध दिशेने कधीही फवारणी करू नका; सकाळी ६:३० ते ९:३० किंवा संध्याकाळी ४:३० ते ६:३० या शांत वेळेतच फवारा.',
          'कीटकनाशकांचे रिकामे डबे तीन वेळा धुवून, तळाला छिद्र पाडून सुरक्षित विल्हेवाट लावा; घरगुती वापरासाठी वापरू नका.',
          'फवारणीनंतर २४ तास शेतात मजूर आणि जनावरांचा प्रवेश पूर्णतः बंद ठेवा.',
        ],
      },
      etlCriteria: {
        en: 'Economic Threshold Level (ETL): >5% foliage affected with expanding target lesions on lower/mid canopy when ambient relative humidity exceeds 80% and temperatures hover between 24-29°C.',
        hi: 'आर्थिक दहलीज स्तर (ETL): निचले व मध्य छतरी के 5% से अधिक पत्तों पर संकेंद्री धब्बे दिखना, जब सापेक्ष आर्द्रता 80% से अधिक और तापमान 24-29°C के बीच हो।',
        mr: 'आर्थिक नुकसान पातळी (ETL): हवेतील सापेक्ष आर्द्रता ८०% पेक्षा जास्त आणि तापमान २४-२९° से असताना झाडाच्या खालच्या व मधल्या भागातील ५% पेक्षा जास्त पानांवर करपा डाग दिसणे.',
      },
    },
  },
};

/**
 * SCENARIO 1B: Tomato Early Blight - Low Confidence (64%) for KVK Escalation Testing
 * Ambiguous chlorotic lesion presentation confounded with Septoria and bacterial speck.
 * Triggers mandatory KVK agronomist escalation and locks chemical recommendations.
 */
export const TOMATO_EARLY_BLIGHT_LOW_CONFIDENCE: DiagnosticResult = {
  scanId: 'FLX-SCAN-2026-TOM-082-ESC',
  timestamp: '2026-11-14T09:15:00.000Z',
  cropName: 'Tomato (Solanum lycopersicum)',
  topCandidates: [
    {
      id: 'DIS-TOM-ALT-SOLANI',
      name: {
        en: 'Tomato Early Blight (Atypical presentation)',
        hi: 'टमाटर का अगेती झुलसा (अस्पष्ट लक्षण)',
        mr: 'टोमॅटो करपा (अस्पष्ट करपा लक्षणे)',
      },
      scientificName: 'Alternaria solani',
      confidence: 64.0,
      category: 'FUNGAL',
    },
    {
      id: 'DIS-TOM-SEPTORIA',
      name: {
        en: 'Septoria Leaf Spot',
        hi: 'सेप्टोरिया पर्ण धब्बा',
        mr: 'सेप्टोरिया ठिपके रोग',
      },
      scientificName: 'Septoria lycopersici',
      confidence: 22.8,
      category: 'FUNGAL',
    },
    {
      id: 'DIS-TOM-BACT-CANKER',
      name: {
        en: 'Bacterial Canker / Spot',
        hi: 'जीवाणुज कैंकर व धब्बा',
        mr: 'जिवाणूजन्य कॅन्कर किंवा ठिपके',
      },
      scientificName: 'Clavibacter michiganensis / Xanthomonas perforans',
      confidence: 13.2,
      category: 'BACTERIAL',
    },
  ],
  lesionAreaPercentage: 6.4,
  gradCamRegions: [
    {
      x: 45.0,
      y: 50.0,
      radius: 16.0,
      intensity: 0.65,
      label: 'Diffuse chlorosis lacking distinct concentric ring boundaries',
    },
    {
      x: 70.2,
      y: 35.8,
      radius: 8.5,
      intensity: 0.58,
      label: 'Small punctate specks resembling bacterial or Septoria spots',
    },
  ],
  requiresExpertVerification: true,
  verificationStatus: 'PENDING_KVK_REVIEW',
  ipmAdvisory: {
    culturalMechanical: {
      en: [
        'Isolate symptomatic plants; do not enter healthy blocks after touching suspect foliage to prevent mechanical bacterial transmission.',
        'Collect 3 fresh leaf samples in sterile ziplock bags and submit to the nearest Taluka KVK diagnostic laboratory for stereomicroscope spore examination.',
        'Suspend all overhead washing or sprinkler irrigation immediately.',
      ],
      hi: [
        'लक्षणयुक्त पौधों को अलग रखें; जीवाणु संक्रमण फैलने से रोकने के लिए संदिग्ध पत्तियों को छूने के बाद स्वस्थ पौधों को न छुएं।',
        '3 ताजी रोगग्रस्त पत्तियों को स्वच्छ पॉलीथिन बैग में एकत्र कर नजदीकी तालुका कृषि विज्ञान केंद्र (KVK) प्रयोगशाला में सूक्ष्मदर्शी जांच हेतु भेजें।',
        'फव्वारा या स्प्रिंकलर से पानी देना तुरंत बंद कर दें।',
      ],
      mr: [
        'लक्षणे दिसणारी झाडे तात्पुरती वेगळी ओळखा; संशयित पानांना स्पर्श केल्यानंतर निरोगी झाडांना स्पर्श करू नका जेणेकरून जिवाणूंचा प्रसार टळेल.',
        '३ ताजी बाधित पाने स्वच्छ झिपलॉक पिशवीत भरून तात्काळ जवळच्या तालुका कृषी विज्ञान केंद्र (KVK) प्रयोगशाळेत सूक्ष्मदर्शक तपासणीसाठी सादर करा.',
        'तुषार सिंचन किंवा पाण्याचा फवारा मारणे ताबडतोब थांबवा.',
      ],
    },
    biologicalBotanical: {
      en: [
        'Broad-spectrum bio-protectant foliar spray: Bacillus subtilis (1% WP @ 5 g/L) combined with Trichoderma harzianum (2% WP @ 5 g/L).',
        'Neem Seed Kernel Extract (5% NSKE @ 50 g/L) as a benign botanical prophylactic while awaiting laboratory culture results.',
      ],
      hi: [
        'व्यापक जैव-सुरक्षात्मक छिड़काव: बैसिलस सबटिलिस (1% WP @ 5 ग्राम/लीटर) और ट्राइकोडर्मा हार्ज़ियानम (2% WP @ 5 ग्राम/लीटर) का प्रयोग करें।',
        'प्रयोगशाला परिणाम आने तक 5% नीम बीज अर्क (NSKE @ 50 ग्राम/लीटर) का सौम्य सुरक्षात्मक छिड़काव करें।',
      ],
      mr: [
        'सर्वसमावेशक जैविक बुरशीनाशक फवारणी: बॅसिलस सबटिलिस (१% डब्ल्यूपी @ ५ ग्रॅम/लिटर) सोबत ट्रायकोडर्मा हार्झियानम (२% डब्ल्यूपी @ ५ ग्रॅम/लिटर) फवारा.',
        'प्रयोगशाळेचा अहवाल येईपर्यंत ५% निंबोळी अर्क (NSKE @ ५० ग्रॅम/लिटर) चा सौम्य प्रतिबंधक फवारा द्या.',
      ],
    },
    chemicalControl: {
      lockedByThreshold: true,
      productName: 'CHEMICAL LOCK ACTIVE: Awaiting KVK Agronomist Diagnosis',
      dosagePerLitre: 'LOCKED - Indiscriminate fungicide spray contraindicated without microscopic pathogen confirmation',
      waitingPeriodDays: 0,
      ppeWarnings: {
        en: [
          'CHEMICAL INTERLOCK: Synthetic chemical fungicides are strictly locked to prevent pathogen resistance and financial loss.',
          'Wait for digital verification and prescription from the assigned KVK plant pathologist.',
        ],
        hi: [
          'रासायनिक इंटरलॉक: रोगजनक प्रतिरोध और आर्थिक नुकसान रोकने के लिए रासायनिक कीटनाशक अनुशंसा अवरुद्ध है।',
          'केवीके पादप रोग विशेषज्ञ के डिजिटल सत्यापन और परामर्श की प्रतीक्षा करें।',
        ],
        mr: [
          'रासायनिक लॉक सक्रिय: बुरशीमध्ये प्रतिकारक्षमता निर्माण होऊ नये आणि आर्थिक भुर्दंड टाळण्यासाठी रासायनिक फवारणी लॉक केली आहे.',
          'नियुक्त केव्हीके पीक संरक्षण तज्ज्ञांच्या डिजिटल पडताळणी व सल्ल्याची प्रतीक्षा करा.',
        ],
      },
      etlCriteria: {
        en: 'ETL Hold: Confidence 64.0% falls below the 75% autonomy safety threshold. Requires human-in-the-loop expert sign-off.',
        hi: 'ईटीएल रोक: 64.0% विश्वसनीयता 75% की सुरक्षा सीमा से कम है। मानव विशेषज्ञ के अनुमोदन की आवश्यकता है।',
        mr: 'ईटीएल लॉक: ६४.०% अचूकता ही ७५% च्या स्वयंचलित सुरक्षितता मर्यादेपेक्षा कमी आहे. केव्हीके तज्ज्ञ मान्यतेची गरज आहे.',
      },
    },
  },
};

/**
 * SCENARIO 2: Paddy Blast (Magnaporthe oryzae / Pyricularia oryzae)
 * Critical threat across coastal Konkan paddy belt (Raigad, Ratnagiri) during humid monsoons.
 */
export const PADDY_BLAST_DIAGNOSTIC: DiagnosticResult = {
  scanId: 'FLX-SCAN-2026-RIC-104',
  timestamp: '2026-11-14T07:45:00.000Z',
  cropName: 'Paddy / Rice (Oryza sativa)',
  topCandidates: [
    {
      id: 'DIS-RIC-MAGN-ORYZAE',
      name: {
        en: 'Rice Blast (Leaf & Neck Blast)',
        hi: 'धान का झोंका / ब्लास्ट रोग',
        mr: 'भातावरील करपा / मानमोड्या रोग',
      },
      scientificName: 'Magnaporthe oryzae (Pyricularia oryzae)',
      confidence: 89.5,
      category: 'FUNGAL',
    },
    {
      id: 'DIS-RIC-BROWN-SPOT',
      name: {
        en: 'Rice Brown Spot',
        hi: 'धान का भूरा धब्बा रोग',
        mr: 'भातावरील तपकिरी ठिपके',
      },
      scientificName: 'Bipolaris oryzae',
      confidence: 6.8,
      category: 'FUNGAL',
    },
    {
      id: 'DIS-RIC-SHEATH-BLIGHT',
      name: {
        en: 'Rice Sheath Blight',
        hi: 'धान का शीथ ब्लाइट (पर्णच्छद झुलसा)',
        mr: 'भातावरील पर्णकोष करपा',
      },
      scientificName: 'Rhizoctonia solani',
      confidence: 3.7,
      category: 'FUNGAL',
    },
  ],
  lesionAreaPercentage: 11.2,
  gradCamRegions: [
    {
      x: 52.3,
      y: 38.6,
      radius: 14.0,
      intensity: 0.96,
      label: 'Spindle-shaped elliptical lesion with grey center and reddish-brown margin',
    },
    {
      x: 39.1,
      y: 64.2,
      radius: 10.5,
      intensity: 0.89,
      label: 'Collar rot and leaf junction blast necrosis',
    },
    {
      x: 74.5,
      y: 49.0,
      radius: 8.2,
      intensity: 0.81,
      label: 'Secondary coalescing blast lesions on upper flag leaf',
    },
  ],
  requiresExpertVerification: false,
  verificationStatus: 'AI_VERIFIED',
  ipmAdvisory: {
    culturalMechanical: {
      en: [
        'Avoid excessive top-dressing with nitrogenous fertilizers; split urea into 3 balanced split applications (50% basal, 25% active tillering, 25% panicle initiation).',
        'Drain standing field water temporarily for 24-48 hours to aerate soil and reduce micro-canopy relative humidity.',
        'Eradicate collateral weed hosts along field bunds, specifically Echinochloa crus-galli and Panicum repens.',
        'Burn or compost stubbles deeply post-harvest to destroy overwintering perithecia and conidia.',
        'Adopt blast-resistant regional cultivars (e.g., Karjat-3, Karjat-7, Phule Radha, Ratnagiri-4) recommended by Dr. BSKKV Dapoli.',
      ],
      hi: [
        'यूरिया का अत्यधिक छिड़काव न करें; नाइट्रोजन को 3 बराबर भागों में बांटकर दें (50% रोपाई के समय, 25% कल्ले फूटते समय, 25% बाली निकलने पर)।',
        'खेत में भरे पानी को 24-48 घंटों के लिए निकाल दें ताकि मिट्टी में हवा जा सके और नमी कम हो सके।',
        'मेड़ों पर उगे खरपतवार जैसे सावा घास (इचिनोक्लोआ) को नष्ट करें जो कवक के वैकल्पिक मेजबान हैं।',
        'फसल कटाई के बाद ठूंठों को गहरी जुताई कर नष्ट करें ताकि बीजाणु नष्ट हो जाएं।',
        'क्षेत्रीय रोगरोधी प्रजातियां (जैसे कर्जत-3, कर्जत-7, फुले राधा, रत्नागिरी-4) ही लगाएं।',
      ],
      mr: [
        'नत्रयुक्त खतांचा (युरिया) अतिरेक टाळा; शिफारशीत नत्र तीन हप्त्यांत विभागून द्या (५०% लावणीच्या वेळी, २५% फुटवे फुटताना, २५% पोटरीच्या वेळी).',
        'शेतातील साचलेले पाणी २४ ते ४८ तासांसाठी काढून देऊन शेतात हवा खेळती करा व सूक्ष्म-हवामानातील आर्द्रता कमी करा.',
        'बांधावरील सावा व इतर गवत/तण काढून नष्ट करा, जे करपा बुरशीचे आश्रयदाते असतात.',
        'पीक कापणीनंतर उरलेली धसकटे खोल नांगरट करून जमिनीत गाडून टाका.',
        'डॉ. बाळासाहेब सावंत कोकण कृषी विद्यापीठाने शिफारस केलेल्या करपा-प्रतिरोधक जातींची (उदा. कर्जत-३, कर्जत-७, फुले राधा, रत्नागिरी-४) लागवड करा.',
      ],
    },
    biologicalBotanical: {
      en: [
        'Seed treatment prior to sowing with talc-based Pseudomonas fluorescens (10 g/kg seed) followed by 30-minute nursery seedling root dip (2.5 kg in 50 L water).',
        'Foliar spray of Pseudomonas fluorescens (2.5 kg/ha or 5 g/L) at maximum tillering and boot leaf emergence.',
        'Spray bio-fungicide Trichoderma asperellum (5 g/L) or 10% crude extract of wild garlic / Lantana camara leaf extract.',
      ],
      hi: [
        'बुवाई से पहले स्यूडोमोनास फ्लोरोसेंस (10 ग्राम/किग्रा बीज) से बीज उपचार करें और रोपाई से पूर्व 30 मिनट तक पौधों की जड़ों को घोल में डुबोएं।',
        'कल्ले फूटने की अंतिम अवस्था और झंडा पत्ती निकलने पर स्यूडोमोनास फ्लोरोसेंस (5 ग्राम/लीटर) का पर्णीय छिड़काव करें।',
        'ट्राइकोडर्मा एस्परेलम (5 ग्राम/लीटर) या 10% बेशरम/लंटाना पत्ती के अर्क का छिड़काव करें।',
      ],
      mr: [
        'पेरणीपूर्वी स्यूडोमोनास फ्लोरोसन्स (१० ग्रॅम/किलो बियाणे) चोळून बीजप्रक्रिया करा आणि पुनर्लागवडीपूर्वी रोपांची मुळे द्रावणात ३० मिनिटे बुडवून ठेवा.',
        'फुटवे निघण्याच्या काळात व पोटरीच्या वेळी स्यूडोमोनास फ्लोरोसन्स (५ ग्रॅम/लिटर किंवा २.५ किलो/हे.) फवारा.',
        'ट्रायकोडर्मा एस्पेरेलियम (५ ग्रॅम/लिटर) किंवा १०% घाणेरी (लँटाना) पाल्याच्या अर्काची फवारणी करा.',
      ],
    },
    chemicalControl: {
      lockedByThreshold: false,
      productName: 'Tricyclazole 75% WP or Isoprothiolane 40% EC',
      dosagePerLitre: 'Tricyclazole 75% WP @ 0.6 g/L (0.6 kg/ha in 1000 L water) OR Isoprothiolane 40% EC @ 1.5 mL/L',
      waitingPeriodDays: 21,
      ppeWarnings: {
        en: [
          'Wear waterproof full-body protective suit, chemical safety goggles, heavy neoprene gloves, and high-ankle gumboots.',
          'Wash all spraying equipment and nozzles in designated sump pits far away from drinking water wells, rivers, and fish ponds.',
          'Tricyclazole is highly toxic to aquatic life; prevent all spray drift into adjacent water reservoirs and aquaculture ponds.',
          'Strict 48-hour re-entry interval post spray.',
        ],
        hi: [
          'जल-अभेद्य सुरक्षात्मक सूट, सुरक्षा चश्मा, नियोप्रीन दस्ताने और गमबूट पहनें।',
          'छिड़काव यंत्रों को पीने के कुओं, तालाबों और नदियों से दूर सुरक्षित स्थान पर धोएं।',
          'ट्राइसाइक्लाजोल जलीय जीवों के लिए अत्यंत विषैला है; दवा को पास के तालाबों या मछली पालन पोखरों में जाने से रोकें।',
          'छिड़काव के बाद 48 घंटे तक खेत में प्रवेश न करें।',
        ],
        mr: [
          'वॉटरप्रूफ संपूर्ण अंग झाकणारा सूट, सुरक्षा गॉगल, निओप्रीन हातमोजे आणि उंच गमबूट वापरा.',
          'फवारणी पंप व नोझल्स पिण्याच्या विहिरी, तलाव किंवा नद्यांपासून दूर धुवावेत.',
          'ट्रायसायक्लॅझोल हे जलचरांसाठी (माशांसाठी) अतिविषारी आहे; औषध शेजारच्या तलावात किंवा शेततळ्यात वाहून जाणार नाही याची दक्षता घ्या.',
          'फवारणीनंतर किमान ४८ तास शेतात जाणे टाळा.',
        ],
      },
      etlCriteria: {
        en: 'Economic Threshold Level (ETL): 2-5% leaf area affected with diamond spindle lesions, or 1-2% neck/node infection observed at panicle emergence when night temperature is 19-24°C with relative humidity >90%.',
        hi: 'आर्थिक दहलीज स्तर (ETL): 2-5% पत्तों पर तकुआ आकार के धब्बे या बाली निकलते समय 1-2% गर्दन संक्रमण, जब रात का तापमान 19-24°C और आर्द्रता 90% से अधिक हो।',
        mr: 'आर्थिक नुकसान पातळी (ETL): पानांवर २ ते ५% चाकोरीसारखे करपा डाग दिसणे किंवा लोंबी बाहेर पडण्याच्या वेळी १ ते २% मानेवर करपा आढळणे, जेव्हा रात्रीचे तापमान १९-२४° से व आर्द्रता ९०% पेक्षा जास्त असते.',
      },
    },
  },
};

/**
 * SCENARIO 3: Cotton Pink Bollworm / Leaf Curl Complex
 * Severe economic pest outbreak across Vidarbha cotton belt (Nagpur, Wardha, Yavatmal).
 */
export const COTTON_PINK_BOLLWORM_DIAGNOSTIC: DiagnosticResult = {
  scanId: 'FLX-SCAN-2026-COT-309',
  timestamp: '2026-11-14T10:10:00.000Z',
  cropName: 'Bt Cotton (Gossypium hirsutum)',
  topCandidates: [
    {
      id: 'DIS-COT-PINK-BOLLWORM',
      name: {
        en: 'Pink Bollworm (Rosette Flower & Locule Damage)',
        hi: 'कपास की गुलाबी सुंडी (गुलाब फूल व बोंड क्षति)',
        mr: 'कापसावरील गुलाबी बोंड अळी (रोजेट फुले व बोंड नुकसान)',
      },
      scientificName: 'Pectinophora gossypiella',
      confidence: 93.1,
      category: 'PEST',
    },
    {
      id: 'DIS-COT-LEAF-CURL',
      name: {
        en: 'Cotton Leaf Curl Virus (CLCuV)',
        hi: 'कपास का पर्ण कुंचन विषाणु रोग',
        mr: 'कापसावरील चुरडा-मुरडा / पर्ण आकुंचन विषाणू',
      },
      scientificName: 'Cotton Leaf Curl Begomovirus',
      confidence: 4.4,
      category: 'VIRAL',
    },
    {
      id: 'DIS-COT-SPOTTED-BOLLWORM',
      name: {
        en: 'Spotted Bollworm',
        hi: 'चित्तीदार सुंडी',
        mr: 'ठिपकेवाली बोंड अळी',
      },
      scientificName: 'Earias vittella',
      confidence: 2.5,
      category: 'PEST',
    },
  ],
  lesionAreaPercentage: 16.5,
  gradCamRegions: [
    {
      x: 41.2,
      y: 35.4,
      radius: 13.5,
      intensity: 0.97,
      label: 'Rosetted flower bloom with petals twisted and sealed by larval webbing',
    },
    {
      x: 65.8,
      y: 58.7,
      radius: 11.0,
      intensity: 0.91,
      label: 'Minute entry pin-hole and frass ejection on developing green boll',
    },
    {
      x: 52.0,
      y: 72.3,
      radius: 9.2,
      intensity: 0.83,
      label: 'Discolored locule and stained lint inside dissected boll carpel',
    },
  ],
  requiresExpertVerification: false,
  verificationStatus: 'AI_VERIFIED',
  ipmAdvisory: {
    culturalMechanical: {
      en: [
        'Install yellow sticky traps (15-20 per acre) at canopy height for whiteflies (CLCuV vectors) and Delta Pheromone traps with Gossyplure septa (8-10 traps per acre) for monitoring male pink bollworm moths.',
        'Manually pluck and collect rosetted flowers (interlocked petals) daily during morning walk-throughs; place them in plastic bags and destroy.',
        'Strictly terminate crop duration within 160-180 days after sowing; avoid ratoon (khodwa) cotton to disrupt the pest diapause cycle.',
        'Graze sheep and goats immediately following the final picking to devour leftover green bolls containing diapausing larvae.',
        'Install light traps (1 trap per 5 acres) operated from 07:00 PM to 10:00 PM to trap nocturnal adult moths.',
      ],
      hi: [
        'सफेद मक्खी (विषाणु वाहक) के लिए पीले चिपचिपे ट्रैप (15-20 प्रति एकड़) और गुलाबी सुंडी के लिए गॉसीप्लूर युक्त फेरोमोन ट्रैप (8-10 प्रति एकड़) लगाएं।',
        'रोजाना सुबह खेत में जाकर बंधी हुई कलियों (गुलाब जैसे फूल / रोजेट फूल) को हाथ से तोड़कर थैली में बंद कर नष्ट करें।',
        'फसल को 160-180 दिनों में अनिवार्य रूप से समाप्त करें; कीट का जीवन चक्र तोड़ने के लिए रतून (खोडवा) कपास बिल्कुल न लें।',
        'अंतिम चुनाई के तुरंत बाद खेत में भेड़-बकरियां चराएं ताकि वे अवशिष्ट हरे बोंडों और सुंडियों को खा सकें।',
        'वयस्क पतंगों को फंसाने के लिए रात 7:00 से 10:00 बजे तक प्रकाश प्रपंच (लाइट ट्रैप @ 1 प्रति 5 एकड़) चलाएं।',
      ],
      mr: [
        'पांढरी माशी (चुरडा मुरडा वाहक) नियंत्रणासाठी पिवळे चिकट सापळे (१५-२० प्रति एकर) आणि नर पतंग पकडण्यासाठी गॉसीप्लूर कामगंध सापळे (८-१० प्रति एकर) पिकाच्या उंचीवर लावा.',
        'दररोज सकाळी शेतात फेरफटका मारून बोंड अळीने बंद झालेली "गुलाबी रोजेट फुले" हाताने गोळा करून प्लॅस्टिकच्या पिशवीत भरून नष्ट करा.',
        'किडीचा जीवनक्रम खंडित करण्यासाठी कपाशीचा खोडवा (रतून) घेऊ नका आणि पीक १६०-१८० दिवसांत संपवा.',
        'शेवटच्या वेचणीनंतर शेतात शेळ्या-मेंढ्या चरण्यासाठी सोडाव्यात जेणेकरून सुप्त अवस्थेतील अळ्या असलेली शेवटची बोंडे नष्ट होतील.',
        'रात्री ७ ते १० या वेळेत प्रकाश सापळे (१ सापळा प्रति ५ एकर) लावून प्रौढ पतंग नष्ट करा.',
      ],
    },
    biologicalBotanical: {
      en: [
        'Inundative field release of egg parasitoid Trichogramma bactrae @ 150,000 parasitized eggs/ha (3 to 4 Tricho-cards per acre) 3-4 times at weekly intervals starting 45 days after sowing.',
        'Foliar spray of entomopathogenic fungus Beauveria bassiana (1 x 10^8 CFU/g @ 5 g/L) or Bacillus thuringiensis var. kurstaki (Bt @ 2 g/L).',
        'Spray 5% Neem Seed Kernel Extract (NSKE @ 50 g/L) or cold-pressed Azadirachtin (10,000 ppm @ 2 mL/L) at square formation to deter oviposition.',
      ],
      hi: [
        'बुवाई के 45 दिनों बाद अंडा परजीवी ट्राइकोग्रामा बैक्ट्रे (1.5 लाख प्रति हेक्टेयर या 3-4 ट्राइको-कार्ड प्रति एकड़) 3-4 बार साप्ताहिक अंतराल पर छोड़ें।',
        'कीट-रोगजनक कवक बवेरिया बेसियाना (5 ग्राम/लीटर) या बैसिलस थुरिनजिएन्सिस (Bt @ 2 ग्राम/लीटर) का छिड़काव करें।',
        'अंडे देने से रोकने के लिए फूल-कलियां बनते समय 5% नीम बीज अर्क (NSKE @ 50 ग्राम/लीटर) या एज़ाडिराक्टिन (10,000 ppm @ 2 मिली/लीटर) छिड़कें।',
      ],
      mr: [
        'पेरणीनंतर ४५ दिवसांनी ट्रायकोग्रामा बॅक्ट्रे (१.५ लाख प्रति हेक्टर किंवा ३-४ ट्रायको-कार्ड प्रति एकर) दर आठवड्याला असे सलग ३ ते ४ वेळा शेतात लावा.',
        'बिव्हेरिया बॅसियाना ही जैविक बुरशी (५ ग्रॅम/लिटर) किंवा बॅसिलस थुरिन्जिनेन्सिस (बीटी @ २ ग्रॅम/लिटर) चा फवारा द्या.',
        'पतंगांना अंडी घालण्यापासून रोखण्यासाठी पाते लागण्याच्या अवस्थेत ५% निंबोळी अर्क (NSKE @ ५० ग्रॅम/लिटर) किंवा अझाडिराक्टिन (१०,००० पीपीएम @ २ मिली/लिटर) फवारा.',
      ],
    },
    chemicalControl: {
      lockedByThreshold: false,
      productName: 'Chlorantraniliprole 18.5% SC or Emamectin Benzoate 5% SG',
      dosagePerLitre: 'Chlorantraniliprole 18.5% SC @ 0.3 mL/L OR Emamectin Benzoate 5% SG @ 0.4 g/L',
      waitingPeriodDays: 20,
      ppeWarnings: {
        en: [
          'Wear heavy-duty nitrile/PVC chemical apron, organic vapor respirator mask, and chemical splash goggles.',
          'Never spray when honeybees and pollinators are actively foraging (strictly between 06:00 AM and 09:00 AM).',
          'Do not graze milch cattle in treated fields for at least 3 weeks following chemical application.',
          'Store chemical bottles in double-locked chemical cabinets away from children, animal feed, and grain stores.',
        ],
        hi: [
          'भारी पीवीसी रासायनिक एप्रन, जैविक वाष्प मास्क और चश्मा अवश्य पहनें।',
          'मधुमक्खियों के परागण के सक्रिय समय पर छिड़काव बिल्कुल न करें (केवल सुबह 6:00 से 9:00 बजे तक ही करें)।',
          'छिड़काव के कम से कम 3 सप्ताह बाद तक दुधारू पशुओं को खेत में न चरने दें।',
          'कीटनाशकों को बच्चों, पशु आहार और अनाज से दूर ताले में रखें।',
        ],
        mr: [
          'पीव्हीसी केमिकल ॲप्रन, गॅस फिल्टर रेस्पिरेटर मास्क आणि सुरक्षा गॉगलचा वापर अनिवार्य करा.',
          'मधमाशा व मित्रकीटक परागीभवनासाठी फिरत असताना फवारणी करू नका (फक्त सकाळी ६:०० ते ९:०० या वेळेतच करावी).',
          'फवारणीनंतर किमान ३ आठवडे दुभत्या जनावरांना शेतात चरू देऊ नका.',
          'कीटकनाशकांच्या बाटल्या कुलूपबंद पेटीत लहान मुले, जनावरांचे खाद्य व धान्यापासून दूर ठेवा.',
        ],
      },
      etlCriteria: {
        en: 'Economic Threshold Level (ETL): 8 adult male moths caught per pheromone trap per night for 3 consecutive nights, OR 10% damaged green bolls / rosetted flowers observed containing live pink larvae.',
        hi: 'आर्थिक दहलीज स्तर (ETL): लगातार 3 रातों तक प्रति फेरोमोन ट्रैप में औसतन 8 नर पतंगे मिलना, या 10% हरे बोंडों/गुलाब जैसे फूलों में जीवित गुलाबी सुंडी मिलना।',
        mr: 'आर्थिक नुकसान पातळी (ETL): सलग ३ रात्री कामगंध सापळ्यात सरासरी ८ किंवा जास्त नर पतंग अडकणे, किंवा १०% हिरव्या बोंडांमध्ये / रोजेट फुलांमध्ये जिवंत गुलाबी बोंड अळी आढळणे.',
      },
    },
  },
};

/**
 * SCENARIO 4: Nitrogen & Magnesium Dual Nutrient Deficiency
 * Abiotic physiological chlorosis across intensive vegetable and sugarcane belts (Satara, Pune).
 * Synthetic pesticides are strictly LOCKED; balanced mineral fertigation protocol enforced.
 */
export const NUTRIENT_DEFICIENCY_DIAGNOSTIC: DiagnosticResult = {
  scanId: 'FLX-SCAN-2026-NUT-412',
  timestamp: '2026-11-14T11:20:00.000Z',
  cropName: 'Tomato / Solanaceous Vegetables',
  topCandidates: [
    {
      id: 'DIS-NUT-N-MG-DEFICIENCY',
      name: {
        en: 'Nitrogen & Magnesium Dual Deficiency (Interveinal Chlorosis)',
        hi: 'नत्र (नाइट्रोजन) एवं मैग्नीशियम पोषक तत्व की कमी',
        mr: 'नत्र आणि मॅग्नेशियम अन्नद्रव्यांची कमतरता (शिरांमधील पिवळेपणा)',
      },
      scientificName: 'Abiotic Physiological Nutritional Disorder (N & Mg)',
      confidence: 88.6,
      category: 'NUTRIENT',
    },
    {
      id: 'DIS-NUT-FE-CHLOROSIS',
      name: {
        en: 'Iron Deficiency Chlorosis',
        hi: 'लौह (आयरन) की कमी का पीलापन',
        mr: 'लोह (आयर्न) कमतरता पिवळेपणा',
      },
      scientificName: 'Iron (Fe) Induced Interveinal Chlorosis',
      confidence: 7.2,
      category: 'NUTRIENT',
    },
    {
      id: 'DIS-VIR-LEAF-YELLOWING',
      name: {
        en: 'Early Whitefly Phytoplasma Yellowing',
        hi: 'शुरुआती फाइटोप्लाज्मा पीलापन',
        mr: 'सुरुवातीचा फायटोप्लाझ्मा पिवळेपणा',
      },
      scientificName: 'Candidatus Phytoplasma aurantifolia',
      confidence: 4.2,
      category: 'VIRAL',
    },
  ],
  lesionAreaPercentage: 22.4,
  gradCamRegions: [
    {
      x: 48.0,
      y: 62.0,
      radius: 17.5,
      intensity: 0.95,
      label: 'Pronounced interveinal chlorosis on older mature bottom foliage (Mg deficiency)',
    },
    {
      x: 35.2,
      y: 45.1,
      radius: 13.0,
      intensity: 0.87,
      label: 'Inverted V-shaped pale yellowing advancing along midrib (Nitrogen depletion)',
    },
    {
      x: 72.4,
      y: 70.8,
      radius: 11.0,
      intensity: 0.80,
      label: 'Marginal purple-red pigmentation due to anthocyanin accumulation in low Mg tissue',
    },
  ],
  requiresExpertVerification: false,
  verificationStatus: 'AI_VERIFIED',
  ipmAdvisory: {
    culturalMechanical: {
      en: [
        'Conduct immediate soil testing for Electrical Conductivity (EC), pH, and exchangeable cations (Ca, Mg, K).',
        'Incorporate 10-12 tonnes/ha of well-decomposed Farm Yard Manure (FYM) or 3 tonnes/ha of enriched vermicompost to enhance cation exchange capacity (CEC).',
        'If soil pH is acidic (< 6.0), broadcast agricultural dolomite limestone (calcium magnesium carbonate) @ 1.5-2.0 tonnes/ha.',
        'Address soil compaction and waterlogging; poor root aeration directly suppresses active nitrate and magnesium trans-membrane uptake.',
        'Flush excessive potassium salts if drip fertigation was over-supplied, as high K+ antagonizes Mg2+ root absorption.',
      ],
      hi: [
        'तत्काल मिट्टी परीक्षण करवाकर ईसी (EC), पीएच (pH) और विनिमेय मैग्नीशियम की जांच करें।',
        'जमीन की उर्वरा शक्ति बढ़ाने के लिए 10-12 टन अच्छी सड़ी गोबर की खाद (FYM) या 3 टन वर्मीकंपोस्ट प्रति हेक्टेयर डालें।',
        'यदि मिट्टी का पीएच 6.0 से कम (अम्लीय) हो, तो 1.5-2.0 टन डोलोमाइट चूना प्रति हेक्टेयर बुरकें।',
        'खेत में जलभराव रोकें; जड़ों के पास हवा न मिलने से नाइट्रोजन और मैग्नीशियम का अवशोषण रुक जाता है।',
        'यदि पोटाश (K) ज्यादा दिया गया हो तो अतिरिक्त सिंचाई से निथारें, क्योंकि अधिक पोटाश मैग्नीशियम के अवशोषण को बाधित करता है।',
      ],
      mr: [
        'तातडीने माती परीक्षण करून जमिनीचा सामू (pH), क्षारता (EC) आणि विनिमेय मॅग्नेशियमचे प्रमाण तपासून घ्या.',
        'जमिनीची अन्नद्रव्ये धरून ठेवण्याची क्षमता वाढवण्यासाठी हेक्टरी १० ते १२ टन कुजलेले शेणखत किंवा ३ टन गांडूळखत जमिनीत मिसळा.',
        'जमीन आम्लधर्मी (सामू ६.० पेक्षा कमी) असल्यास हेक्टरी १.५ ते २ टन डोलोमाइट चुनखडी शेतात पसरवून द्या.',
        'मुळांभोवती पाणी साचू देऊ नका; दलदलीमुळे झाडांचे नत्र व मॅग्नेशियम शोषण पूर्णपणे थांबते.',
        'पोटॅश खतांचा अवाजवी वापर टाळा, कारण पोटॅशियमचे अधिक प्रमाण मॅग्नेशियमच्या शोषणाला तीव्र विरोध करते.',
      ],
    },
    biologicalBotanical: {
      en: [
        'Soil application of Nitrogen-fixing biofertilizers (Azotobacter chroococcum for vegetables or Azospirillum @ 2 kg/acre) mixed in 200 kg vermicompost.',
        'Drip application of Potash & Zinc Solubilizing Bacteria (KSB/ZSB @ 1 L/acre) to optimize rhizosphere ionic balance.',
        'Inoculate seedling roots with Vesicular Arbuscular Mycorrhizae (VAM / Glomus intraradices @ 4-5 kg/acre) to drastically amplify root surface area.',
        'Apply fermented organic Jeevamrutha (200 L/acre) every 14 days via drip irrigation.',
      ],
      hi: [
        'नाइट्रोजन स्थिरीकरण जीवाणु खाद (एजोटोबैक्टर या एजोस्पिरिलम @ 2 किग्रा/एकड़) को 200 किग्रा वर्मीकंपोस्ट में मिलाकर मिट्टी में दें।',
        'जैव-उर्वरक (पोटाश व जिंक घोलक जीवाणु @ 1 लीटर/एकड़) ड्रिप से चलाएं।',
        'जड़ों के विकास के लिए माइकोराइजा (VAM @ 4-5 किग्रा/एकड़) का प्रयोग करें।',
        'हर 14 दिन पर जीवामृत (200 लीटर/एकड़) ड्रिप से सिंचाई के साथ दें।',
      ],
      mr: [
        'नत्र स्थिर करणारे जैविक खत (ॲझोटोबॅक्टर किंवा ॲझोस्पिरिलम @ २ किलो/एकर) २०० किलो गांडूळखतात मिसळून मुळांशी द्या.',
        'पालाश व जस्त विरघळवणारे जिवाणू संवर्धन (१ लिटर/एकर) ठिबक सिंचनातून द्या.',
        'मुळांची कार्यक्षमता व अन्नद्रव्य शोषण क्षेत्र वाढवण्यासाठी मायकोरायझा (VAM @ ४-५ किलो/एकर) जमिनीत टाका.',
        'दर १४ दिवसांनी २०० लिटर जीवामृत ठिबक सिंचनाद्वारे पिकाला द्या.',
      ],
    },
    chemicalControl: {
      lockedByThreshold: true,
      productName: 'Magnesium Sulphate (MgSO4 9.6% Mg) + 100% Water Soluble Urea / 19:19:19',
      dosagePerLitre: 'Foliar: Magnesium Sulphate @ 5.0 g/L (0.5%) + Soluble Urea @ 10.0 g/L (1.0%); Fertigation: MgSO4 @ 5 kg/acre',
      waitingPeriodDays: 0,
      ppeWarnings: {
        en: [
          'PESTICIDES LOCKED: Synthetic chemical pesticides/fungicides are NOT applicable for abiotic physiological nutritional deficiencies.',
          'Wear standard eye-protection goggles and rubber gloves to avoid skin dryness from high-salt mineral foliar sprays.',
          'Never mix Magnesium Sulphate directly with concentrated Phosphate fertilizers (e.g., 0:52:34 or Phosphoric acid) in the same spray tank to avoid magnesium phosphate precipitate formation.',
        ],
        hi: [
          'कीटनाशक लॉक: अजैविक पोषण संबंधी कमियों के लिए रासायनिक कीटनाशकों का प्रयोग पूर्णतः अनुचित व प्रतिबंधित है।',
          'लवणों के घोल से त्वचा व आंखों के बचाव के लिए सामान्य सुरक्षा चश्मा व रबर के दस्ताने पहनें।',
          'स्प्रे टैंक में मैग्नीशियम सल्फेट को फॉस्फेट उर्वरकों (जैसे 0:52:34) के साथ न मिलाएं ताकि अघुलनशील अवक्षेप न बने।',
        ],
        mr: [
          'कीटकनाशक फवारणी लॉक: अजैविक अन्नद्रव्य कमतरतेवर रासायनिक विषारी कीटकनाशके फवारणे पूर्णतः अयोग्य व प्रतिबंधित आहे.',
          'क्षारांच्या द्रावणापासून डोळ्यांचे रक्षण करण्यासाठी गॉगल आणि रबरी हातमोजे वापरा.',
          'मॅग्नेशियम फॉस्फेटचा साका तयार होऊन नोझल तुंबू नये म्हणून मॅग्नेशियम सल्फेट व फॉस्फेटयुक्त खते (उदा. ०:५२:३४) एकाच टाकीत एकत्र मिसळू नका.',
        ],
      },
      etlCriteria: {
        en: 'Deficiency Criteria: Soil test exchangeable Mg < 1.0 cmol/kg or leaf blade Mg < 0.25% DM and Total N < 2.8% DM with visible interveinal chlorosis across >15% of the lower canopy.',
        hi: 'कमी सीमा: मिट्टी में मैग्नीशियम < 1.0 cmol/kg या पत्तियों में Mg < 0.25% और कुल नाइट्रोजन < 2.8% होने पर निचले 15% पत्तों में शिराओं के बीच पीलापन दिखना।',
        mr: 'कमतरता मर्यादा: मातीतील उपलब्ध मॅग्नेशियम १.० cmol/kg पेक्षा कमी किंवा पानांमधील मॅग्नेशियम ०.२५% आणि नत्र २.८% पेक्षा कमी असून खालच्या १५% पेक्षा जास्त पानांवर शिरांमधील पिवळेपणा स्पष्ट दिसणे.',
      },
    },
  },
};

// ============================================================================
// SECTION 2: MAHARASHTRA DISTRICT EPIDEMIC OUTBREAK CLUSTERS
// ============================================================================

/**
 * Verified epidemiological outbreak clusters and meteorological risk profiles
 * across 5 major Maharashtra agro-climatic zones (Nashik, Pune, Raigad, Satara, Nagpur).
 */
export const MAHARASHTRA_VILLAGE_OUTBREAK_CLUSTERS: VillageOutbreakCluster[] = [
  {
    clusterId: 'MH-NSK-DINDORI-01',
    village: 'Dindori (दिंडोरी)',
    taluka: 'Dindori',
    district: 'Nashik',
    coordinates: { lat: 20.2036, lng: 73.8314 },
    primaryCrop: 'Tomato & Table Grapes',
    affectedHectares: 480,
    activeFarmerAlerts: 142,
    weatherRisk: {
      district: 'Nashik',
      tempC: 25.2,
      humidity: 88,
      rainfallMm: 44.5,
      outbreakRiskScore: 88,
      predictedThreats: [
        {
          diseaseName: {
            en: 'Tomato Early Blight (Alternaria solani)',
            hi: 'टमाटर का अगेती झुलसा रोग',
            mr: 'टोमॅटोवरील लवकर येणारा करपा',
          },
          riskLevel: 'CRITICAL',
          reason: {
            en: 'Continuous cloud cover and sustained relative humidity >85% for 48 hours creating optimal spore germination conditions.',
            hi: 'लगातार 48 घंटों से बादल छाए रहने और 85% से अधिक आर्द्रता के कारण बीजाणु अंकुरण की अनुकूल स्थिति।',
            mr: 'सलग ४८ तास ढगाळ हवामान व ८५% पेक्षा जास्त सापेक्ष आर्द्रता यामुळे बुरशीच्या बीजाणू उगवणीसाठी अत्यंत पोषक वातावरण.',
          },
        },
        {
          diseaseName: {
            en: 'Grape Downy Mildew (Plasmopara viticola)',
            hi: 'अंगूर का डाउनी मिल्ड्यू (मृदु रोमिल आसिता)',
            mr: 'द्राक्षावरील डाऊनी मिल्ड्यू (केवडा रोग)',
          },
          riskLevel: 'HIGH',
          reason: {
            en: 'Leaf wetness duration exceeding 6 continuous hours at temperatures between 22-26°C.',
            hi: '22-26°C तापमान में 6 घंटे से अधिक समय तक पत्तियों का गीला रहना।',
            mr: '२२ ते २६° से तापमानात सलग ६ तासांपेक्षा जास्त वेळ पाने ओली राहिल्याने केवडा रोगाचा धोका.',
          },
        },
      ],
    },
  },
  {
    clusterId: 'MH-PUN-JUNNAR-02',
    village: 'Otur (ओतूर)',
    taluka: 'Junnar',
    district: 'Pune',
    coordinates: { lat: 19.2612, lng: 73.9167 },
    primaryCrop: 'Tomato & Kharif Onion',
    affectedHectares: 320,
    activeFarmerAlerts: 94,
    weatherRisk: {
      district: 'Pune',
      tempC: 27.2,
      humidity: 79,
      rainfallMm: 16.2,
      outbreakRiskScore: 74,
      predictedThreats: [
        {
          diseaseName: {
            en: 'Tomato Early Blight & Septoria Spot',
            hi: 'टमाटर अगेती झुलसा एवं सेप्टोरिया धब्बा',
            mr: 'टोमॅटो करपा व सेप्टोरिया ठिपके',
          },
          riskLevel: 'HIGH',
          reason: {
            en: 'Intermittent afternoon showers coupled with dense canopy microclimate in stake-free tomato fields.',
            hi: 'दोपहर में रुक-रुक कर बारिश और बिना बंधाई वाले टमाटर के खेतों में नमी का ठहराव।',
            mr: 'दुपारच्या तुरळक सरी आणि आधार न दिलेल्या टोमॅटो पिकात जास्त आर्द्रता साचल्याने करप्याचा फैलाव.',
          },
        },
        {
          diseaseName: {
            en: 'Onion Purple Blotch (Alternaria porri)',
            hi: 'प्याज का बैंगनी धब्बा रोग',
            mr: 'कांद्यावरील जांभळा करपा रोग',
          },
          riskLevel: 'MODERATE',
          reason: {
            en: 'Morning dew persistence and Thrips vector feeding creating entry wounds for Alternaria porri conidia.',
            hi: 'सुबह की ओस और थ्रिप्स कीट के काटने से पत्तियों पर घाव बनना।',
            mr: 'सकाळचे दव आणि फुलकिड्यांच्या (थ्रिप्स) प्रादुर्भावामुळे पानांवर जखमा होऊन करपा बुरशीचा शिरकाव.',
          },
        },
      ],
    },
  },
  {
    clusterId: 'MH-RGD-MANGAON-03',
    village: 'Nizampur (निझामपूर)',
    taluka: 'Mangaon',
    district: 'Raigad',
    coordinates: { lat: 18.2534, lng: 73.2891 },
    primaryCrop: 'Lowland Paddy (Rice)',
    affectedHectares: 640,
    activeFarmerAlerts: 215,
    weatherRisk: {
      district: 'Raigad',
      tempC: 29.1,
      humidity: 95,
      rainfallMm: 118.0,
      outbreakRiskScore: 94,
      predictedThreats: [
        {
          diseaseName: {
            en: 'Paddy Blast (Magnaporthe oryzae)',
            hi: 'धान का झोंका रोग (ब्लास्ट)',
            mr: 'भातावरील करपा व मानमोड्या रोग',
          },
          riskLevel: 'CRITICAL',
          reason: {
            en: 'Extreme coastal humidity (95%), nocturnal temperatures dropping to 21°C, and heavy precipitation during panicle initiation.',
            hi: 'अत्यधिक तटीय आर्द्रता (95%), रात का तापमान 21°C तक गिरना और बाली निकलते समय मूसलाधार बारिश।',
            mr: 'किनारपट्टीवरील अतिउच्च आर्द्रता (९५%), रात्रीचे २१° से पर्यंत घसरलेले तापमान आणि पोटरीच्या अवस्थेत मुसळधार पाऊस.',
          },
        },
        {
          diseaseName: {
            en: 'Paddy Sheath Blight (Rhizoctonia solani)',
            hi: 'धान का पर्णच्छद झुलसा',
            mr: 'भातावरील पर्णकोष करपा',
          },
          riskLevel: 'HIGH',
          reason: {
            en: 'Flooded stagnant water depth > 10 cm and high planting density facilitating mycelial bridging.',
            hi: 'खेत में 10 सेमी से अधिक पानी का ठहराव और घनी रोपाई।',
            mr: 'शेतात १० सेमीपेक्षा जास्त पाणी साचणे आणि दाट लावणीमुळे बुरशीचे धागे एका झाडावरून दुसऱ्या झाडावर पसरणे.',
          },
        },
      ],
    },
  },
  {
    clusterId: 'MH-STR-KARAD-04',
    village: 'Umbraj (उंब्रज)',
    taluka: 'Karad',
    district: 'Satara',
    coordinates: { lat: 17.4042, lng: 74.1539 },
    primaryCrop: 'Soybean & Sugarcane',
    affectedHectares: 260,
    activeFarmerAlerts: 67,
    weatherRisk: {
      district: 'Satara',
      tempC: 26.4,
      humidity: 76,
      rainfallMm: 24.0,
      outbreakRiskScore: 62,
      predictedThreats: [
        {
          diseaseName: {
            en: 'Soybean Rust (Phakopsora pachyrhizi)',
            hi: 'सोयाबीन का गेरुई / रस्ट रोग',
            mr: 'सोयाबीनवरील तांबेरा रोग',
          },
          riskLevel: 'MODERATE',
          reason: {
            en: 'Prolonged cloudy skies with morning temperatures of 20-22°C favoring urediniospore dispersal in Krishna valley.',
            hi: 'कृष्णा घाटी में लगातार बादल छाए रहने और सुबह 20-22°C तापमान से रस्ट बीजाणुओं का फैलाव।',
            mr: 'कृष्णा खोऱ्यात दीर्घकाळ ढगाळ हवामान आणि सकाळी २०-२२° से तापमान असल्याने तांबेरा बुरशीचा प्रादुर्भाव.',
          },
        },
        {
          diseaseName: {
            en: 'Nutrient Leaching (Magnesium & Nitrogen Chlorosis)',
            hi: 'पोषक तत्व क्षरण (मैग्नीशियम व नाइट्रोजन पीलापन)',
            mr: 'अन्नद्रव्य लीचिंग (नत्र व मॅग्नेशियम कमतरता)',
          },
          riskLevel: 'HIGH',
          reason: {
            en: 'Intensive irrigation in sandy-loam soils leaching Mg2+ and NO3- below effective root uptake zones.',
            hi: 'बलुई दोमट मिट्टी में अत्यधिक सिंचाई से मैग्नीशियम और नाइट्रेट का जड़ क्षेत्र से नीचे बह जाना।',
            mr: 'वाळूमिश्रित पोयटा जमिनीत अतिपाण्यामुळे मुळांच्या कार्यकक्षेखाली मॅग्नेशियम व नायट्रेट वाहून जाणे.',
          },
        },
      ],
    },
  },
  {
    clusterId: 'MH-NGP-KATOL-05',
    village: 'Katol (काटोल)',
    taluka: 'Katol',
    district: 'Nagpur',
    coordinates: { lat: 21.2721, lng: 78.5833 },
    primaryCrop: 'Bt Cotton & Nagpur Mandarin',
    affectedHectares: 540,
    activeFarmerAlerts: 188,
    weatherRisk: {
      district: 'Nagpur',
      tempC: 33.8,
      humidity: 82,
      rainfallMm: 38.0,
      outbreakRiskScore: 86,
      predictedThreats: [
        {
          diseaseName: {
            en: 'Cotton Pink Bollworm (Pectinophora gossypiella)',
            hi: 'कपास की गुलाबी सुंडी',
            mr: 'कापसावरील गुलाबी बोंड अळी',
          },
          riskLevel: 'CRITICAL',
          reason: {
            en: 'Pheromone trap catches exceeding 12 male moths/trap/night across Vidarbha cotton tracts during boll development phase.',
            hi: 'विदर्भ कपास क्षेत्र में बोंड विकास के समय फेरोमोन ट्रैप में प्रति रात 12 से अधिक पतंगे मिलना।',
            mr: 'बोंडे भरण्याच्या मोसमात विदर्भातील कपाशी पट्ट्यात कामगंध सापळ्यात प्रति रात्री १२ पेक्षा जास्त नर पतंग अडकणे.',
          },
        },
        {
          diseaseName: {
            en: 'Citrus Bacterial Canker (Xanthomonas axonopodis)',
            hi: 'नींबू वर्गीय कैंकर रोग',
            mr: 'संत्र्यावरील खैऱ्या / कॅन्कर रोग',
          },
          riskLevel: 'HIGH',
          reason: {
            en: 'High temperatures (34°C) with gusty rain-wind events dispersing bacterial ooze across Nagpur mandarin orchards.',
            hi: 'तेज आंधी-बारिश और 34°C तापमान में जीवाणुज रिसाव का संतरा बगीचों में फैलना।',
            mr: '३४° से तापमान, वादळी पाऊस व वाऱ्यामुळे संत्र्याच्या बागांमध्ये खैऱ्या रोगाच्या जिवाणूंचा वेगाने प्रसार.',
          },
        },
      ],
    },
  },
];

// ============================================================================
// SECTION 3: MULTI-TEMPORAL PLANT PROGRESSION TIMELINES
// ============================================================================

/**
 * Sample sequential progression records tracking individual tagged plants
 * across multi-day scans to monitor recovery, stabilization, or epidemic spread.
 */
export const SAMPLE_PROGRESSION_RECORDS: ProgressionRecord[] = [
  {
    plantId: 'PLANT-TOM-NSK-081',
    plantLabel: 'Tomato Specimen #81 (Dindori Plot B-4)',
    scans: [
      {
        date: '2026-11-04',
        lesionPercentage: 21.5,
        status: 'SPREADING',
        imageUrl: '/scans/tomato-nsk-081-day01.webp',
      },
      {
        date: '2026-11-08',
        lesionPercentage: 16.8,
        status: 'STABLE',
        imageUrl: '/scans/tomato-nsk-081-day05.webp',
      },
      {
        date: '2026-11-12',
        lesionPercentage: 9.4,
        status: 'RECOVERING',
        imageUrl: '/scans/tomato-nsk-081-day09.webp',
      },
      {
        date: '2026-11-15',
        lesionPercentage: 3.2,
        status: 'RECOVERING',
        imageUrl: '/scans/tomato-nsk-081-day12.webp',
      },
    ],
  },
  {
    plantId: 'PLANT-RIC-RGD-104',
    plantLabel: 'Paddy Specimen #104 (Mangaon Lowland Block 2)',
    scans: [
      {
        date: '2026-11-06',
        lesionPercentage: 3.8,
        status: 'STABLE',
        imageUrl: '/scans/paddy-rgd-104-day01.webp',
      },
      {
        date: '2026-11-09',
        lesionPercentage: 9.5,
        status: 'SPREADING',
        imageUrl: '/scans/paddy-rgd-104-day04.webp',
      },
      {
        date: '2026-11-12',
        lesionPercentage: 18.2,
        status: 'SPREADING',
        imageUrl: '/scans/paddy-rgd-104-day07.webp',
      },
      {
        date: '2026-11-15',
        lesionPercentage: 11.2,
        status: 'RECOVERING',
        imageUrl: '/scans/paddy-rgd-104-day10.webp',
      },
    ],
  },
  {
    plantId: 'PLANT-COT-NGP-309',
    plantLabel: 'Bt Cotton Specimen #309 (Katol Demonstration Farm)',
    scans: [
      {
        date: '2026-11-03',
        lesionPercentage: 24.0,
        status: 'SPREADING',
        imageUrl: '/scans/cotton-ngp-309-day01.webp',
      },
      {
        date: '2026-11-08',
        lesionPercentage: 18.5,
        status: 'STABLE',
        imageUrl: '/scans/cotton-ngp-309-day06.webp',
      },
      {
        date: '2026-11-14',
        lesionPercentage: 8.0,
        status: 'RECOVERING',
        imageUrl: '/scans/cotton-ngp-309-day12.webp',
      },
    ],
  },
  {
    plantId: 'PLANT-NUT-STR-412',
    plantLabel: 'Vegetable Chlorosis Specimen #412 (Karad Fertigation Block)',
    scans: [
      {
        date: '2026-11-02',
        lesionPercentage: 28.0,
        status: 'SPREADING',
        imageUrl: '/scans/nutrient-str-412-day01.webp',
      },
      {
        date: '2026-11-07',
        lesionPercentage: 22.4,
        status: 'STABLE',
        imageUrl: '/scans/nutrient-str-412-day06.webp',
      },
      {
        date: '2026-11-13',
        lesionPercentage: 6.5,
        status: 'RECOVERING',
        imageUrl: '/scans/nutrient-str-412-day12.webp',
      },
    ],
  },
];

// ============================================================================
// SECTION 4: MASTER VAULT REGISTRY & QUERY HELPERS
// ============================================================================

/**
 * Registry containing all verified diagnostic records in the FloraX IPM Vault.
 */
export const ALL_DIAGNOSTIC_RECORDS: DiagnosticResult[] = [
  TOMATO_EARLY_BLIGHT_HIGH_CONFIDENCE,
  TOMATO_EARLY_BLIGHT_LOW_CONFIDENCE,
  PADDY_BLAST_DIAGNOSTIC,
  COTTON_PINK_BOLLWORM_DIAGNOSTIC,
  NUTRIENT_DEFICIENCY_DIAGNOSTIC,
];

/**
 * Retrieve a verified diagnostic record by its unique scan identifier.
 */
export function getDiagnosticByScanId(scanId: string): DiagnosticResult | undefined {
  return ALL_DIAGNOSTIC_RECORDS.find((rec) => rec.scanId === scanId);
}

/**
 * Retrieve weather risk assessments for a specific Maharashtra district.
 */
export function getWeatherRiskByDistrict(district: string): WeatherRiskPrediction | undefined {
  const cluster = MAHARASHTRA_VILLAGE_OUTBREAK_CLUSTERS.find(
    (c) => c.district.toLowerCase() === district.toLowerCase()
  );
  return cluster?.weatherRisk;
}

/**
 * Retrieve progression record by plant ID.
 */
export function getProgressionByPlantId(plantId: string): ProgressionRecord | undefined {
  return SAMPLE_PROGRESSION_RECORDS.find((p) => p.plantId === plantId);
}
