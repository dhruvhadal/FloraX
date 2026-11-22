/**
 * ============================================================================
 * FloraX - Predictive, Diagnostic, and Advisory (PDA) Crop Health Platform
 * Core Domain Interfaces & Type Definitions
 * ============================================================================
 * 
 * Strict typing contracts governing AI inference results, Grad-CAM attention
 * heatmaps, ICAR/KVK Integrated Pest Management (IPM) advisories, weather-driven
 * epidemiological risk modeling, and multi-temporal plant progression tracking.
 */

/**
 * Supported regional languages for localized agronomic advisories:
 * - 'en': English (Standard Agronomic Nomenclature)
 * - 'hi': Hindi (राजभाषा हिन्दी)
 * - 'mr': Marathi (मराठी - Maharashtra Agro-Climatic Zones)
 */
export type SupportedLanguage = 'en' | 'hi' | 'mr';

/**
 * Pathological and physiological classification of crop damage causes.
 */
export type DiseaseCategory = 'FUNGAL' | 'BACTERIAL' | 'VIRAL' | 'NUTRIENT' | 'PEST';

/**
 * Diagnostic candidate identified by computer vision classification heads.
 */
export interface DiseaseCandidate {
  id: string;
  name: Record<SupportedLanguage, string>;
  scientificName: string;
  confidence: number; // Percentage [0.0 - 100.0]
  category: DiseaseCategory;
}

/**
 * Grad-CAM (Gradient-weighted Class Activation Mapping) activation hotspot.
 * Maps spatial attention regions on high-resolution crop imagery for visual explainability.
 * Coordinates (x, y) and radius are expressed in normalized percentages (0 - 100) or pixel space.
 */
export interface GradCamRegion {
  x: number;
  y: number;
  radius: number;
  intensity: number; // Normalized activation weight [0.0 - 1.0]
  label: string;
}

/**
 * Chemical control specification adhering strictly to Central Insecticides Board &
 * Registration Committee (CIBRC) and ICAR/KVK safety protocols.
 */
export interface ChemicalControlPlan {
  /**
   * Safety interlock: When true, chemical recommendations are locked in the UI
   * until Economic Threshold Level (ETL) criteria are met or KVK experts confirm.
   */
  lockedByThreshold: boolean;
  productName: string;
  dosagePerLitre: string;
  waitingPeriodDays: number; // Pre-Harvest Interval (PHI) in days
  ppeWarnings: Record<SupportedLanguage, string[]>;
  etlCriteria: Record<SupportedLanguage, string>;
}

/**
 * Three-tier Integrated Pest Management (IPM) advisory structure:
 * 1. Cultural & Mechanical prevention
 * 2. Biological & Botanical bio-interventions
 * 3. Chemical control (restricted by strict economic thresholds & PPE mandates)
 */
export interface IPMStageTreatment {
  culturalMechanical: Record<SupportedLanguage, string[]>;
  biologicalBotanical: Record<SupportedLanguage, string[]>;
  chemicalControl: ChemicalControlPlan;
}

/**
 * Verification lifecycle states for computer vision inferences.
 * - 'AI_VERIFIED': High confidence (>=75%) validated by automated vision pipeline.
 * - 'PENDING_KVK_REVIEW': Low confidence (<75%) or atypical symptomology requiring Krishi Vigyan Kendra specialist audit.
 * - 'KVK_CONFIRMED': Verified and signed off by an authorized ICAR/KVK agronomist.
 */
export type VerificationStatus = 'AI_VERIFIED' | 'PENDING_KVK_REVIEW' | 'KVK_CONFIRMED';

/**
 * Comprehensive diagnostic assessment payload returned by the FloraX inference engine.
 */
export interface DiagnosticResult {
  scanId: string;
  timestamp: string; // ISO 8601 UTC string
  cropName: string;
  topCandidates: [DiseaseCandidate, DiseaseCandidate, DiseaseCandidate]; // Strict Top 3 tuple
  lesionAreaPercentage: number;
  gradCamRegions: GradCamRegion[];
  requiresExpertVerification: boolean; // Flagged true if top candidate confidence < 75%
  verificationStatus: VerificationStatus;
  ipmAdvisory: IPMStageTreatment;
}

/**
 * Epidemic outbreak severity classification.
 */
export type RiskLevel = 'LOW' | 'MODERATE' | 'HIGH' | 'CRITICAL';

/**
 * Predictive pathogen threat modeled against micro-meteorological variables.
 */
export interface PredictedThreat {
  diseaseName: Record<SupportedLanguage, string>;
  riskLevel: RiskLevel;
  reason: Record<SupportedLanguage, string>;
}

/**
 * Regional micro-climate risk assessment predicting disease outbreak vectors.
 */
export interface WeatherRiskPrediction {
  district: string;
  tempC: number;
  humidity: number; // Relative humidity percentage
  rainfallMm: number; // Precipitation in mm over 24-48 hours
  outbreakRiskScore: number; // Aggregate risk index [0 - 100]
  predictedThreats: PredictedThreat[];
}

/**
 * Progression tracking state between sequential scans of an individual crop plant.
 */
export type ProgressionStatus = 'RECOVERING' | 'STABLE' | 'SPREADING';

/**
 * Individual temporal checkpoint in a plant's disease progression trajectory.
 */
export interface ScanTimelineEntry {
  date: string; // ISO format YYYY-MM-DD
  lesionPercentage: number;
  status: ProgressionStatus;
  imageUrl: string;
}

/**
 * Multi-temporal recovery or decline timeline tracking a tagged crop specimen over time.
 */
export interface ProgressionRecord {
  plantId: string;
  plantLabel: string;
  scans: ScanTimelineEntry[];
}

/**
 * Extended cluster metadata for spatial visualization across Maharashtra districts.
 */
export interface VillageOutbreakCluster {
  clusterId: string;
  village: string;
  taluka: string;
  district: string;
  coordinates: {
    lat: number;
    lng: number;
  };
  primaryCrop: string;
  affectedHectares: number;
  activeFarmerAlerts: number;
  weatherRisk: WeatherRiskPrediction;
}
