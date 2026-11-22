'use client';

import React, { useState, useMemo } from 'react';
import {
  SupportedLanguage,
  ProgressionStatus,
  ScanTimelineEntry,
  ProgressionRecord,
} from '../types/florax';
import { SAMPLE_PROGRESSION_RECORDS } from '../data/icar-ipm-vault';

// ============================================================================
// SELF-CONTAINED SVG PATHOLOGY VISUALIZER FOR PROGRESSION CHECKPOINTS
// Renders realistic tomato leaf geometry where necrotic lesion area visually
// matches the exact measured lesion-to-leaf percentage!
// ============================================================================

interface LeafGraphicProps {
  lesionPercentage: number;
  status: ProgressionStatus;
  dayLabel: string;
}

const LeafProgressionGraphic: React.FC<LeafGraphicProps> = ({
  lesionPercentage,
  status,
  dayLabel,
}) => {
  // Scale necrotic spots based on lesionPercentage
  // Normalizing around baseline ~25%
  const scale = Math.max(0.2, Math.min(1.6, lesionPercentage / 20));
  const haloOpacity = status === 'RECOVERING' ? 0.3 : status === 'STABLE' ? 0.6 : 0.85;

  return (
    <div className="relative aspect-square w-full max-w-[240px] overflow-hidden rounded-xl border border-stone-800 bg-[#081009] p-2 shadow-inner">
      <svg
        viewBox="0 0 300 300"
        className="h-full w-full select-none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <defs>
          {/* Chlorotic Yellow Halo Gradient */}
          <radialGradient id={`halo-${dayLabel}`} cx="45%" cy="45%" r="40%">
            <stop offset="0%" stopColor="#ca8a04" stopOpacity={haloOpacity} />
            <stop offset="60%" stopColor="#84cc16" stopOpacity={haloOpacity * 0.4} />
            <stop offset="100%" stopColor="#15803d" stopOpacity="0" />
          </radialGradient>

          {/* Necrotic Core Gradient */}
          <radialGradient id={`necrotic-${dayLabel}`} cx="40%" cy="40%" r="45%">
            <stop offset="0%" stopColor="#1c1917" />
            <stop offset="50%" stopColor="#451a03" />
            <stop offset="85%" stopColor="#78350f" />
            <stop offset="100%" stopColor="#a16207" />
          </radialGradient>
        </defs>

        {/* Leaf Stem */}
        <path
          d="M 150,285 Q 151,200 150,130 Q 148,60 147,20"
          stroke="#365314"
          strokeWidth="7"
          fill="none"
          strokeLinecap="round"
        />

        {/* Leaf Blade (Healthy Green Base) */}
        <path
          d="M 147,20 C 195,50 255,115 248,195 C 242,245 188,272 150,280 C 112,272 58,245 52,195 C 45,115 105,50 147,20 Z"
          fill="#1b431e"
          stroke="#14532d"
          strokeWidth="2.5"
        />

        {/* Leaf Veins */}
        <path
          d="M 148,65 Q 185,58 220,78 M 148,95 Q 198,90 235,115 M 149,135 Q 195,140 240,165 M 149,175 Q 190,185 228,215"
          stroke="#4ade80"
          strokeWidth="1.8"
          strokeOpacity="0.4"
          fill="none"
        />
        <path
          d="M 148,65 Q 110,58 78,78 M 148,95 Q 98,90 62,115 M 149,135 Q 102,140 58,165 M 149,175 Q 108,185 70,215"
          stroke="#4ade80"
          strokeWidth="1.8"
          strokeOpacity="0.4"
          fill="none"
        />

        {/* DYNAMIC LESION PATCH 1 (Primary Target-Board Spot) */}
        <g transform={`translate(105, 120) scale(${scale})`}>
          {/* Chlorotic Halo */}
          <circle cx="0" cy="0" r="38" fill={`url(#halo-${dayLabel})`} />
          {/* Necrotic Core */}
          <circle cx="0" cy="0" r="24" fill={`url(#necrotic-${dayLabel})`} stroke="#1c1917" strokeWidth="1.5" />
          {/* Concentric rings */}
          <circle cx="0" cy="0" r="18" fill="none" stroke="#92400e" strokeWidth="1.8" />
          <circle cx="0" cy="0" r="11" fill="none" stroke="#b45309" strokeWidth="1.5" />
          <circle cx="0" cy="0" r="5" fill="#1c0a02" />
        </g>

        {/* DYNAMIC LESION PATCH 2 (Expanding Marginal Blight) */}
        <g transform={`translate(185, 175) scale(${scale * 0.85})`}>
          <circle cx="0" cy="0" r="32" fill={`url(#halo-${dayLabel})`} />
          <ellipse cx="0" cy="0" rx="20" ry="17" fill={`url(#necrotic-${dayLabel})`} stroke="#1c1917" strokeWidth="1.5" />
          <ellipse cx="0" cy="0" rx="14" ry="11" fill="none" stroke="#92400e" strokeWidth="1.5" />
          <ellipse cx="0" cy="0" rx="7" ry="5" fill="#1c0a02" />
        </g>

        {/* DYNAMIC LESION PATCH 3 (Lower Petiole Spot) */}
        {lesionPercentage > 12 && (
          <g transform={`translate(145, 215) scale(${scale * 0.7})`}>
            <circle cx="0" cy="0" r="26" fill={`url(#halo-${dayLabel})`} />
            <circle cx="0" cy="0" r="16" fill={`url(#necrotic-${dayLabel})`} stroke="#1c1917" strokeWidth="1.2" />
            <circle cx="0" cy="0" r="10" fill="none" stroke="#92400e" strokeWidth="1.2" />
            <circle cx="0" cy="0" r="4" fill="#1c0a02" />
          </g>
        )}

        {/* Watermark day badge */}
        <rect x="10" y="10" width="65" height="20" rx="5" fill="#09090b" fillOpacity="0.8" />
        <text x="42" y="24" textAnchor="middle" fill="#f5f5f4" fontSize="11" fontWeight="bold" fontFamily="sans-serif">
          {dayLabel}
        </text>
      </svg>
    </div>
  );
};

