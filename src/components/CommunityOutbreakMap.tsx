'use client';

import React, { useState, useEffect, useMemo, useRef } from 'react';
import {
  SupportedLanguage,
  RiskLevel,
  VillageOutbreakCluster,
  WeatherRiskPrediction,
} from '../types/florax';
import { MAHARASHTRA_VILLAGE_OUTBREAK_CLUSTERS } from '../data/icar-ipm-vault';

// ============================================================================
// EXPANDED REGIONAL VILLAGE CLUSTERS (COVERS ALL AGRO-CLIMATIC ZONES)
// ============================================================================

export interface OutbreakReport {
  id: string;
  timestampMinutesAgo: number;
  farmerCount: number;
  distanceKm: number;
  villageName: string;
  taluka: string;
  district: string;
  crop: string;
  diseaseName: Record<SupportedLanguage, string>;
  severity: RiskLevel;
  advisory: Record<SupportedLanguage, string>;
}

/**
 * Extended clusters combining the ICAR vault data with additional
 * representative villages across Konkan, Khandesh, Marathwada, Desh, and Vidarbha.
 */
export const ALL_MAHARASHTRA_CLUSTERS: VillageOutbreakCluster[] = [
  ...MAHARASHTRA_VILLAGE_OUTBREAK_CLUSTERS,
  {
    clusterId: 'MH-NSK-NIPHAD-06',
    village: 'Pimpalgaon Baswant (पिंपळगाव)',
    taluka: 'Niphad',
    district: 'Nashik',
    coordinates: { lat: 20.1700, lng: 73.9800 },
    primaryCrop: 'Export Table Grapes & Onion',
    affectedHectares: 85,
    activeFarmerAlerts: 18,
    weatherRisk: {
      district: 'Nashik',
      tempC: 25.0,
      humidity: 62,
      rainfallMm: 2.0,
      outbreakRiskScore: 38,
      predictedThreats: [
        {
          diseaseName: {
            en: 'Powdery Mildew (Erysiphe necator)',
            hi: 'अंगूर का चूर्णिल आसिता रोग',
            mr: 'द्राक्षावरील भुरी रोग',
          },
          riskLevel: 'LOW',
          reason: {
            en: 'Dry afternoon winds keeping canopy humidity below spore threshold. Regular sulfur dusting effective.',
            hi: 'दोपहर की शुष्क हवाओं से आर्द्रता नियंत्रित। सल्फर का नियमित छिड़काव प्रभावी।',
            mr: 'दुपारच्या कोरड्या हवेमुळे आर्द्रता कमी राहिली आहे. गंधकाची धुरळणी प्रभावी ठरत आहे.',
          },
        },
      ],
    },
  },
  {
    clusterId: 'MH-PUN-BARAMATI-07',
    village: 'Malegaon BK (माळेगाव)',
    taluka: 'Baramati',
    district: 'Pune',
    coordinates: { lat: 18.1500, lng: 74.5800 },
    primaryCrop: 'Sugarcane & Green Fodder',
    affectedHectares: 120,
    activeFarmerAlerts: 14,
    weatherRisk: {
      district: 'Pune',
      tempC: 27.8,
      humidity: 58,
      rainfallMm: 0.0,
      outbreakRiskScore: 32,
      predictedThreats: [
        {
          diseaseName: {
            en: 'Sugarcane Red Rot (Colletotrichum falcatum)',
            hi: 'गन्ने का लाल सड़न रोग',
            mr: 'उसावरील तांबडे कूज रोग (रेड रॉट)',
          },
          riskLevel: 'LOW',
          reason: {
            en: 'Canal irrigation strictly monitored. Well-drained black cotton soils preventing water stagnation.',
            hi: 'नहर सिंचाई नियंत्रित। जलभराव न होने से फसल सुरक्षित।',
            mr: 'कालव्याचे पाणी योग्य नियोजनात. पाण्याचा चांगला निचरा होत असल्याने पीक निरोगी.',
          },
        },
      ],
    },
  },
  {
    clusterId: 'MH-AHM-RAHURI-08',
    village: 'Rahuri Rural (राहुरी)',
    taluka: 'Rahuri',
    district: 'Ahmednagar',
    coordinates: { lat: 19.3900, lng: 74.6500 },
    primaryCrop: 'Pomegranate & Rabi Sorghum',
    affectedHectares: 210,
    activeFarmerAlerts: 52,
    weatherRisk: {
      district: 'Ahmednagar',
      tempC: 28.5,
      humidity: 71,
      rainfallMm: 8.5,
      outbreakRiskScore: 64,
      predictedThreats: [
        {
          diseaseName: {
            en: 'Pomegranate Bacterial Blight (Telya)',
            hi: 'अनार का तेलिया जीवाणु रोग',
            mr: 'डाळिंबावरील तेल्या रोग (जिवाणू करपा)',
          },
          riskLevel: 'MODERATE',
          reason: {
            en: 'High humidity during fruit development stage. KVK MPKV Rahuri advising strict copper bactericide schedule.',
            hi: 'फल विकास अवस्था में नमी का बढ़ना। कॉपर युक्त जीवाणुनाशक के प्रयोग की सलाह।',
            mr: 'फळे वाढीच्या अवस्थेत आर्द्रता वाढल्याने तेल्याचा धोका. कॉपरयुक्त जिवाणूनाशकांची फवारणी आवश्यक.',
          },
        },
      ],
    },
  },
  {
    clusterId: 'MH-JAL-AMBAD-09',
    village: 'Ambad (अंबड)',
    taluka: 'Ambad',
    district: 'Jalna',
    coordinates: { lat: 19.6100, lng: 75.7900 },
    primaryCrop: 'Bt Cotton & Sweet Orange (Mosambi)',
    affectedHectares: 390,
    activeFarmerAlerts: 112,
    weatherRisk: {
      district: 'Jalna',
      tempC: 31.2,
      humidity: 82,
      rainfallMm: 22.0,
      outbreakRiskScore: 78,
      predictedThreats: [
        {
          diseaseName: {
            en: 'Cotton Bacterial Leaf Blight',
            hi: 'कपास का जीवाणुज झुलसा रोग',
            mr: 'कापसावरील जिवाणू पानांचा करपा (कोनयुक्त ठिपके)',
          },
          riskLevel: 'HIGH',
          reason: {
            en: 'Warm humid spells causing angular leaf spots. Severe wind-driven rain spreading bacterial inoculum.',
            hi: 'उमस भरे मौसम और हवा के साथ बारिश से जीवाणु तेजी से फैल रहे हैं।',
            mr: 'दमट हवामान आणि सोसाट्याच्या पावसामुळे जिवाणू करप्याचा पानांवर जलद प्रसार.',
          },
        },
      ],
    },
  },
  {
    clusterId: 'MH-RTG-CHIPLUN-10',
    village: 'Chiplun Valley (चिपळूण)',
    taluka: 'Chiplun',
    district: 'Ratnagiri',
    coordinates: { lat: 17.5320, lng: 73.5180 },
    primaryCrop: 'Alphonso Mango & Lowland Cashew',
    affectedHectares: 140,
    activeFarmerAlerts: 22,
    weatherRisk: {
      district: 'Ratnagiri',
      tempC: 28.0,
      humidity: 68,
      rainfallMm: 4.0,
      outbreakRiskScore: 44,
      predictedThreats: [
        {
          diseaseName: {
            en: 'Mango Anthracnose (Colletotrichum gloeosporioides)',
            hi: 'आम का एन्थ्रेक्नोज (श्याम वर्ण)',
            mr: 'आंब्यावरील करपा / एन्थ्रॅक्नोज',
          },
          riskLevel: 'LOW',
          reason: {
            en: 'Pre-flowering vegetative flush resting stage. Routine preventive copper spray maintaining containment.',
            hi: 'फूल आने से पहले की अवस्था। कॉपर का निवारक छिड़काव संक्रमण को रोके हुए है।',
            mr: 'मोहोरापूर्वीची अवस्था. कॉपरच्या प्रतिबंधात्मक फवारणीमुळे रोग नियंत्रणात आहे.',
          },
        },
      ],
    },
  },
];

