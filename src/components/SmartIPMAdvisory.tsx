'use client';

import React, { useState } from 'react';
import {
  DiagnosticResult,
  SupportedLanguage,
  ChemicalControlPlan,
} from '../types/florax';
import { TOMATO_EARLY_BLIGHT_HIGH_CONFIDENCE } from '../data/icar-ipm-vault';

export interface SmartIPMAdvisoryProps {
  diagnosticResult?: DiagnosticResult;
  language?: SupportedLanguage;
  onLanguageChange?: (lang: SupportedLanguage) => void;
  onEscalateToKvk?: (scanId: string) => void;
}

export function SmartIPMAdvisory({
  diagnosticResult = TOMATO_EARLY_BLIGHT_HIGH_CONFIDENCE,
  language: controlledLanguage,
  onLanguageChange,
  onEscalateToKvk,
}: SmartIPMAdvisoryProps) {
  // Multilingual state
  const [internalLanguage, setInternalLanguage] = useState<SupportedLanguage>('en');
  const activeLanguage = controlledLanguage || internalLanguage;

  const handleSetLanguage = (lang: SupportedLanguage) => {
    setInternalLanguage(lang);
    onLanguageChange?.(lang);
  };

  // Interactive 3-Stage Stepper
  const [activeStage, setActiveStage] = useState<1 | 2 | 3>(1);

  // Stage 1 & 2 Farmer Action Checklist state
  const [completedCulturalTasks, setCompletedCulturalTasks] = useState<Record<number, boolean>>({});
  const [completedBiologicalTasks, setCompletedBiologicalTasks] = useState<Record<number, boolean>>({});

  // Stage 3 Safety Gate States
  const [isEtlConfirmed, setIsEtlConfirmed] = useState<boolean>(false);
  const [isKvkEscalated, setIsKvkEscalated] = useState<boolean>(false);
  const [kvkTicketNumber, setKvkTicketNumber] = useState<string | null>(null);
  const [checkedPpeItems, setCheckedPpeItems] = useState<Record<number, boolean>>({});

  const { ipmAdvisory, requiresExpertVerification, verificationStatus, scanId, topCandidates, cropName } =
    diagnosticResult;
  const primaryCandidate = topCandidates[0];
  const chemicalPlan: ChemicalControlPlan = ipmAdvisory.chemicalControl;

  // Cultural and biological items in current language with fallback to English
  const culturalItems =
    ipmAdvisory.culturalMechanical[activeLanguage] || ipmAdvisory.culturalMechanical.en || [];
  const biologicalItems =
    ipmAdvisory.biologicalBotanical[activeLanguage] || ipmAdvisory.biologicalBotanical.en || [];
  const ppeWarnings =
    chemicalPlan.ppeWarnings[activeLanguage] || chemicalPlan.ppeWarnings.en || [];
  const etlText =
    chemicalPlan.etlCriteria[activeLanguage] || chemicalPlan.etlCriteria.en || '';

  // Handle KVK Escalation
  const handleEscalateToKvk = () => {
    const generatedTicket = `KVK-MH-${Math.floor(1000 + Math.random() * 9000)}`;
    setKvkTicketNumber(generatedTicket);
    setIsKvkEscalated(true);
    onEscalateToKvk?.(scanId);
  };

  const toggleCulturalTask = (index: number) => {
    setCompletedCulturalTasks((prev) => ({ ...prev, [index]: !prev[index] }));
  };

  const toggleBiologicalTask = (index: number) => {
    setCompletedBiologicalTasks((prev) => ({ ...prev, [index]: !prev[index] }));
  };

  const togglePpeItem = (index: number) => {
    setCheckedPpeItems((prev) => ({ ...prev, [index]: !prev[index] }));
  };

  return (
    <div className="w-full max-w-6xl mx-auto rounded-3xl bg-slate-950/85 border border-emerald-900/40 backdrop-blur-2xl text-slate-100 shadow-2xl p-4 sm:p-6 lg:p-8 space-y-8 font-sans">
      {/* Top Header & Context Bar */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 pb-6 border-b border-emerald-800/30">
        <div>
          <div className="flex items-center gap-2.5">
            <span className="px-2.5 py-1 rounded-lg bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-xs font-mono font-bold uppercase">
              ICAR-IPM Protocol Vault
            </span>
            <span className="text-xs text-slate-400 font-mono">Scan: {scanId}</span>
          </div>
          <h2 className="text-2xl sm:text-3xl font-black tracking-tight text-white mt-1">
            Smart Treatment Decision System
          </h2>
          <p className="text-xs sm:text-sm text-slate-400 mt-0.5">
            Prescription for{' '}
            <strong className="text-emerald-300">
              {primaryCandidate.name[activeLanguage] || primaryCandidate.name.en}
            </strong>{' '}
            in <span className="text-slate-300">{cropName}</span>
          </p>
        </div>

        {/* Language selector & Verification Badge */}
        <div className="flex flex-wrap items-center gap-3 self-stretch md:self-auto">
          {/* Status Badge */}
          <div
            className={`px-3 py-1.5 rounded-xl border text-xs font-bold flex items-center gap-2 ${
              requiresExpertVerification
                ? 'bg-amber-500/20 text-amber-300 border-amber-500/40'
                : 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40'
            }`}
          >
            <span
              className={`w-2 h-2 rounded-full ${
                requiresExpertVerification ? 'bg-amber-400 animate-ping' : 'bg-emerald-400'
              }`}
            />
            {requiresExpertVerification ? 'KVK Review Escalation Active' : 'AI Verified Safe'}
          </div>

          {/* Language Toggle */}
          <div className="flex items-center bg-slate-900/90 border border-slate-800 rounded-xl p-1 text-xs">
            {(['en', 'hi', 'mr'] as SupportedLanguage[]).map((lang) => (
              <button
                key={lang}
                type="button"
                onClick={() => handleSetLanguage(lang)}
                className={`px-3 py-1.5 rounded-lg font-medium transition-all ${
                  activeLanguage === lang
                    ? 'bg-emerald-500 text-slate-950 font-bold shadow-md'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                {lang === 'en' ? 'EN' : lang === 'hi' ? 'हिंदी' : 'मराठी'}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* 3-Stage Interactive Stepper Navigation */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {/* Stage 1 Button */}
        <button
          type="button"
          onClick={() => setActiveStage(1)}
          className={`p-4 rounded-2xl border text-left transition-all relative overflow-hidden flex flex-col justify-between ${
            activeStage === 1
              ? 'bg-emerald-950/40 border-emerald-500 ring-2 ring-emerald-400/50 shadow-[0_0_20px_rgba(16,185,129,0.25)]'
              : 'bg-slate-900/60 border-slate-800 hover:border-slate-700 hover:bg-slate-900/90'
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-mono font-bold uppercase tracking-wider text-emerald-400">
              Stage 1
            </span>
            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
              Always Unlocked
            </span>
          </div>
          <div className="mt-2">
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              <svg className="w-5 h-5 text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
              Cultural &amp; Mechanical
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Field sanitation, pruning, aeration &amp; physical barriers
            </p>
          </div>
          <div className="mt-3 pt-2 border-t border-slate-800/80 text-[11px] text-emerald-300 font-semibold flex items-center justify-between">
            <span>Non-Chemical First Line</span>
            <span>{Object.values(completedCulturalTasks).filter(Boolean).length}/{culturalItems.length} Done</span>
          </div>
        </button>

        {/* Stage 2 Button */}
        <button
          type="button"
          onClick={() => setActiveStage(2)}
          className={`p-4 rounded-2xl border text-left transition-all relative overflow-hidden flex flex-col justify-between ${
            activeStage === 2
              ? 'bg-cyan-950/40 border-cyan-500 ring-2 ring-cyan-400/50 shadow-[0_0_20px_rgba(6,182,212,0.25)]'
              : 'bg-slate-900/60 border-slate-800 hover:border-slate-700 hover:bg-slate-900/90'
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-mono font-bold uppercase tracking-wider text-cyan-400">
              Stage 2
            </span>
            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-cyan-500/20 text-cyan-300 border border-cyan-500/30">
              Bio-Cyan Tier
            </span>
          </div>
          <div className="mt-2">
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              <svg className="w-5 h-5 text-cyan-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
              </svg>
              Biological &amp; Botanical
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Trichoderma, Pseudomonas &amp; cold-pressed Neem Oil
            </p>
          </div>
          <div className="mt-3 pt-2 border-t border-slate-800/80 text-[11px] text-cyan-300 font-semibold flex items-center justify-between">
            <span>Eco-Friendly Bio-Agents</span>
            <span>{Object.values(completedBiologicalTasks).filter(Boolean).length}/{biologicalItems.length} Done</span>
          </div>
        </button>

        {/* Stage 3 Button */}
        <button
          type="button"
          onClick={() => setActiveStage(3)}
          className={`p-4 rounded-2xl border text-left transition-all relative overflow-hidden flex flex-col justify-between ${
            activeStage === 3
              ? 'bg-rose-950/40 border-rose-500 ring-2 ring-rose-400/50 shadow-[0_0_20px_rgba(244,63,94,0.25)]'
              : 'bg-slate-900/60 border-slate-800 hover:border-slate-700 hover:bg-slate-900/90'
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-mono font-bold uppercase tracking-wider text-rose-400">
              Stage 3
            </span>
            <span
              className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${
                requiresExpertVerification
                  ? 'bg-amber-500/20 text-amber-300 border-amber-500/30'
                  : 'bg-rose-500/20 text-rose-300 border-rose-500/30'
              }`}
            >
              {requiresExpertVerification ? 'Locked by AI Uncertainty' : 'Regulated Last Resort'}
            </span>
          </div>
          <div className="mt-2">
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              <svg className="w-5 h-5 text-rose-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
              </svg>
              Approved Chemical Control
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              CIBRC-approved dosage, PHI intervals &amp; mandatory PPE
            </p>
          </div>
          <div className="mt-3 pt-2 border-t border-slate-800/80 text-[11px] text-rose-300 font-semibold flex items-center justify-between">
            <span>Strict ETL Safety Gate</span>
            <span>{requiresExpertVerification ? '🔒 Locked' : isEtlConfirmed ? '🔓 Unlocked' : '⚠️ ETL Pending'}</span>
          </div>
        </button>
      </div>

      {/* Stage Content Panel */}
      <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-5 sm:p-7 shadow-xl">
        {/* ========================================================================= */}
        {/* STAGE 1: CULTURAL & MECHANICAL CONTROL (Always Unlocked) */}
        {/* ========================================================================= */}
        {activeStage === 1 && (
          <div className="space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 border-b border-emerald-900/30">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center text-emerald-400">
                  <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <div>
                  <h3 className="text-lg font-black text-white">
                    Stage 1: Cultural &amp; Mechanical Control Measures
                  </h3>
                  <p className="text-xs text-slate-400">
                    Mandatory foundational hygiene recommended by ICAR agronomic scientists
                  </p>
                </div>
              </div>
              <span className="self-start sm:self-auto px-3 py-1 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-xs font-bold font-mono">
                100% NON-TOXIC
              </span>
            </div>

            <p className="text-xs sm:text-sm text-slate-300 leading-relaxed">
              Before applying any spray, implement these mechanical and cultural field sanitation
              practices to disrupt fungal sporulation cycles, minimize spore splashing, and reduce
              canopy humidity.
            </p>

            {/* Checklist of Cultural items */}
            <div className="space-y-3">
              {culturalItems.map((item, index) => {
                const isChecked = !!completedCulturalTasks[index];
                return (
                  <label
                    key={`cultural-${index}`}
                    className={`p-4 rounded-2xl border transition-all flex items-start gap-3.5 cursor-pointer ${
                      isChecked
                        ? 'bg-emerald-950/30 border-emerald-500/50 shadow-sm'
                        : 'bg-slate-950/60 border-slate-800 hover:border-slate-700'
                    }`}
                  >
                    <input
                      type="checkbox"
                      checked={isChecked}
                      onChange={() => toggleCulturalTask(index)}
                      className="mt-1 w-4 h-4 rounded text-emerald-500 focus:ring-emerald-400 accent-emerald-500 cursor-pointer flex-shrink-0"
                    />
                    <div className="flex-1 space-y-1">
                      <div className="text-xs sm:text-sm text-white font-medium leading-relaxed">
                        {item}
                      </div>
                      <div className="text-[11px] text-slate-400 flex items-center gap-2">
                        <span className="font-mono text-emerald-400 font-semibold">ICAR Action #{index + 1}</span>
                        {isChecked && (
                          <span className="text-emerald-300 font-bold flex items-center gap-1">
                            ✓ Completed in field
                          </span>
                        )}
                      </div>
                    </div>
                  </label>
                );
              })}
            </div>

            {/* Stage 1 Footer Callout */}
            <div className="p-4 rounded-2xl bg-emerald-950/20 border border-emerald-800/40 text-xs text-emerald-200/90 flex items-center justify-between gap-4">
              <span>
                💡 <strong>Field Tip:</strong> Pruning infected lower leaves early in the morning while leaves are dry prevents conidia from splashing onto healthy mid-canopy leaves.
              </span>
              <button
                type="button"
                onClick={() => setActiveStage(2)}
                className="px-4 py-2 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold text-xs whitespace-nowrap shadow-md"
              >
                Proceed to Stage 2 &rarr;
              </button>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* STAGE 2: BIOLOGICAL & BOTANICAL BIO-SPRAYS (Always Unlocked) */}
        {/* ========================================================================= */}
        {activeStage === 2 && (
          <div className="space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 border-b border-cyan-900/30">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-cyan-500/20 border border-cyan-500/40 flex items-center justify-center text-cyan-400">
                  <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
                  </svg>
                </div>
                <div>
                  <h3 className="text-lg font-black text-white">
                    Stage 2: Biological &amp; Botanical Interventions
                  </h3>
                  <p className="text-xs text-slate-400">
                    Eco-safe bio-fungicides and botanicals protecting pollinators &amp; soil health
                  </p>
                </div>
              </div>
              <span className="self-start sm:self-auto px-3 py-1 rounded-full bg-cyan-500/20 text-cyan-300 border border-cyan-500/30 text-xs font-bold font-mono">
                BIO-CYAN CERTIFIED
              </span>
            </div>

            <p className="text-xs sm:text-sm text-slate-300 leading-relaxed">
              Bio-agents hyper-parasitize fungal hyphae and trigger systemic acquired resistance
              (SAR) in crops without chemical residues or Pre-Harvest waiting penalties.
            </p>

            {/* Checklist of Biological items */}
            <div className="space-y-3">
              {biologicalItems.map((item, index) => {
                const isChecked = !!completedBiologicalTasks[index];
                return (
                  <label
                    key={`biological-${index}`}
                    className={`p-4 rounded-2xl border transition-all flex items-start gap-3.5 cursor-pointer ${
                      isChecked
                        ? 'bg-cyan-950/30 border-cyan-500/50 shadow-sm'
                        : 'bg-slate-950/60 border-slate-800 hover:border-slate-700'
                    }`}
                  >
                    <input
                      type="checkbox"
                      checked={isChecked}
                      onChange={() => toggleBiologicalTask(index)}
                      className="mt-1 w-4 h-4 rounded text-cyan-500 focus:ring-cyan-400 accent-cyan-500 cursor-pointer flex-shrink-0"
                    />
                    <div className="flex-1 space-y-1">
                      <div className="text-xs sm:text-sm text-white font-medium leading-relaxed">
                        {item}
                      </div>
                      <div className="text-[11px] text-slate-400 flex items-center gap-2">
                        <span className="font-mono text-cyan-400 font-semibold">Bio Protocol #{index + 1}</span>
                        {isChecked && (
                          <span className="text-cyan-300 font-bold flex items-center gap-1">
                            ✓ Bio-application logged
                          </span>
                        )}
                      </div>
                    </div>
                  </label>
                );
              })}
            </div>

            {/* Stage 2 Footer Callout */}
            <div className="p-4 rounded-2xl bg-cyan-950/20 border border-cyan-800/40 text-xs text-cyan-200/90 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
              <span>
                🌿 <strong>Bio Spray Rule:</strong> Apply Trichoderma or Neem Oil strictly during late afternoon (04:30 - 06:30 PM) to protect beneficial living bio-agents from solar UV breakdown.
              </span>
              <div className="flex items-center gap-2 self-end sm:self-auto">
                <button
                  type="button"
                  onClick={() => setActiveStage(1)}
                  className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-white font-semibold text-xs"
                >
                  &larr; Stage 1
                </button>
                <button
                  type="button"
                  onClick={() => setActiveStage(3)}
                  className="px-4 py-2 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-xs whitespace-nowrap shadow-md"
                >
                  Inspect Stage 3 &rarr;
                </button>
              </div>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* STAGE 3: APPROVED CHEMICAL CONTROL (Strict Last Resort & Safety Gate) */}
        {/* ========================================================================= */}
        {activeStage === 3 && (
          <div className="space-y-6">
            {/* ===================================================================== */}
            {/* SUB-CASE A: LOCKED BEHIND AMBER GLASSMORPHIC SHIELD (Confidence < 75%) */}
            {/* ===================================================================== */}
            {requiresExpertVerification ? (
              <div className="relative rounded-3xl overflow-hidden p-6 sm:p-10 border border-amber-500/50 bg-gradient-to-b from-amber-950/40 via-slate-950/80 to-slate-950 shadow-2xl text-center space-y-6">
                {/* Visual Glassmorphic Amber Lock Icon */}
                <div className="mx-auto w-20 h-20 rounded-3xl bg-amber-500/20 border-2 border-amber-400 flex items-center justify-center text-amber-300 shadow-[0_0_30px_rgba(245,158,11,0.35)] relative">
                  <svg className="w-10 h-10 animate-pulse" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                  <span className="absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-amber-400 animate-ping" />
                </div>

                {/* Primary Warning Statement */}
                <div className="max-w-2xl mx-auto space-y-3">
                  <h3 className="text-xl sm:text-2xl font-black text-amber-300 leading-tight">
                    Chemical prescription locked due to AI uncertainty (&lt;75%).
                  </h3>
                  <h4 className="text-sm sm:text-base font-bold text-white">
                    KVK Expert Verification required to prevent toxic over-spraying.
                  </h4>
                  <p className="text-xs sm:text-sm text-slate-300 leading-relaxed">
                    Indiscriminate spraying of synthetic chemical fungicides on ambiguous foliar
                    pathology violates ICAR/DPPQS guidelines. It causes rapid pathogen resistance,
                    destroys soil micro-flora, and creates unnecessary financial loss.
                  </p>
                </div>

                {/* Status Box */}
                <div className="max-w-md mx-auto p-4 rounded-2xl bg-amber-950/30 border border-amber-500/30 text-left text-xs space-y-2">
                  <div className="flex items-center justify-between font-mono">
                    <span className="text-slate-400">Diagnosis Confidence:</span>
                    <span className="font-bold text-amber-400">{primaryCandidate.confidence}% (&lt; 75.0% threshold)</span>
                  </div>
                  <div className="flex items-center justify-between font-mono">
                    <span className="text-slate-400">Safety Interlock:</span>
                    <span className="font-bold text-amber-300">AUTONOMOUS DISPENSATION BLOCKED</span>
                  </div>
                  <div className="flex items-center justify-between font-mono">
                    <span className="text-slate-400">Escalation Hub:</span>
                    <span className="font-bold text-white">Taluka Krishi Vigyan Kendra (KVK)</span>
                  </div>
                </div>

                {/* Escalation Button or Confirmation Card */}
                {isKvkEscalated ? (
                  <div className="max-w-md mx-auto p-5 rounded-2xl bg-emerald-950/40 border border-emerald-500/50 text-left space-y-3">
                    <div className="flex items-center gap-2 text-emerald-300 font-bold text-sm">
                      <svg className="w-5 h-5 text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      Escalated to KVK Agronomist Cell!
                    </div>
                    <p className="text-xs text-slate-300">
                      Case <strong className="text-white font-mono">{kvkTicketNumber}</strong> registered in the Maharashtra KVK Tele-Diagnostics queue. An ICAR plant pathologist will review your Grad-CAM hotspot map.
                    </p>
                    <div className="text-[11px] text-emerald-400 font-mono">
                      Expected tele-callback: Within 4 daylight hours
                    </div>
                  </div>
                ) : (
                  <div className="max-w-md mx-auto pt-2">
                    <button
                      type="button"
                      onClick={handleEscalateToKvk}
                      className="w-full px-6 py-3.5 rounded-2xl bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-400 hover:to-orange-400 text-slate-950 font-black text-sm shadow-[0_0_25px_rgba(245,158,11,0.4)] flex items-center justify-center gap-2.5 transition-all"
                    >
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                      </svg>
                      Escalate Leaf to Local KVK Center for Priority Audit
                    </button>
                    <p className="text-[11px] text-slate-400 mt-2">
                      Free ICAR farmer support via Krishi Vigyan Kendra network
                    </p>
                  </div>
                )}
              </div>
            ) : (
              /* ===================================================================== */
              /* SUB-CASE B: UNLOCKED HIGH CONFIDENCE (>=75%) WITH ETL SAFETY CHECKBOX  */
              /* ===================================================================== */
              <div className="space-y-6">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 border-b border-rose-900/30">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-2xl bg-rose-500/20 border border-rose-500/40 flex items-center justify-center text-rose-400">
                      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                      </svg>
                    </div>
                    <div>
                      <h3 className="text-lg font-black text-white">
                        Stage 3: Approved Chemical Control (Regulated Last Resort)
                      </h3>
                      <p className="text-xs text-slate-400">
                        Central Insecticides Board &amp; Registration Committee (CIBRC) Compliant Protocol
                      </p>
                    </div>
                  </div>
                  <span className="self-start sm:self-auto px-3 py-1 rounded-full bg-rose-500/20 text-rose-300 border border-rose-500/30 text-xs font-bold font-mono">
                    ETL VERIFIED
                  </span>
                </div>

                {/* Economic Threshold Level (ETL) Safety Gate Card */}
                <div className="p-5 rounded-2xl bg-slate-950/90 border border-amber-500/40 shadow-xl space-y-4">
                  <div className="flex items-start gap-3">
                    <span className="px-2 py-0.5 rounded bg-amber-500/20 text-amber-300 text-[10px] font-mono font-bold uppercase">
                      Mandatory Gate
                    </span>
                    <h4 className="text-sm font-bold text-white">
                      Economic Threshold Level (ETL) Safety Verification
                    </h4>
                  </div>

                  <div className="p-3.5 rounded-xl bg-amber-950/20 border border-amber-500/20 text-xs text-amber-200/90 leading-relaxed">
                    <strong>ICAR Benchmark Criteria:</strong> {etlText}
                  </div>

                  {/* Mandatory Farmer Safety Checkbox */}
                  <label className="p-3.5 rounded-xl bg-slate-900 border border-slate-700 hover:border-emerald-500 transition-all flex items-start gap-3 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={isEtlConfirmed}
                      onChange={(e) => setIsEtlConfirmed(e.target.checked)}
                      className="mt-0.5 w-5 h-5 rounded text-emerald-500 focus:ring-emerald-400 accent-emerald-500 cursor-pointer flex-shrink-0"
                    />
                    <div className="space-y-0.5">
                      <span className="text-xs sm:text-sm font-bold text-white">
                        Economic Threshold Level (ETL) Crossed in Field
                      </span>
                      <p className="text-[11px] text-slate-400 leading-normal">
                        I certify that I have physically surveyed the field and confirmed that pest/lesion
                        severity exceeds the Economic Threshold Level specified above before applying
                        synthetic chemicals.
                      </p>
                    </div>
                  </label>
                </div>

                {/* Content Protected by ETL Checkbox */}
                {!isEtlConfirmed ? (
                  <div className="p-8 rounded-3xl bg-slate-950/50 border border-slate-800 text-center space-y-3">
                    <div className="w-12 h-12 rounded-full bg-slate-900 border border-slate-700 mx-auto flex items-center justify-center text-slate-500">
                      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                      </svg>
                    </div>
                    <h4 className="text-sm font-bold text-slate-300">
                      Chemical Prescription Shielded
                    </h4>
                    <p className="text-xs text-slate-500 max-w-md mx-auto">
                      Please check the <strong>"Economic Threshold Level (ETL) Crossed"</strong> checkbox
                      above to unlock the CIBRC-approved product formulation, exact dosage per litre,
                      and mandatory PPE safety checklist.
                    </p>
                  </div>
                ) : (
                  /* UNLOCKED CIBRC CHEMICAL DETAILS */
                  <div className="space-y-6 animate-fadeIn">
                    {/* Approved Product & Dosage Card */}
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      {/* Product Card */}
                      <div className="p-4 rounded-2xl bg-slate-950 border border-rose-500/30 space-y-2">
                        <div className="text-[11px] uppercase font-mono font-bold text-rose-400">
                          CIBRC Approved Product &amp; Active Ingredients
                        </div>
                        <div className="text-sm sm:text-base font-bold text-white">
                          {chemicalPlan.productName}
                        </div>
                        <div className="text-[11px] text-slate-400">
                          Registered under Section 9(3) of Insecticides Act 1968
                        </div>
                      </div>

                      {/* Dosage & PHI Card */}
                      <div className="p-4 rounded-2xl bg-slate-950 border border-rose-500/30 space-y-2">
                        <div className="text-[11px] uppercase font-mono font-bold text-cyan-400">
                          Prescribed Dosage &amp; Pre-Harvest Interval (PHI)
                        </div>
                        <div className="text-sm sm:text-base font-mono font-bold text-emerald-300">
                          {chemicalPlan.dosagePerLitre}
                        </div>
                        <div className="flex items-center gap-2 pt-1">
                          <span className="px-2 py-0.5 rounded bg-rose-500/20 text-rose-300 border border-rose-500/30 text-xs font-mono font-bold">
                            PHI: {chemicalPlan.waitingPeriodDays} Days Waiting Period
                          </span>
                        </div>
                      </div>
                    </div>

                    {/* Pre-Harvest Interval (PHI) Notice */}
                    <div className="p-4 rounded-2xl bg-rose-950/20 border border-rose-500/30 text-xs text-rose-200 flex items-start gap-3">
                      <svg className="w-5 h-5 flex-shrink-0 text-rose-400 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <div>
                        <strong className="text-white">Strict Harvest Prohibition (PHI {chemicalPlan.waitingPeriodDays} Days):</strong>{' '}
                        Do not harvest, consume, or transport produce to APMC wholesale markets until at least {chemicalPlan.waitingPeriodDays} days after chemical spray.
                      </div>
                    </div>

                    {/* Mandatory PPE Safety Checklist */}
                    <div className="space-y-3">
                      <h4 className="text-xs font-bold uppercase tracking-wider text-slate-300 flex items-center gap-2">
                        <svg className="w-4 h-4 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                        </svg>
                        Mandatory Applicator Personal Protective Equipment (PPE) Checklist
                      </h4>

                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                        {ppeWarnings.map((warning, index) => {
                          const isPpeChecked = !!checkedPpeItems[index];
                          return (
                            <label
                              key={`ppe-${index}`}
                              className={`p-3.5 rounded-xl border text-xs flex items-start gap-3 cursor-pointer transition-all ${
                                isPpeChecked
                                  ? 'bg-slate-900 border-emerald-500/50 text-white'
                                  : 'bg-slate-950 border-slate-800 text-slate-300 hover:border-slate-700'
                              }`}
                            >
                              <input
                                type="checkbox"
                                checked={isPpeChecked}
                                onChange={() => togglePpeItem(index)}
                                className="mt-0.5 w-4 h-4 rounded text-emerald-500 focus:ring-emerald-400 accent-emerald-500 cursor-pointer flex-shrink-0"
                              />
                              <span className="leading-relaxed">{warning}</span>
                            </label>
                          );
                        })}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