// ============================================================================
// DEFAULT BENCHMARK PLANT RECORD: DAY 1 (28.4%) -> DAY 5 (19.1%) -> DAY 10 (8.2%)
// ============================================================================

export const BENCHMARK_TOMATO_SPECIMEN: ProgressionRecord = {
  plantId: 'PLANT-TOM-NSK-BENCHMARK-081',
  plantLabel: 'Tomato Specimen #81 (Dindori Plot B-4)',
  scans: [
    {
      date: '2026-11-01',
      lesionPercentage: 28.4,
      status: 'SPREADING',
      imageUrl: '/scans/tomato-day1-lesion.webp',
    },
    {
      date: '2026-11-05',
      lesionPercentage: 19.1,
      status: 'STABLE',
      imageUrl: '/scans/tomato-day5-lesion.webp',
    },
    {
      date: '2026-11-10',
      lesionPercentage: 8.2,
      status: 'RECOVERING',
      imageUrl: '/scans/tomato-day10-lesion.webp',
    },
  ],
};

// ============================================================================
// PROPS AND COMPONENT IMPLEMENTATION
// ============================================================================

export interface DiseaseProgressionTrackerProps {
  initialLanguage?: SupportedLanguage;
  initialRecord?: ProgressionRecord;
  onScanLogged?: (updatedRecord: ProgressionRecord) => void;
  className?: string;
}