// ============================================================================
// REALISTIC ANONYMOUS OUTBREAK TICKER REPORTS (ICAR/KVK VERIFIED PATTERNS)
// ============================================================================

export const INITIAL_ANONYMOUS_REPORTS: OutbreakReport[] = [
  {
    id: 'REP-001',
    timestampMinutesAgo: 14,
    farmerCount: 3,
    distanceKm: 4.0,
    villageName: 'Dindori (दिंडोरी)',
    taluka: 'Dindori',
    district: 'Nashik',
    crop: 'Tomato',
    diseaseName: {
      en: 'Tomato Early Blight',
      hi: 'टमाटर का अगेती झुलसा',
      mr: 'टोमॅटोवरील लवकर येणारा करपा',
    },
    severity: 'CRITICAL',
    advisory: {
      en: '3 farmers within 4km reported Tomato Early Blight in the last 48 hrs — Preventive Neem spray advised.',
      hi: '4 किमी के भीतर 3 किसानों ने अगेती झुलसा की पुष्टि की — नीम तेल का निवारक छिड़काव करें।',
      mr: '४ किमी अंतरामध्ये ३ शेतकऱ्यांनी टोमॅटो करप्याची नोंद केली — निंबोळी अर्क प्रतिबंधात्मक फवारणी करा.',
    },
  },
  {
    id: 'REP-002',
    timestampMinutesAgo: 42,
    farmerCount: 6,
    distanceKm: 2.5,
    villageName: 'Otur (ओतूर)',
    taluka: 'Junnar',
    district: 'Pune',
    crop: 'Tomato & Onion',
    diseaseName: {
      en: 'Tomato Early Blight & Septoria Spot',
      hi: 'टमाटर झुलसा एवं सेप्टोरिया धब्बा',
      mr: 'टोमॅटो करपा व सेप्टोरिया ठिपके',
    },
    severity: 'HIGH',
    advisory: {
      en: '6 farmers within 2.5km flagged expanding target-board lesions — Apply prophylactic Trichoderma viride.',
      hi: '2.5 किमी के भीतर 6 किसानों ने गोल छल्लेदार धब्बे देखे — ट्राइकोडर्मा विरिडी का जैविक सुरक्षा कवच छिड़कें।',
      mr: '२.५ किमी अंतरात ६ शेतकऱ्यांनी करप्याचे रिंग ठिपके नोंदवले — ट्रायकोडर्मा विरिडीची फवारणी करावी.',
    },
  },
  {
    id: 'REP-003',
    timestampMinutesAgo: 85,
    farmerCount: 4,
    distanceKm: 6.2,
    villageName: 'Nizampur (निझामपूर)',
    taluka: 'Mangaon',
    district: 'Raigad',
    crop: 'Lowland Paddy',
    diseaseName: {
      en: 'Paddy Blast (Magnaporthe oryzae)',
      hi: 'धान का झोंका रोग (ब्लास्ट)',
      mr: 'भातावरील मानमोड्या व करपा',
    },
    severity: 'CRITICAL',
    advisory: {
      en: '4 farmers within 6.2km reported spindle-shaped leaf lesions — Drain excess standing water immediately.',
      hi: '6.2 किमी के दायरे में 4 किसानों ने नाव के आकार के धब्बे देखे — खेत से अतिरिक्त पानी तुरंत निकालें।',
      mr: '६.२ किमी परिसरात ४ शेतकऱ्यांनी भातावर डोळ्यासारखे ठिपके पाहिले — शेतातील साचलेले पाणी तातडीने बाहेर काढा.',
    },
  },
  {
    id: 'REP-004',
    timestampMinutesAgo: 110,
    farmerCount: 5,
    distanceKm: 3.1,
    villageName: 'Katol (काटोल)',
    taluka: 'Katol',
    district: 'Nagpur',
    crop: 'Bt Cotton',
    diseaseName: {
      en: 'Cotton Pink Bollworm',
      hi: 'कपास की गुलाबी सुंडी',
      mr: 'कापसावरील गुलाबी बोंड अळी',
    },
    severity: 'CRITICAL',
    advisory: {
      en: '5 farmers within 3.1km recorded pheromone trap catches >12 moths — Deploy Phero-sensor traps and inspect rosette flowers.',
      hi: '3.1 किमी में 5 किसानों के फेरोमोन ट्रैप में 12+ पतंगे मिले — कामगंध जाल लगाएं और गुलाब फूल अवस्था जांचें।',
      mr: '३.१ किमी मध्ये ५ शेतकऱ्यांच्या कामगंध सापळ्यात १२+ पतंग अडकले — डोमकळ्या तपासून ताबडतोब नष्ट करा.',
    },
  },
  {
    id: 'REP-005',
    timestampMinutesAgo: 160,
    farmerCount: 2,
    distanceKm: 1.8,
    villageName: 'Umbraj (उंब्रज)',
    taluka: 'Karad',
    district: 'Satara',
    crop: 'Soybean',
    diseaseName: {
      en: 'Soybean Rust (Phakopsora pachyrhizi)',
      hi: 'सोयाबीन गेरुई / रस्ट रोग',
      mr: 'सोयाबीनवरील तांबेरा रोग',
    },
    severity: 'MODERATE',
    advisory: {
      en: '2 farmers within 1.8km noted early yellow speckling on lower leaf surfaces — Inspect underside for brown pustules.',
      hi: '1.8 किमी में 2 किसानों ने निचली पत्तियों पर पीलापन देखा — पत्तियों की निचली सतह पर भूरे दाने जांचें।',
      mr: '१.८ किमी मध्ये २ शेतकऱ्यांनी पानांच्या खालच्या बाजूला तांबूस दाणे पाहिले — तांबेरा प्रतिबंधासाठी त्वरित निरीक्षण करा.',
    },
  },
  {
    id: 'REP-006',
    timestampMinutesAgo: 210,
    farmerCount: 7,
    distanceKm: 5.5,
    villageName: 'Ambad (अंबड)',
    taluka: 'Ambad',
    district: 'Jalna',
    crop: 'Bt Cotton',
    diseaseName: {
      en: 'Cotton Bacterial Blight',
      hi: 'कपास का जीवाणुज झुलसा',
      mr: 'कापसावरील जिवाणू करपा',
    },
    severity: 'HIGH',
    advisory: {
      en: '7 farmers within 5.5km reported water-soaked angular leaf spots — Spray Copper Oxychloride (2.5 g/L) before rain.',
      hi: '5.5 किमी में 7 किसानों ने कोणीय धब्बे दर्ज किए — बारिश से पहले कॉपर ऑक्सीक्लोराइड का छिड़काव करें।',
      mr: '५.५ किमी परिसरात ७ शेतकऱ्यांनी पानांवर त्रिकोणी करपा ठिपके नोंदवले — पावसापूर्वी कॉपर ऑक्सिक्लोराईड फवारावे.',
    },
  },
];