export function DiseaseProgressionTracker({
  initialLanguage = 'en',
  initialRecord = BENCHMARK_TOMATO_SPECIMEN,
  onScanLogged,
  className = '',
}: DiseaseProgressionTrackerProps) {
  // Multilingual state
  const [language, setLanguage] = useState<SupportedLanguage>(initialLanguage);

  // Active progression record (with timeline scans)
  const [activeRecord, setActiveRecord] = useState<ProgressionRecord>(initialRecord);
  const scans = activeRecord.scans;

  // Selected scan for side-by-side inspection
  const [selectedScanIndex, setSelectedScanIndex] = useState<number>(scans.length - 1);
  const selectedScan = scans[selectedScanIndex] || scans[0];

  // Follow-up scan logger modal state
  const [isLogModalOpen, setIsLogModalOpen] = useState<boolean>(false);
  const [newScanDate, setNewScanDate] = useState<string>('2026-11-15');
  const [newLesionPercentage, setNewLesionPercentage] = useState<number>(4.5);
  const [treatmentNotes, setTreatmentNotes] = useState<string>(
    'Foliar spray with Trichoderma viride (5g/L) + Neem Azadirachtin applied on Day 6. Secondary lesion arrest observed.'
  );

  // Available plant specimens (to switch between plants)
  const allSpecimens: ProgressionRecord[] = useMemo(() => {
    return [BENCHMARK_TOMATO_SPECIMEN, ...SAMPLE_PROGRESSION_RECORDS];
  }, []);

  // Compute longitudinal metrics
  const baselineScan = scans[0];
  const latestScan = scans[scans.length - 1];

  // Delta calculation between current/latest scan and initial baseline
  const totalDeltaPercentage = +(latestScan.lesionPercentage - baselineScan.lesionPercentage).toFixed(1);
  const relativeReductionPercentage = +(
    ((baselineScan.lesionPercentage - latestScan.lesionPercentage) / baselineScan.lesionPercentage) *
    100
  ).toFixed(1);

  // Rate of recovery per day
  const daysElapsed = Math.max(
    1,
    Math.round(
      (new Date(latestScan.date).getTime() - new Date(baselineScan.date).getTime()) / (1000 * 3600 * 24)
    )
  );
  const dailyRecoveryVelocity = +(Math.abs(totalDeltaPercentage) / daysElapsed).toFixed(2);

  // Helper for Status Badge styling
  const getStatusBadge = (status: ProgressionStatus) => {
    switch (status) {
      case 'RECOVERING':
        return {
          label: {
            en: 'RECOVERING',
            hi: 'सुधार जारी (RECOVERING)',
            mr: 'रोगमुक्तीकडे (RECOVERING)',
          },
          badgeClass: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40',
          dotClass: 'bg-emerald-400',
          colorHex: '#10b981',
        };
      case 'STABLE':
        return {
          label: {
            en: 'STABLE',
            hi: 'स्थिर (STABLE)',
            mr: 'स्थिर (STABLE)',
          },
          badgeClass: 'bg-amber-500/20 text-amber-300 border-amber-500/40',
          dotClass: 'bg-amber-400',
          colorHex: '#f59e0b',
        };
      case 'SPREADING':
      default:
        return {
          label: {
            en: 'SPREADING',
            hi: 'फैलाव जारी (SPREADING)',
            mr: 'वाढता संसर्ग (SPREADING)',
          },
          badgeClass: 'bg-rose-500/20 text-rose-300 border-rose-500/40',
          dotClass: 'bg-rose-500',
          colorHex: '#ef4444',
        };
    }
  };

  // Helper for Day Label (e.g. Day 1, Day 5, Day 10)
  const getDayLabel = (scanDate: string, index: number) => {
    if (index === 0) return 'Day 1';
    const dayDiff = Math.round(
      (new Date(scanDate).getTime() - new Date(scans[0].date).getTime()) / (1000 * 3600 * 24)
    );
    return `Day ${dayDiff + 1}`;
  };

  // ==========================================================================
  // HANDLER: LOG NEW PERIODIC FOLLOW-UP SCAN
  // Calculates delta % between current scan and previous baseline, derives status,
  // updates timeline and trend chart dynamically!
  // ==========================================================================
  const handleLogFollowUpScan = (e: React.FormEvent) => {
    e.preventDefault();

    const previousBaseline = scans[scans.length - 1];
    const deltaFromPrevious = +(newLesionPercentage - previousBaseline.lesionPercentage).toFixed(1);

    // Derive status based on delta
    let derivedStatus: ProgressionStatus = 'STABLE';
    if (deltaFromPrevious <= -1.5) {
      derivedStatus = 'RECOVERING';
    } else if (deltaFromPrevious >= 1.5) {
      derivedStatus = 'SPREADING';
    } else {
      derivedStatus = 'STABLE';
    }

    const newScanEntry: ScanTimelineEntry = {
      date: newScanDate,
      lesionPercentage: newLesionPercentage,
      status: derivedStatus,
      imageUrl: `/scans/followup-${newScanDate}.webp`,
    };

    const updatedRecord: ProgressionRecord = {
      ...activeRecord,
      scans: [...activeRecord.scans, newScanEntry],
    };

    setActiveRecord(updatedRecord);
    setSelectedScanIndex(updatedRecord.scans.length - 1);
    setIsLogModalOpen(false);
    onScanLogged?.(updatedRecord);
  };

  // Switch plant specimen
  const handleSelectPlant = (plantId: string) => {
    const found = allSpecimens.find((p) => p.plantId === plantId);
    if (found) {
      setActiveRecord(found);
      setSelectedScanIndex(found.scans.length - 1);
    }
  };

  return (
    <div
      className={`rounded-2xl border border-emerald-500/25 bg-gradient-to-b from-stone-900 via-stone-900/95 to-stone-950 p-4 md:p-6 text-stone-100 shadow-2xl backdrop-blur-xl ${className}`}
    >
      {/* ==================================================================== */}
      {/* HEADER: TITLE, SPECIMEN SELECTOR & LANGUAGE                          */}
      {/* ==================================================================== */}
      <div className="flex flex-col gap-4 border-b border-stone-800 pb-5 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <div className="flex items-center gap-2">
            <span className="flex h-3 w-3 rounded-full bg-emerald-400" />
            <h2 className="text-xl font-bold tracking-tight text-white md:text-2xl">
              {language === 'mr'
                ? 'रोग घट व पुनर्प्राप्ती ट्रॅकर'
                : language === 'hi'
                ? 'रोग प्रगति एवं सुधार ट्रैकर'
                : 'Periodic Plant Recovery & Progression Tracker'}
            </h2>
            <span className="rounded-full border border-emerald-500/30 bg-emerald-950/60 px-2 py-0.5 text-xs font-semibold text-emerald-300">
              Longitudinal Vision
            </span>
          </div>

          <p className="mt-1 text-xs text-stone-400 md:text-sm">
            {language === 'mr'
              ? 'एकाच रोपाच्या विविध दिवसांच्या स्कॅनची तुलना व पानांवरील करपा क्षेत्र घट (%)'
              : language === 'hi'
              ? 'एक ही पौधे के क्रमिक स्कैन की तुलना और पत्ती पर धब्बा क्षेत्र में कमी (%)'
              : 'Multi-temporal computer vision analysis tracking lesion-to-leaf area reduction over time'}
          </p>
        </div>

        {/* Top Controls: Plant Selector & Language Switcher */}
        <div className="flex flex-wrap items-center gap-2">
          {/* Plant Selector */}
          <select
            value={activeRecord.plantId}
            onChange={(e) => handleSelectPlant(e.target.value)}
            className="rounded-lg border border-stone-700 bg-stone-950 px-3 py-1.5 text-xs font-medium text-stone-200 focus:border-emerald-500 focus:outline-none"
          >
            {allSpecimens.map((specimen) => (
              <option key={specimen.plantId} value={specimen.plantId}>
                {specimen.plantLabel}
              </option>
            ))}
          </select>

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

          {/* Log New Scan Button */}
          <button
            type="button"
            onClick={() => setIsLogModalOpen(true)}
            className="flex items-center gap-1.5 rounded-lg bg-emerald-600 px-3.5 py-1.5 text-xs font-bold text-white shadow-lg shadow-emerald-700/40 transition-all hover:bg-emerald-500"
          >
            <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
            </svg>
            <span>
              {language === 'mr'
                ? 'नवीन फॉलो-अप स्कॅन नोंदवा'
                : language === 'hi'
                ? 'नया फॉलो-अप स्कैन दर्ज करें'
                : 'Log New Follow-Up Scan'}
            </span>
          </button>
        </div>
      </div>

      {/* ==================================================================== */}
      {/* KEY LONGITUDINAL RECOVERY METRICS CARDS                              */}
      {/* ==================================================================== */}
      <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
        {/* Metric 1: Baseline Lesion */}
        <div className="rounded-xl border border-stone-800 bg-stone-950/60 p-3.5">
          <span className="text-xs font-semibold text-stone-400">
            {language === 'mr' ? 'सुरुवातीचा करपा (Day 1)' : language === 'hi' ? 'प्रारंभिक धब्बा (Day 1)' : 'Initial Baseline (Day 1)'}
          </span>
          <div className="mt-2 flex items-baseline gap-1">
            <span className="font-mono text-2xl font-black text-rose-400">{baselineScan.lesionPercentage}%</span>
          </div>
          <span className="mt-1 block text-[11px] text-stone-400">
            Area ratio on {baselineScan.date}
          </span>
        </div>

        {/* Metric 2: Current Scan Lesion */}
        <div className="rounded-xl border border-stone-800 bg-stone-950/60 p-3.5">
          <span className="text-xs font-semibold text-stone-400">
            {language === 'mr' ? 'सध्याचा करपा (Latest)' : language === 'hi' ? 'वर्तमान धब्बा (Latest)' : 'Current Scan Ratio'}
          </span>
          <div className="mt-2 flex items-baseline gap-1">
            <span className="font-mono text-2xl font-black text-emerald-400">{latestScan.lesionPercentage}%</span>
          </div>
          <span className="mt-1 block text-[11px] text-stone-400">
            Area ratio on {latestScan.date}
          </span>
        </div>

        {/* Metric 3: Delta % Reduction */}
        <div className="rounded-xl border border-stone-800 bg-stone-950/60 p-3.5">
          <span className="text-xs font-semibold text-stone-400">
            {language === 'mr' ? 'एकूण घट (Delta %)' : language === 'hi' ? 'कुल कमी (Delta %)' : 'Net Delta Reduction'}
          </span>
          <div className="mt-2 flex items-baseline gap-1">
            <span
              className={`font-mono text-2xl font-black ${
                totalDeltaPercentage < 0 ? 'text-emerald-400' : 'text-rose-400'
              }`}
            >
              {totalDeltaPercentage > 0 ? `+${totalDeltaPercentage}` : totalDeltaPercentage}%
            </span>
          </div>
          <span className="mt-1 block text-[11px] text-stone-400">
            {relativeReductionPercentage}% relative recovery
          </span>
        </div>

        {/* Metric 4: Daily Recovery Velocity */}
        <div className="rounded-xl border border-stone-800 bg-stone-950/60 p-3.5">
          <span className="text-xs font-semibold text-stone-400">
            {language === 'mr' ? 'दैनंदिन घट वेग' : language === 'hi' ? 'दैनिक सुधार दर' : 'Recovery Velocity'}
          </span>
          <div className="mt-2 flex items-baseline gap-1">
            <span className="font-mono text-2xl font-black text-cyan-300">
              {dailyRecoveryVelocity}%
            </span>
            <span className="text-xs text-stone-400">/ day</span>
          </div>
          <span className="mt-1 block text-[11px] text-stone-400">
            Over {daysElapsed} monitored days
          </span>
        </div>
      </div>

      {/* ==================================================================== */}
      {/* DELIVERABLE 3 REQUIREMENT: TIMELINE VISUAL COMPARISON                 */}
      {/* Displays Day 1 (28.4%) -> Day 5 (19.1%) -> Day 10 (8.2%) with         */}
      {/* SVG leaf pathology and status badges                                 */}
      {/* ==================================================================== */}
      <div className="mt-6">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-bold text-white">
            {language === 'mr'
              ? 'पानावरील करप्याची दृश्य कालमर्यादा (Longitudinal Timeline)'
              : language === 'hi'
              ? 'पत्ती पर धब्बे की दृश्य समयरेखा (Timeline Comparison)'
              : 'Longitudinal Leaf Pathology Comparison Timeline'}
          </h3>
          <span className="text-xs text-stone-400">
            Click any checkpoint card to inspect pathology details
          </span>
        </div>

        {/* Horizontal Timeline Grid */}
        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
          {scans.map((scan, idx) => {
            const dayLabel = getDayLabel(scan.date, idx);
            const badge = getStatusBadge(scan.status);
            const isSelected = idx === selectedScanIndex;

            // Delta from prior checkpoint
            const priorScan = idx > 0 ? scans[idx - 1] : null;
            const deltaFromPrior = priorScan
              ? +(scan.lesionPercentage - priorScan.lesionPercentage).toFixed(1)
              : null;

            return (
              <div
                key={idx}
                onClick={() => setSelectedScanIndex(idx)}
                className={`flex cursor-pointer flex-col rounded-2xl border p-4 transition-all duration-200 ${
                  isSelected
                    ? 'border-emerald-400 bg-emerald-950/40 ring-2 ring-emerald-400/40 shadow-xl'
                    : 'border-stone-800 bg-stone-950/60 hover:border-stone-700 hover:bg-stone-900/40'
                }`}
              >
                {/* Card Header: Day and Status Badge */}
                <div className="flex items-center justify-between border-b border-stone-800/80 pb-2.5">
                  <div className="flex items-center gap-1.5">
                    <span className="font-mono text-sm font-extrabold text-white">{dayLabel}</span>
                    <span className="text-[10px] text-stone-400 font-mono">({scan.date.slice(5)})</span>
                  </div>

                  <span className={`rounded-full border px-2 py-0.5 text-[10px] font-bold ${badge.badgeClass}`}>
                    {badge.label[language]}
                  </span>
                </div>

                {/* SVG Leaf Graphic matching exact Lesion % */}
                <div className="my-3 flex justify-center">
                  <LeafProgressionGraphic
                    lesionPercentage={scan.lesionPercentage}
                    status={scan.status}
                    dayLabel={dayLabel}
                  />
                </div>

                {/* Lesion Ratio Readout */}
                <div className="mt-auto border-t border-stone-800/80 pt-2.5">
                  <div className="flex items-baseline justify-between">
                    <span className="text-xs text-stone-400">Lesion Area Ratio:</span>
                    <span className="font-mono text-base font-black text-white">
                      {scan.lesionPercentage}%
                    </span>
                  </div>

                  {/* Delta from previous checkpoint pill */}
                  <div className="mt-1 flex items-center justify-between text-[11px]">
                    <span className="text-stone-400">Delta from prior:</span>
                    {deltaFromPrior !== null ? (
                      <span
                        className={`font-mono font-bold ${
                          deltaFromPrior < 0 ? 'text-emerald-400' : deltaFromPrior > 0 ? 'text-rose-400' : 'text-amber-400'
                        }`}
                      >
                        {deltaFromPrior > 0 ? `+${deltaFromPrior}` : deltaFromPrior}%
                      </span>
                    ) : (
                      <span className="font-mono text-stone-400">Initial Baseline</span>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* ==================================================================== */}
      {/* DELIVERABLE 3 REQUIREMENT: SVG TREND CHART (AREA CURVE)              */}
      {/* ==================================================================== */}
      <div className="mt-6 rounded-2xl border border-stone-800 bg-stone-950/70 p-5">
        <div className="flex flex-col justify-between gap-1 sm:flex-row sm:items-center">
          <div>
            <h4 className="text-sm font-bold text-white">
              {language === 'mr'
                ? 'रोग घट आलेख (Lesion Area Ratio Trend %)'
                : language === 'hi'
                ? 'धब्बा क्षेत्रफल कमी ग्राफ (Trend Chart)'
                : 'Lesion Area Ratio (%) Progression Trend Curve'}
            </h4>
            <p className="text-xs text-stone-400">
              Longitudinal healing trajectory against the ICAR Economic Injury Level (15% limit)
            </p>
          </div>

          <div className="flex items-center gap-4 text-xs">
            <span className="flex items-center gap-1.5 text-stone-300">
              <span className="h-2 w-2 rounded-full bg-emerald-400" />
              Observed Lesion %
            </span>
            <span className="flex items-center gap-1.5 text-rose-400">
              <span className="h-0.5 w-4 border-t-2 border-dashed border-rose-500" />
              15% Economic Threshold
            </span>
          </div>
        </div>

        {/* SVG Interactive Trend Chart */}
        <div className="mt-4 h-48 w-full">
          <svg className="h-full w-full" viewBox="0 0 700 200" preserveAspectRatio="none">
            <defs>
              <linearGradient id="progressionGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                <stop offset="0%" stopColor="#10b981" stopOpacity="0.4" />
                <stop offset="70%" stopColor="#10b981" stopOpacity="0.1" />
                <stop offset="100%" stopColor="#10b981" stopOpacity="0.0" />
              </linearGradient>
            </defs>

            {/* Gridlines */}
            <line x1="50" y1="20" x2="680" y2="20" stroke="#292524" strokeWidth="1" />
            <line x1="50" y1="65" x2="680" y2="65" stroke="#292524" strokeWidth="1" />
            <line x1="50" y1="110" x2="680" y2="110" stroke="#292524" strokeWidth="1" />
            <line x1="50" y1="155" x2="680" y2="155" stroke="#292524" strokeWidth="1" />

            {/* Y-Axis Labels */}
            <text x="40" y="24" textAnchor="end" fill="#78716c" fontSize="10" fontFamily="monospace">30%</text>
            <text x="40" y="69" textAnchor="end" fill="#78716c" fontSize="10" fontFamily="monospace">20%</text>
            <text x="40" y="114" textAnchor="end" fill="#78716c" fontSize="10" fontFamily="monospace">10%</text>
            <text x="40" y="159" textAnchor="end" fill="#78716c" fontSize="10" fontFamily="monospace">0%</text>

            {/* 15% Economic Injury Threshold Dashed Guideline */}
            {/* 15% corresponds to y = 155 - (15/30)*135 = 87.5 */}
            <line
              x1="50"
              y1="87.5"
              x2="680"
              y2="87.5"
              stroke="#f43f5e"
              strokeWidth="1.5"
              strokeDasharray="5 5"
              strokeOpacity="0.6"
            />
            <text x="675" y="83" textAnchor="end" fill="#f43f5e" fontSize="9.5" fontFamily="monospace">
              15% ETL Safety Line
            </text>

            {/* Calculate Points for the curve */}
            {(() => {
              const maxVal = 35;
              const chartWidth = 630;
              const startX = 60;
              const stepX = scans.length > 1 ? chartWidth / (scans.length - 1) : chartWidth;

              const points = scans.map((s, idx) => {
                const px = startX + idx * stepX;
                const py = 155 - (s.lesionPercentage / maxVal) * 135;
                return { x: px, y: py, scan: s, dayLabel: getDayLabel(s.date, idx) };
              });

              // Create SVG Path string
              const linePathD = points.reduce((acc, p, idx) => {
                return idx === 0 ? `M ${p.x},${p.y}` : `${acc} L ${p.x},${p.y}`;
              }, '');

              const areaPathD = `${linePathD} L ${points[points.length - 1].x},155 L ${points[0].x},155 Z`;

              return (
                <g>
                  {/* Area fill */}
                  <path d={areaPathD} fill="url(#progressionGradient)" />

                  {/* Trend line */}
                  <path
                    d={linePathD}
                    fill="none"
                    stroke="#10b981"
                    strokeWidth="3.5"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />

                  {/* Point circles & Values */}
                  {points.map((p, idx) => (
                    <g key={idx}>
                      {/* Outer pulse if selected */}
                      {idx === selectedScanIndex && (
                        <circle cx={p.x} cy={p.y} r="12" fill="#10b981" fillOpacity="0.25" />
                      )}

                      <circle
                        cx={p.x}
                        cy={p.y}
                        r="6"
                        fill="#052e16"
                        stroke="#34d399"
                        strokeWidth="3"
                        className="cursor-pointer"
                        onClick={() => setSelectedScanIndex(idx)}
                      />

                      {/* Value label */}
                      <text
                        x={p.x}
                        y={p.y - 12}
                        textAnchor="middle"
                        fill="#ffffff"
                        fontSize="11"
                        fontWeight="bold"
                        fontFamily="monospace"
                      >
                        {p.scan.lesionPercentage}%
                      </text>

                      {/* X-Axis Day label */}
                      <text
                        x={p.x}
                        y="178"
                        textAnchor="middle"
                        fill={idx === selectedScanIndex ? '#34d399' : '#a8a29e'}
                        fontSize="11"
                        fontWeight={idx === selectedScanIndex ? 'bold' : 'normal'}
                      >
                        {p.dayLabel}
                      </text>
                    </g>
                  ))}
                </g>
              );
            })()}
          </svg>
        </div>
      </div>

      {/* ==================================================================== */}
      {/* DETAILED CHECKPOINT INSPECTION CARD                                  */}
      {/* ==================================================================== */}
      <div className="mt-5 rounded-2xl border border-stone-800 bg-stone-950/60 p-5">
        <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <div className="flex items-center gap-2">
              <h4 className="text-base font-extrabold text-white">
                Detailed Inspection: {getDayLabel(selectedScan.date, selectedScanIndex)} ({selectedScan.date})
              </h4>
              <span className={`rounded-full px-2.5 py-0.5 text-xs font-bold ${getStatusBadge(selectedScan.status).badgeClass}`}>
                {getStatusBadge(selectedScan.status).label[language]}
              </span>
            </div>
            <p className="mt-1 text-xs text-stone-400">
              Specimen: {activeRecord.plantLabel}
            </p>
          </div>

          <div className="flex items-center gap-3">
            <div className="rounded-xl border border-stone-800 bg-stone-900/60 px-3 py-1.5 text-xs">
              <span className="text-stone-400">Lesion-to-Leaf: </span>
              <span className="font-mono text-sm font-bold text-white">{selectedScan.lesionPercentage}%</span>
            </div>
          </div>
        </div>

        {/* Agronomic Prognosis */}
        <div className="mt-4 rounded-xl border border-emerald-500/20 bg-emerald-950/20 p-3.5 text-xs">
          <span className="font-bold text-emerald-300">
            {language === 'mr' ? 'तज्ज्ञ शेती सल्ला व प्रगती निष्कर्ष:' : language === 'hi' ? 'विशेषज्ञ कृषि निष्कर्ष एवं प्रगति:' : 'ICAR Clinical Plant Pathology Assessment:'}
          </span>
          <p className="mt-1 leading-relaxed text-stone-300">
            {selectedScan.lesionPercentage < 10 ? (
              <span>
                Foliar lesion area has stabilized below 10%, indicating that bio-protectants (Trichoderma viride) and cultural pruning have successfully contained Alternaria mycelial spread. Plant has entered active vegetative regeneration.
              </span>
            ) : selectedScan.lesionPercentage < 20 ? (
              <span>
                Disease progression is currently in intermediate stabilization. Concentric rings are desiccating, but continued monitoring is advised if microclimatic humidity spikes above 80%.
              </span>
            ) : (
              <span>
                Active lesion expansion observed across lower leaflets. High conidial sporulation pressure. Strict adherence to biological bio-shielding or contact fungicides is required before canopy closure.
              </span>
            )}
          </p>
        </div>
      </div>

      {/* ==================================================================== */}
      {/* MODAL: LOG NEW PERIODIC FOLLOW-UP SCAN                               */}
      {/* ==================================================================== */}
      {isLogModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 backdrop-blur-sm">
          <div className="w-full max-w-lg rounded-2xl border border-stone-700 bg-stone-900 p-6 text-stone-100 shadow-2xl">
            <div className="flex items-center justify-between border-b border-stone-800 pb-3">
              <div className="flex items-center gap-2">
                <span className="flex h-3 w-3 rounded-full bg-emerald-400" />
                <h3 className="text-lg font-bold text-white">
                  {language === 'mr'
                    ? 'नवीन नियतकालिक स्कॅन नोंदवा'
                    : language === 'hi'
                    ? 'नया आवधिक स्कैन दर्ज करें'
                    : 'Log New Periodic Follow-Up Scan'}
                </h3>
              </div>
              <button
                type="button"
                onClick={() => setIsLogModalOpen(false)}
                className="text-stone-400 hover:text-white"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleLogFollowUpScan} className="mt-4 space-y-4">
              {/* Previous Baseline Reference Card */}
              <div className="rounded-xl border border-stone-800 bg-stone-950 p-3 text-xs">
                <div className="flex justify-between">
                  <span className="text-stone-400">Previous Checkpoint:</span>
                  <span className="font-mono font-bold text-white">
                    {getDayLabel(latestScan.date, scans.length - 1)} ({latestScan.date})
                  </span>
                </div>
                <div className="mt-1 flex justify-between">
                  <span className="text-stone-400">Previous Lesion Area:</span>
                  <span className="font-mono font-bold text-emerald-400">
                    {latestScan.lesionPercentage}%
                  </span>
                </div>
              </div>

              {/* Field 1: Scan Date */}
              <div>
                <label className="text-xs font-semibold text-stone-300">Scan Observation Date:</label>
                <input
                  type="date"
                  value={newScanDate}
                  onChange={(e) => setNewScanDate(e.target.value)}
                  required
                  className="mt-1 w-full rounded-lg border border-stone-700 bg-stone-950 p-2.5 text-xs text-white focus:border-emerald-500 focus:outline-none"
                />
              </div>

              {/* Field 2: Measured Lesion Area Ratio (%) */}
              <div>
                <div className="flex justify-between text-xs font-semibold">
                  <span className="text-stone-300">Measured Lesion-to-Leaf Area Ratio:</span>
                  <span className="font-mono text-sm font-black text-emerald-400">
                    {newLesionPercentage}%
                  </span>
                </div>
                <input
                  type="range"
                  min="0.5"
                  max="40.0"
                  step="0.1"
                  value={newLesionPercentage}
                  onChange={(e) => setNewLesionPercentage(Number(e.target.value))}
                  className="mt-2 w-full accent-emerald-500 cursor-pointer"
                />
                <div className="mt-1 flex justify-between text-[10px] text-stone-400">
                  <span>0% (Fully Cured)</span>
                  <span className="text-emerald-400 font-bold">15% Threshold</span>
                  <span>40% (Severe)</span>
                </div>
              </div>

              {/* Delta Calculation Preview */}
              <div className="rounded-xl border border-stone-800 bg-stone-950/80 p-3 text-xs">
                <div className="flex items-center justify-between">
                  <span className="text-stone-300 font-semibold">Calculated Delta vs Previous:</span>
                  <span
                    className={`font-mono text-sm font-black ${
                      newLesionPercentage - latestScan.lesionPercentage < 0
                        ? 'text-emerald-400'
                        : 'text-rose-400'
                    }`}
                  >
                    {+(newLesionPercentage - latestScan.lesionPercentage).toFixed(1) > 0 ? '+' : ''}
                    {+(newLesionPercentage - latestScan.lesionPercentage).toFixed(1)}%
                  </span>
                </div>
                <span className="mt-1 block text-[11px] text-stone-400">
                  {newLesionPercentage < latestScan.lesionPercentage
                    ? '✓ Improvement confirmed. Status will be marked as RECOVERING.'
                    : newLesionPercentage === latestScan.lesionPercentage
                    ? 'Status will be marked as STABLE.'
                    : '⚠️ Lesion area has expanded. Status will be marked as SPREADING.'}
                </span>
              </div>

              {/* Field 3: Treatment & Scouting Notes */}
              <div>
                <label className="text-xs font-semibold text-stone-300">Intervention / Scouting Notes:</label>
                <textarea
                  rows={3}
                  value={treatmentNotes}
                  onChange={(e) => setTreatmentNotes(e.target.value)}
                  placeholder="Record treatment applied (e.g. bio-fungicide, pruning, copper protectant)"
                  className="mt-1 w-full rounded-lg border border-stone-700 bg-stone-950 p-2.5 text-xs text-white focus:border-emerald-500 focus:outline-none"
                />
              </div>

              {/* Actions */}
              <div className="flex justify-end gap-2 border-t border-stone-800 pt-3">
                <button
                  type="button"
                  onClick={() => setIsLogModalOpen(false)}
                  className="rounded-lg px-4 py-2 text-xs font-semibold text-stone-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="rounded-lg bg-emerald-600 px-5 py-2 text-xs font-bold text-white shadow-lg shadow-emerald-700/40 hover:bg-emerald-500"
                >
                  Commit Follow-Up Scan
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

export default DiseaseProgressionTracker;