// ============================================================================
// PROPS AND COMPONENT DEFINITION
// ============================================================================

export interface CommunityOutbreakMapProps {
  initialLanguage?: SupportedLanguage;
  onClusterSelect?: (cluster: VillageOutbreakCluster) => void;
  className?: string;
}

export function CommunityOutbreakMap({
  initialLanguage = 'en',
  onClusterSelect,
  className = '',
}: CommunityOutbreakMapProps) {
  // Multilingual state
  const [language, setLanguage] = useState<SupportedLanguage>(initialLanguage);

  // Clusters and selection
  const [clusters] = useState<VillageOutbreakCluster[]>(ALL_MAHARASHTRA_CLUSTERS);
  const [selectedClusterId, setSelectedClusterId] = useState<string>(
    ALL_MAHARASHTRA_CLUSTERS[0].clusterId
  );
  const activeCluster = useMemo(
    () => clusters.find((c) => c.clusterId === selectedClusterId) || clusters[0],
    [clusters, selectedClusterId]
  );

  // Filters
  const [cropFilter, setCropFilter] = useState<string>('ALL');
  const [severityFilter, setSeverityFilter] = useState<'ALL' | 'CRITICAL_HIGH' | 'MODERATE' | 'SAFE'>('ALL');

  // Radar sweep animation toggle
  const [isRadarSweepActive, setIsRadarSweepActive] = useState<boolean>(true);

  // Live Ticker state
  const [reports, setReports] = useState<OutbreakReport[]>(INITIAL_ANONYMOUS_REPORTS);
  const [activeReportIndex, setActiveReportIndex] = useState<number>(0);
  const [isTickerPaused, setIsTickerPaused] = useState<boolean>(false);

  // Anonymous reporting modal state
  const [isReportingModalOpen, setIsReportingModalOpen] = useState<boolean>(false);
  const [newReportCrop, setNewReportCrop] = useState<string>('Tomato');
  const [newReportSymptom, setNewReportSymptom] = useState<string>('Concentric brown target rings on lower leaves');
  const [newReportTaluka, setNewReportTaluka] = useState<string>('Dindori');
  const [newReportSeverity, setNewReportSeverity] = useState<RiskLevel>('HIGH');
  const [reportSuccessMessage, setReportSuccessMessage] = useState<string | null>(null);

  // Notify parent if callback provided
  useEffect(() => {
    onClusterSelect?.(activeCluster);
  }, [activeCluster, onClusterSelect]);

  // Auto-advance live ticker every 5 seconds (if not paused)
  useEffect(() => {
    if (isTickerPaused || reports.length <= 1) return;

    const timer = setInterval(() => {
      setActiveReportIndex((prev) => (prev + 1) % reports.length);
    }, 5000);

    return () => clearInterval(timer);
  }, [isTickerPaused, reports.length]);

  // ==========================================================================
  // GEOSPATIAL PROJECTION TO SVG (MAHARASHTRA BOUNDS)
  // Latitude: 15.8° N (South Konkan) to 22.1° N (North Khandesh/Vidarbha)
  // Longitude: 72.6° E (Mumbai Coast) to 80.9° E (Gondia/Gadchiroli border)
  // SVG Canvas: 800 x 540 viewBox
  // ==========================================================================
  const mapWidth = 800;
  const mapHeight = 540;
  const minLng = 72.5;
  const maxLng = 81.0;
  const minLat = 15.6;
  const maxLat = 22.2;

  const projectToSvg = (lat: number, lng: number) => {
    // Equirectangular projection
    const x = ((lng - minLng) / (maxLng - minLng)) * (mapWidth - 100) + 50;
    const y = ((maxLat - lat) / (maxLat - minLat)) * (mapHeight - 80) + 40;
    return { x: Math.round(x * 10) / 10, y: Math.round(y * 10) / 10 };
  };

  // Filter clusters based on crop & severity
  const filteredClusters = useMemo(() => {
    return clusters.filter((c) => {
      // Crop filter
      if (cropFilter !== 'ALL') {
        const matchesCrop = c.primaryCrop.toLowerCase().includes(cropFilter.toLowerCase());
        if (!matchesCrop) return false;
      }

      // Severity filter
      const score = c.weatherRisk.outbreakRiskScore;
      if (severityFilter === 'CRITICAL_HIGH') {
        return score >= 70;
      }
      if (severityFilter === 'MODERATE') {
        return score >= 50 && score < 70;
      }
      if (severityFilter === 'SAFE') {
        return score < 50;
      }
      return true;
    });
  }, [clusters, cropFilter, severityFilter]);

  // Color helper based on risk score
  const getClusterColor = (score: number) => {
    if (score >= 70) {
      // High Alert / Critical -> Pulsing Crimson
      return {
        fill: '#ef4444',
        stroke: '#f87171',
        pulseClass: 'text-rose-500',
        badgeClass: 'bg-rose-500/20 text-rose-300 border-rose-500/40',
        tag: 'HIGH ALERT',
        hex: '#ef4444',
      };
    } else if (score >= 50) {
      // Moderate Alert -> Amber
      return {
        fill: '#f59e0b',
        stroke: '#fbbf24',
        pulseClass: 'text-amber-500',
        badgeClass: 'bg-amber-500/20 text-amber-300 border-amber-500/40',
        tag: 'MODERATE',
        hex: '#f59e0b',
      };
    } else {
      // Safe / Controlled -> Emerald
      return {
        fill: '#10b981',
        stroke: '#34d399',
        pulseClass: 'text-emerald-500',
        badgeClass: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40',
        tag: 'SAFE',
        hex: '#10b981',
      };
    }
  };

  // Handle Anonymous Report Submission
  const handleAnonymousSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    const newReport: OutbreakReport = {
      id: `REP-${Date.now().toString().slice(-4)}`,
      timestampMinutesAgo: 1,
      farmerCount: 1,
      distanceKm: +(Math.random() * 3 + 1).toFixed(1),
      villageName: `${newReportTaluka} Grid`,
      taluka: newReportTaluka,
      district: 'Maharashtra',
      crop: newReportCrop,
      diseaseName: {
        en: `${newReportCrop} Alert: ${newReportSymptom.slice(0, 24)}...`,
        hi: `${newReportCrop} लक्षण चेतावनी`,
        mr: `${newReportCrop} लक्षण नोंदणी`,
      },
      severity: newReportSeverity,
      advisory: {
        en: `1 farmer near ${newReportTaluka} logged ${newReportCrop} symptoms (${newReportSymptom.slice(0, 30)}...) — Community surveillance alert dispatched.`,
        hi: `${newReportTaluka} के पास 1 किसान ने लक्षण दर्ज किए — सामुदायिक निगरानी अलर्ट जारी।`,
        mr: `${newReportTaluka} परिसरातील एका शेतकऱ्याने लक्षणे नोंदवली — सामूहिक खबरदारीचा इशारा.`,
      },
    };

    setReports([newReport, ...reports]);
    setActiveReportIndex(0);
    setReportSuccessMessage('Observation successfully submitted anonymously to community surveillance!');

    setTimeout(() => {
      setIsReportingModalOpen(false);
      setReportSuccessMessage(null);
    }, 2000);
  };

  const currentReport = reports[activeReportIndex] || reports[0];
  const activeClusterColor = getClusterColor(activeCluster.weatherRisk.outbreakRiskScore);

  return (
    <div
      className={`rounded-2xl border border-emerald-500/25 bg-gradient-to-b from-stone-900 via-stone-900/95 to-stone-950 p-4 md:p-6 text-stone-100 shadow-2xl backdrop-blur-xl ${className}`}
    >
      {/* ==================================================================== */}
      {/* HEADER: TITLE, BADGES, AND CONTROLS                                  */}
      {/* ==================================================================== */}
      <div className="flex flex-col gap-4 border-b border-stone-800 pb-5 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <div className="flex items-center gap-2">
            <span className="relative flex h-3 w-3">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-rose-400 opacity-75" />
              <span className="relative inline-flex h-3 w-3 rounded-full bg-rose-500" />
            </span>
            <h2 className="text-xl font-bold tracking-tight text-white md:text-2xl">
              {language === 'mr'
                ? 'सामूहिक रोग प्रादुर्भाव नकाशा'
                : language === 'hi'
                ? 'सामुदायिक रोग प्रकोप हीटमैप'
                : 'Anonymous Community Disease Heatmap'}
            </h2>
            <span className="rounded-full border border-purple-500/30 bg-purple-950/60 px-2.5 py-0.5 text-xs font-semibold text-purple-300">
              Maharashtra GeoGrid
            </span>
          </div>

          <p className="mt-1 text-xs text-stone-400 md:text-sm">
            {language === 'mr'
              ? 'अनामिक शेतकरी नोंदींवर आधारित महाराष्ट्र कृषी विभाग व गावांचा थेट रोग प्रादुर्भाव'
              : language === 'hi'
              ? 'गुमनाम किसान रिपोर्टों पर आधारित महाराष्ट्र कृषि क्षेत्रों का लाइव रोग प्रकोप मानचित्र'
              : 'Decentralized, privacy-preserving epidemiological surveillance across Maharashtra agricultural clusters'}
          </p>
        </div>

        {/* Action Controls: Language Toggle & Report Outbreak Button */}
        <div className="flex flex-wrap items-center gap-2">
          {/* Language Switcher */}
          <div className="flex items-center rounded-lg border border-stone-700 bg-stone-950/80 p-0.5 text-xs font-medium">
            <button
              type="button"
              onClick={() => setLanguage('en')}
              className={`rounded px-2.5 py-1 transition-all ${
                language === 'en' ? 'bg-emerald-600 text-white font-bold' : 'text-stone-400 hover:text-stone-200'
              }`}
            >
              EN
            </button>
            <button
              type="button"
              onClick={() => setLanguage('hi')}
              className={`rounded px-2.5 py-1 transition-all ${
                language === 'hi' ? 'bg-emerald-600 text-white font-bold' : 'text-stone-400 hover:text-stone-200'
              }`}
            >
              हिन्दी
            </button>
            <button
              type="button"
              onClick={() => setLanguage('mr')}
              className={`rounded px-2.5 py-1 transition-all ${
                language === 'mr' ? 'bg-emerald-600 text-white font-bold' : 'text-stone-400 hover:text-stone-200'
              }`}
            >
              मराठी
            </button>
          </div>

          {/* Report Sighting Button */}
          <button
            type="button"
            onClick={() => setIsReportingModalOpen(true)}
            className="flex items-center gap-1.5 rounded-lg border border-rose-500/40 bg-rose-950/50 px-3 py-1.5 text-xs font-bold text-rose-300 transition-colors hover:bg-rose-900/60"
          >
            <svg className="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span>{language === 'mr' ? 'अनामिक नोंद करा' : language === 'hi' ? 'गुमनाम रिपोर्ट करें' : 'Log Anonymous Report'}</span>
          </button>
        </div>
      </div>

      {/* ==================================================================== */}
      {/* DELIVERABLE 2 REQUIREMENT: LIVE TICKER OF NEARBY ANONYMOUS REPORTS   */}
      {/* ==================================================================== */}
      <div className="mt-4 overflow-hidden rounded-xl border border-stone-800 bg-stone-950/80 p-3 shadow-lg">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-2">
            <span className="flex h-2 w-2 rounded-full bg-rose-400 animate-ping" />
            <span className="text-[11px] font-bold uppercase tracking-wider text-rose-400">
              {language === 'mr' ? 'थेट शेतकरी अलर्ट' : language === 'hi' ? 'लाइव किसान अलर्ट' : 'Live Community Ticker'}
            </span>
            <span className="rounded bg-stone-800 px-1.5 py-0.2 font-mono text-[10px] text-stone-400">
              {activeReportIndex + 1}/{reports.length}
            </span>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => setIsTickerPaused(!isTickerPaused)}
              className="text-stone-400 hover:text-stone-200 text-xs"
              title={isTickerPaused ? 'Resume auto-ticker' : 'Pause auto-ticker'}
            >
              {isTickerPaused ? '▶ Resume' : '⏸ Pause'}
            </button>
            <div className="flex items-center gap-1">
              <button
                type="button"
                onClick={() =>
                  setActiveReportIndex((prev) => (prev - 1 + reports.length) % reports.length)
                }
                className="rounded p-1 text-stone-400 hover:bg-stone-800 hover:text-white"
                title="Previous report"
              >
                ◀
              </button>
              <button
                type="button"
                onClick={() => setActiveReportIndex((prev) => (prev + 1) % reports.length)}
                className="rounded p-1 text-stone-400 hover:bg-stone-800 hover:text-white"
                title="Next report"
              >
                ▶
              </button>
            </div>
          </div>
        </div>

        {/* Current Active Report Banner */}
        <div className="mt-2 flex items-center gap-3 rounded-lg border border-stone-800/80 bg-stone-900/60 p-2.5">
          <div className="hidden sm:flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-rose-950/80 text-rose-400 border border-rose-800/40">
            <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
            </svg>
          </div>
          <div className="flex-1">
            <p className="text-xs font-medium text-stone-200 leading-snug">
              {currentReport.advisory[language]}
            </p>
            <div className="mt-1 flex flex-wrap items-center gap-2 text-[10px] text-stone-400">
              <span className="font-semibold text-emerald-400">✓ Anonymous Peer Observation</span>
              <span>•</span>
              <span>Approx. {currentReport.distanceKm} km from center</span>
              <span>•</span>
              <span className="font-mono">{currentReport.timestampMinutesAgo} mins ago</span>
              <span>•</span>
              <span className="font-medium text-amber-300">{currentReport.crop}</span>
            </div>
          </div>
        </div>
      </div>

      {/* ==================================================================== */}
      {/* FILTER BAR: CROP FILTER & SEVERITY FILTER                            */}
      {/* ==================================================================== */}
      <div className="mt-4 flex flex-wrap items-center justify-between gap-3 border-y border-stone-800 py-3 text-xs">
        {/* Crop Filter */}
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="font-semibold text-stone-400">Crop:</span>
          {['ALL', 'Tomato', 'Grapes', 'Paddy', 'Cotton', 'Soybean', 'Sugarcane'].map((crop) => (
            <button
              key={crop}
              type="button"
              onClick={() => setCropFilter(crop)}
              className={`rounded-lg px-2.5 py-1 transition-all ${
                cropFilter === crop
                  ? 'bg-emerald-600 font-bold text-white shadow-sm'
                  : 'bg-stone-950/60 text-stone-400 hover:bg-stone-800 hover:text-stone-200'
              }`}
            >
              {crop === 'ALL' ? 'All Crops' : crop}
            </button>
          ))}
        </div>

        {/* Severity Filter */}
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="font-semibold text-stone-400">Severity:</span>
          <button
            type="button"
            onClick={() => setSeverityFilter('ALL')}
            className={`rounded-lg px-2 py-1 ${
              severityFilter === 'ALL' ? 'bg-stone-700 text-white font-bold' : 'text-stone-400 hover:text-stone-200'
            }`}
          >
            All
          </button>
          <button
            type="button"
            onClick={() => setSeverityFilter('CRITICAL_HIGH')}
            className={`flex items-center gap-1 rounded-lg px-2 py-1 ${
              severityFilter === 'CRITICAL_HIGH' ? 'bg-rose-950 text-rose-300 border border-rose-500/50 font-bold' : 'text-stone-400 hover:text-rose-400'
            }`}
          >
            <span className="h-2 w-2 rounded-full bg-rose-500" />
            High Alert (Crimson)
          </button>
          <button
            type="button"
            onClick={() => setSeverityFilter('MODERATE')}
            className={`flex items-center gap-1 rounded-lg px-2 py-1 ${
              severityFilter === 'MODERATE' ? 'bg-amber-950 text-amber-300 border border-amber-500/50 font-bold' : 'text-stone-400 hover:text-amber-400'
            }`}
          >
            <span className="h-2 w-2 rounded-full bg-amber-500" />
            Moderate (Amber)
          </button>
          <button
            type="button"
            onClick={() => setSeverityFilter('SAFE')}
            className={`flex items-center gap-1 rounded-lg px-2 py-1 ${
              severityFilter === 'SAFE' ? 'bg-emerald-950 text-emerald-300 border border-emerald-500/50 font-bold' : 'text-stone-400 hover:text-emerald-400'
            }`}
          >
            <span className="h-2 w-2 rounded-full bg-emerald-500" />
            Safe (Emerald)
          </button>
        </div>

        {/* Radar Sweep Toggle */}
        <button
          type="button"
          onClick={() => setIsRadarSweepActive(!isRadarSweepActive)}
          className={`flex items-center gap-1.5 rounded px-2 py-1 text-xs font-semibold ${
            isRadarSweepActive ? 'text-emerald-300 bg-emerald-950/60 border border-emerald-800/50' : 'text-stone-400'
          }`}
        >
          <span>📡 Radar Sweep:</span>
          <span>{isRadarSweepActive ? 'ON' : 'OFF'}</span>
        </button>
      </div>

      {/* ==================================================================== */}
      {/* MAIN SECTION: SVG GEOSPATIAL MAP (LEFT) & CLUSTER INSPECTOR (RIGHT)  */}
      {/* ==================================================================== */}
      <div className="mt-4 grid grid-cols-1 gap-6 lg:grid-cols-12">
        {/* ================================================================== */}
        {/* INTERACTIVE STYLIZED SVG GEOSPATIAL MAP (7 cols)                   */}
        {/* ================================================================== */}
        <div className="relative flex flex-col items-center justify-center overflow-hidden rounded-2xl border border-stone-800 bg-[#070c09] p-2 shadow-2xl lg:col-span-7">
          {/* Map Header Overlay */}
          <div className="absolute left-3 top-3 z-10 flex items-center gap-2 rounded-lg bg-stone-950/80 px-2.5 py-1 text-[11px] font-medium text-stone-300 backdrop-blur-md border border-stone-800">
            <span className="h-2 w-2 rounded-full bg-emerald-400" />
            <span>Maharashtra Agro-Surveillance Grid</span>
          </div>

          <div className="absolute right-3 top-3 z-10 hidden sm:flex items-center gap-3 rounded-lg bg-stone-950/80 px-2.5 py-1 text-[10px] text-stone-400 backdrop-blur-md border border-stone-800">
            <span className="flex items-center gap-1">
              <span className="h-2 w-2 rounded-full bg-rose-500 animate-ping" />
              High Alert
            </span>
            <span className="flex items-center gap-1">
              <span className="h-2 w-2 rounded-full bg-amber-500" />
              Moderate
            </span>
            <span className="flex items-center gap-1">
              <span className="h-2 w-2 rounded-full bg-emerald-500" />
              Controlled
            </span>
          </div>

          {/* SVG Geospatial Canvas */}
          <div className="w-full">
            <svg
              className="h-auto w-full select-none"
              viewBox={`0 0 ${mapWidth} ${mapHeight}`}
              preserveAspectRatio="xMidYMid meet"
            >
              <defs>
                {/* Radar Grid Gradient */}
                <radialGradient id="radarSweepGradient" cx="50%" cy="50%" r="50%">
                  <stop offset="0%" stopColor="#10b981" stopOpacity="0.25" />
                  <stop offset="60%" stopColor="#10b981" stopOpacity="0.08" />
                  <stop offset="100%" stopColor="#10b981" stopOpacity="0" />
                </radialGradient>

                {/* Crimson Pulse Filter */}
                <filter id="glowCrimson" x="-50%" y="-50%" width="200%" height="200%">
                  <feGaussianBlur stdDeviation="4" result="blur" />
                  <feMerge>
                    <feMergeNode in="blur" />
                    <feMergeNode in="SourceGraphic" />
                  </feMerge>
                </filter>
                {/* Amber Pulse Filter */}
                <filter id="glowAmber" x="-50%" y="-50%" width="200%" height="200%">
                  <feGaussianBlur stdDeviation="3.5" result="blur" />
                  <feMerge>
                    <feMergeNode in="blur" />
                    <feMergeNode in="SourceGraphic" />
                  </feMerge>
                </filter>
              </defs>

              {/* Background Coordinate Grid */}
              <g stroke="#1c2b21" strokeWidth="0.8" strokeDasharray="3 3">
                {/* Longitude lines */}
                <line x1="120" y1="20" x2="120" y2="520" />
                <line x1="240" y1="20" x2="240" y2="520" />
                <line x1="360" y1="20" x2="360" y2="520" />
                <line x1="480" y1="20" x2="480" y2="520" />
                <line x1="600" y1="20" x2="600" y2="520" />
                <line x1="720" y1="20" x2="720" y2="520" />
                {/* Latitude lines */}
                <line x1="30" y1="100" x2="770" y2="100" />
                <line x1="30" y1="200" x2="770" y2="200" />
                <line x1="30" y1="300" x2="770" y2="300" />
                <line x1="30" y1="400" x2="770" y2="400" />
                <line x1="30" y1="500" x2="770" y2="500" />
              </g>

              {/* Stylized Maharashtra Agricultural Boundary Contour */}
              <path
                d="M 120,110 
                   C 180,95 280,105 380,85 
                   C 460,70 540,65 650,85 
                   C 720,100 770,160 760,240 
                   C 750,310 710,380 660,400 
                   C 580,430 520,380 460,420 
                   C 400,460 340,510 260,500 
                   C 210,490 190,420 180,350 
                   C 170,280 150,260 140,220 
                   C 130,170 100,140 120,110 Z"
                fill="#0d1b11"
                stroke="#1e3a24"
                strokeWidth="2.5"
                strokeDasharray="none"
              />

              {/* Agro-Climatic Zone Divisions (Subtle outlines) */}
              {/* Konkan Coastal Strip */}
              <path
                d="M 120,110 C 135,160 145,230 160,320 C 175,410 190,460 210,490"
                fill="none"
                stroke="#15803d"
                strokeWidth="1.2"
                strokeDasharray="4 4"
                opacity="0.5"
              />
              <text x="145" y="440" fill="#34d399" fontSize="9" opacity="0.6" transform="rotate(-75 145,440)">
                Konkan Coast
              </text>

              {/* Western Ghats / Desh Transition */}
              <text x="230" y="270" fill="#a7f3d0" fontSize="10" fontWeight="bold" opacity="0.4">
                Desh / Western MH
              </text>
              <text x="290" y="115" fill="#a7f3d0" fontSize="10" fontWeight="bold" opacity="0.4">
                Khandesh (North)
              </text>
              <text x="420" y="260" fill="#a7f3d0" fontSize="10" fontWeight="bold" opacity="0.4">
                Marathwada
              </text>
              <text x="630" y="180" fill="#a7f3d0" fontSize="10" fontWeight="bold" opacity="0.4">
                Vidarbha Cotton Belt
              </text>

              {/* Arabian Sea Watermark */}
              <text x="60" y="320" fill="#065f46" fontSize="12" fontWeight="bold" opacity="0.5" transform="rotate(-90 60,320)">
                ARABIAN SEA
              </text>

              {/* Radar Sweep Animated Beam (If active) */}
              {isRadarSweepActive && (
                <g className="origin-center animate-[spin_8s_linear_infinite]" style={{ transformOrigin: '380px 260px' }}>
                  <circle cx="380" cy="260" r="240" fill="url(#radarSweepGradient)" />
                  <line x1="380" y1="260" x2="620" y2="260" stroke="#34d399" strokeWidth="1.5" strokeOpacity="0.6" />
                </g>
              )}

              {/* RENDER CLUSTER NODES */}
              {filteredClusters.map((cluster) => {
                const { x, y } = projectToSvg(cluster.coordinates.lat, cluster.coordinates.lng);
                const isSelected = cluster.clusterId === selectedClusterId;
                const score = cluster.weatherRisk.outbreakRiskScore;
                const nodeColors = getClusterColor(score);
                const isHighAlert = score >= 70;
                const isModerate = score >= 50 && score < 70;

                return (
                  <g
                    key={cluster.clusterId}
                    className="cursor-pointer transition-transform duration-200 hover:scale-110"
                    onClick={() => setSelectedClusterId(cluster.clusterId)}
                  >
                    {/* Pulsing Ripple Rings for High Alert (Crimson) and Moderate (Amber) */}
                    {isHighAlert && (
                      <circle
                        cx={x}
                        cy={y}
                        r="22"
                        fill="none"
                        stroke="#f43f5e"
                        strokeWidth="1.5"
                        opacity="0.75"
                        className="animate-ping"
                        style={{ transformOrigin: `${x}px ${y}px`, animationDuration: '2.4s' }}
                      />
                    )}
                    {isModerate && (
                      <circle
                        cx={x}
                        cy={y}
                        r="18"
                        fill="none"
                        stroke="#f59e0b"
                        strokeWidth="1.2"
                        opacity="0.6"
                        className="animate-ping"
                        style={{ transformOrigin: `${x}px ${y}px`, animationDuration: '3.2s' }}
                      />
                    )}

                    {/* Secondary buffer radius indicator */}
                    <circle
                      cx={x}
                      cy={y}
                      r={isSelected ? '26' : '15'}
                      fill={nodeColors.fill}
                      fillOpacity={isSelected ? '0.25' : '0.15'}
                      stroke={nodeColors.stroke}
                      strokeWidth={isSelected ? '2' : '1'}
                      strokeDasharray={isSelected ? '3 3' : 'none'}
                    />

                    {/* Core Solid Node */}
                    <circle
                      cx={x}
                      cy={y}
                      r={isSelected ? '9' : '6.5'}
                      fill={nodeColors.fill}
                      stroke="#ffffff"
                      strokeWidth={isSelected ? '2.5' : '1.5'}
                      filter={isHighAlert ? 'url(#glowCrimson)' : isModerate ? 'url(#glowAmber)' : undefined}
                    />

                    {/* Target Reticle if selected */}
                    {isSelected && (
                      <g stroke="#ffffff" strokeWidth="1.5">
                        <line x1={x - 14} y1={y} x2={x - 10} y2={y} />
                        <line x1={x + 10} y1={y} x2={x + 14} y2={y} />
                        <line x1={x} y1={y - 14} x2={x} y2={y - 10} />
                        <line x1={x} y1={y + 10} x2={x} y2={y + 14} />
                      </g>
                    )}

                    {/* Village Name Label */}
                    <text
                      x={x}
                      y={y + 20}
                      textAnchor="middle"
                      fill={isSelected ? '#ffffff' : '#d6d3d1'}
                      fontSize={isSelected ? '11' : '9.5'}
                      fontWeight={isSelected ? 'bold' : 'normal'}
                      className="drop-shadow-[0_1px_3px_rgba(0,0,0,0.9)]"
                    >
                      {cluster.village.split(' ')[0]}
                    </text>

                    {/* Risk Badge on hover/selected */}
                    {isSelected && (
                      <g>
                        <rect
                          x={x - 24}
                          y={y - 28}
                          width="48"
                          height="16"
                          rx="4"
                          fill="#09090b"
                          stroke={nodeColors.stroke}
                          strokeWidth="1"
                        />
                        <text
                          x={x}
                          y={y - 16}
                          textAnchor="middle"
                          fill={nodeColors.fill}
                          fontSize="9.5"
                          fontWeight="bold"
                          fontFamily="monospace"
                        >
                          {score}%
                        </text>
                      </g>
                    )}
                  </g>
                );
              })}
            </svg>
          </div>

          {/* Map Footer Help */}
          <div className="mt-2 flex w-full items-center justify-between border-t border-stone-800 px-3 py-1.5 text-[11px] text-stone-400">
            <span>Click any node to inspect village agronomic breakdown</span>
            <span className="font-mono text-emerald-400">
              Showing {filteredClusters.length} of {clusters.length} clusters
            </span>
          </div>
        </div>

        {/* ================================================================== */}
        {/* DELIVERABLE 2 REQUIREMENT: CLUSTER INSPECTOR (DOMINANT THREATS,    */}
        {/* CASE COUNTS, AND COMMUNITY INTERVENTIONS) (5 cols)                */}
        {/* ================================================================== */}
        <div className="flex flex-col gap-4 rounded-2xl border border-stone-800 bg-stone-950/70 p-5 lg:col-span-5">
          {/* Top Cluster Header */}
          <div className="flex items-start justify-between border-b border-stone-800 pb-3">
            <div>
              <div className="flex items-center gap-2">
                <span className={`h-2.5 w-2.5 rounded-full ${activeClusterColor.hex === '#ef4444' ? 'bg-rose-500 animate-ping' : 'bg-emerald-500'}`} />
                <h3 className="text-base font-extrabold text-white">
                  {activeCluster.village}
                </h3>
              </div>
              <p className="mt-0.5 text-xs text-stone-400">
                Taluka: <span className="font-semibold text-stone-200">{activeCluster.taluka}</span> | District: <span className="font-semibold text-stone-200">{activeCluster.district}</span>
              </p>
            </div>

            {/* Outbreak Status Badge */}
            <div className="flex flex-col items-end">
              <span className={`rounded-full px-2.5 py-0.5 text-xs font-bold ${activeClusterColor.badgeClass}`}>
                {activeClusterColor.tag}
              </span>
              <span className="mt-1 font-mono text-xs text-stone-400">
                Index: <span className="font-bold text-white">{activeCluster.weatherRisk.outbreakRiskScore}%</span>
              </span>
            </div>
          </div>

          {/* Village Case Counts & Impact Metrics */}
          <div className="grid grid-cols-2 gap-2 text-xs">
            <div className="rounded-xl border border-stone-800 bg-stone-900/60 p-3">
              <span className="text-[11px] font-semibold text-stone-400">
                {language === 'mr' ? 'बाधित क्षेत्र' : language === 'hi' ? 'प्रभावित क्षेत्र' : 'Affected Acreage'}
              </span>
              <div className="mt-1 flex items-baseline gap-1">
                <span className="font-mono text-xl font-black text-white">{activeCluster.affectedHectares}</span>
                <span className="text-xs text-stone-400">hectares</span>
              </div>
            </div>

            <div className="rounded-xl border border-stone-800 bg-stone-900/60 p-3">
              <span className="text-[11px] font-semibold text-stone-400">
                {language === 'mr' ? 'सक्रिय शेतकरी इशारे' : language === 'hi' ? 'सक्रिय किसान अलर्ट' : 'Active Farmer Alerts'}
              </span>
              <div className="mt-1 flex items-baseline gap-1">
                <span className="font-mono text-xl font-black text-rose-400">{activeCluster.activeFarmerAlerts}</span>
                <span className="text-xs text-stone-400">reports</span>
              </div>
            </div>
          </div>

          {/* Primary Crops in Cluster */}
          <div className="rounded-xl border border-stone-800 bg-stone-900/40 p-3 text-xs">
            <span className="font-semibold text-stone-400">
              {language === 'mr' ? 'प्रमुख पिके:' : language === 'hi' ? 'प्रमुख फसलें:' : 'Dominant Crops in Zone:'}
            </span>
            <p className="mt-1 font-medium text-emerald-300">
              {activeCluster.primaryCrop}
            </p>
          </div>

          {/* Microclimate Snapshot */}
          <div className="flex items-center justify-between rounded-xl border border-stone-800 bg-stone-900/60 px-3 py-2 text-xs">
            <div className="flex items-center gap-1.5">
              <span className="text-amber-400">🌡️</span>
              <span className="font-mono text-stone-200">{activeCluster.weatherRisk.tempC}°C</span>
            </div>
            <div className="flex items-center gap-1.5">
              <span className="text-cyan-400">💧</span>
              <span className={`font-mono ${activeCluster.weatherRisk.humidity >= 80 ? 'text-rose-400 font-bold' : 'text-stone-200'}`}>
                {activeCluster.weatherRisk.humidity}% RH
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <span className="text-blue-400">🌧️</span>
              <span className="font-mono text-stone-200">{activeCluster.weatherRisk.rainfallMm} mm</span>
            </div>
          </div>

          {/* Dominant Crop Threats Breakdown */}
          <div className="space-y-2">
            <span className="text-xs font-bold uppercase tracking-wider text-stone-400">
              {language === 'mr'
                ? 'या गावातील मुख्य रोग व कारणे'
                : language === 'hi'
                ? 'इस गाँव में मुख्य रोग एवं प्रकोप कारण'
                : 'Identified Pathogen Threats & Etiology:'}
            </span>

            {activeCluster.weatherRisk.predictedThreats.map((threat, tIdx) => {
              const tColor = threat.riskLevel === 'CRITICAL' ? 'border-rose-500/40 bg-rose-950/30' : threat.riskLevel === 'HIGH' ? 'border-amber-500/40 bg-amber-950/30' : 'border-stone-800 bg-stone-900/40';

              return (
                <div key={tIdx} className={`rounded-xl border p-3 text-xs ${tColor}`}>
                  <div className="flex items-center justify-between">
                    <span className="font-bold text-white">
                      {threat.diseaseName[language]}
                    </span>
                    <span
                      className={`rounded px-1.5 py-0.2 text-[10px] font-bold ${
                        threat.riskLevel === 'CRITICAL'
                          ? 'bg-rose-500/20 text-rose-300'
                          : threat.riskLevel === 'HIGH'
                          ? 'bg-amber-500/20 text-amber-300'
                          : 'bg-emerald-500/20 text-emerald-300'
                      }`}
                    >
                      {threat.riskLevel}
                    </span>
                  </div>
                  <p className="mt-1.5 text-stone-300 leading-relaxed">
                    {threat.reason[language]}
                  </p>
                </div>
              );
            })}
          </div>

          {/* Immediate Community Quarantine & Buffer Action */}
          <div className="rounded-xl border border-emerald-500/30 bg-emerald-950/20 p-3 text-xs">
            <span className="flex items-center gap-1.5 font-bold text-emerald-300">
              <svg className="h-4 w-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              {language === 'mr' ? 'गावासाठी सामुहिक सल्ला' : language === 'hi' ? 'गाँव के लिए सामूहिक सलाह' : 'Community Buffer Action:'}
            </span>
            <p className="mt-1 text-stone-300">
              {activeCluster.weatherRisk.outbreakRiskScore >= 70
                ? 'High conidial pressure. Farmers within 5km radius should suspend overhead irrigation and apply prophylactic bio-fungicide within 24 hours.'
                : 'Surveillance within normal limits. Maintain regular scouting of field perimeters and report unusual foliar lesions.'}
            </p>
          </div>
        </div>
      </div>

      {/* ==================================================================== */}
      {/* ANONYMOUS REPORT SUBMISSION MODAL DIALOG                             */}
      {/* ==================================================================== */}
      {isReportingModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 backdrop-blur-sm">
          <div className="w-full max-w-lg rounded-2xl border border-stone-700 bg-stone-900 p-6 text-stone-100 shadow-2xl">
            <div className="flex items-center justify-between border-b border-stone-800 pb-3">
              <div className="flex items-center gap-2">
                <span className="flex h-3 w-3 rounded-full bg-rose-500" />
                <h3 className="text-lg font-bold text-white">
                  {language === 'mr' ? 'अनामिक शेतकरी रोग नोंद' : language === 'hi' ? 'गुमनाम किसान रोग रिपोर्ट' : 'Submit Anonymous Outbreak Report'}
                </h3>
              </div>
              <button
                type="button"
                onClick={() => setIsReportingModalOpen(false)}
                className="text-stone-400 hover:text-white"
              >
                ✕
              </button>
            </div>

            {reportSuccessMessage ? (
              <div className="my-6 rounded-xl border border-emerald-500/40 bg-emerald-950/40 p-4 text-center">
                <span className="text-2xl">✅</span>
                <p className="mt-2 text-sm font-bold text-emerald-300">{reportSuccessMessage}</p>
                <p className="mt-1 text-xs text-stone-400">Updating community map in real time...</p>
              </div>
            ) : (
              <form onSubmit={handleAnonymousSubmit} className="mt-4 space-y-4">
                <p className="text-xs text-stone-400">
                  Your report will help alert neighboring farmers within 5-10km without exposing your phone, name, or exact farm coordinates.
                </p>

                {/* Field 1: Crop */}
                <div>
                  <label className="text-xs font-semibold text-stone-300">Target Crop:</label>
                  <select
                    value={newReportCrop}
                    onChange={(e) => setNewReportCrop(e.target.value)}
                    className="mt-1 w-full rounded-lg border border-stone-700 bg-stone-950 p-2.5 text-xs text-white focus:border-emerald-500 focus:outline-none"
                  >
                    <option value="Tomato">Tomato (टोमॅटो)</option>
                    <option value="Table Grapes">Table Grapes (द्राक्ष)</option>
                    <option value="Lowland Paddy">Paddy / Rice (भात)</option>
                    <option value="Bt Cotton">Bt Cotton (कापूस)</option>
                    <option value="Soybean">Soybean (सोयाबीन)</option>
                    <option value="Onion">Onion (कांदा)</option>
                    <option value="Sugarcane">Sugarcane (ऊस)</option>
                    <option value="Pomegranate">Pomegranate (डाळिंब)</option>
                  </select>
                </div>

                {/* Field 2: Taluka / Region */}
                <div>
                  <label className="text-xs font-semibold text-stone-300">Nearest Taluka / Hub:</label>
                  <input
                    type="text"
                    value={newReportTaluka}
                    onChange={(e) => setNewReportTaluka(e.target.value)}
                    placeholder="e.g. Dindori, Junnar, Mangaon, Karad"
                    required
                    className="mt-1 w-full rounded-lg border border-stone-700 bg-stone-950 p-2.5 text-xs text-white focus:border-emerald-500 focus:outline-none"
                  />
                </div>

                {/* Field 3: Observed Symptoms */}
                <div>
                  <label className="text-xs font-semibold text-stone-300">Observed Foliar Symptoms:</label>
                  <textarea
                    rows={3}
                    value={newReportSymptom}
                    onChange={(e) => setNewReportSymptom(e.target.value)}
                    placeholder="Describe symptoms: e.g. concentric brown target spots, yellow halos, leaf curling"
                    required
                    className="mt-1 w-full rounded-lg border border-stone-700 bg-stone-950 p-2.5 text-xs text-white focus:border-emerald-500 focus:outline-none"
                  />
                </div>

                {/* Field 4: Estimated Severity */}
                <div>
                  <label className="text-xs font-semibold text-stone-300">Estimated Field Spread:</label>
                  <div className="mt-1 flex gap-2">
                    {(['MODERATE', 'HIGH', 'CRITICAL'] as RiskLevel[]).map((level) => (
                      <button
                        key={level}
                        type="button"
                        onClick={() => setNewReportSeverity(level)}
                        className={`flex-1 rounded-lg border p-2 text-center text-xs font-bold transition-all ${
                          newReportSeverity === level
                            ? level === 'CRITICAL'
                              ? 'border-rose-500 bg-rose-950 text-rose-300'
                              : level === 'HIGH'
                              ? 'border-amber-500 bg-amber-950 text-amber-300'
                              : 'border-yellow-500 bg-yellow-950 text-yellow-300'
                            : 'border-stone-800 bg-stone-950 text-stone-400'
                        }`}
                      >
                        {level}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Submit button */}
                <div className="flex justify-end gap-2 border-t border-stone-800 pt-3">
                  <button
                    type="button"
                    onClick={() => setIsReportingModalOpen(false)}
                    className="rounded-lg px-4 py-2 text-xs font-semibold text-stone-400 hover:text-white"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="rounded-lg bg-emerald-600 px-5 py-2 text-xs font-bold text-white shadow-lg shadow-emerald-700/40 hover:bg-emerald-500"
                  >
                    Broadcast Anonymous Alert
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

export default CommunityOutbreakMap;
