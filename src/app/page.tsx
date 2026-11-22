'use client';

import React, { useState, useEffect } from 'react';
import {
  DiagnosticResult,
  SupportedLanguage,
  WeatherRiskPrediction,
  VillageOutbreakCluster,
} from '../types/florax';
import {
  TOMATO_EARLY_BLIGHT_HIGH_CONFIDENCE,
  TOMATO_EARLY_BLIGHT_LOW_CONFIDENCE,
} from '../data/icar-ipm-vault';

// Import All FloraX Pillar Components (Phases 1, 2, 3, 4)
import { ExplainableScanner } from '../components/ExplainableScanner';
import { SmartIPMAdvisory } from '../components/SmartIPMAdvisory';
import { PredictiveWeatherRadar } from '../components/PredictiveWeatherRadar';
import { CommunityOutbreakMap } from '../components/CommunityOutbreakMap';
import { DiseaseProgressionTracker } from '../components/DiseaseProgressionTracker';
import { OfflineVoiceAssistant } from '../components/OfflineVoiceAssistant';
import { KVKExpertPortalModal, KvkAgronomistNote } from '../components/KVKExpertPortalModal';

// ============================================================================
// WORKSPACE TAB ENUM
// ============================================================================
type ActiveTab = 'xai-studio' | 'weather-radar' | 'progression-tracker';
type ViewMode = 'TABBED' | 'BENTO_GRID';

export default function FloraXCommandCenter() {
  // Global Language State (Synchronized across all components)
  const [language, setLanguage] = useState<SupportedLanguage>('en');

  // Global Offline State
  const [isOffline, setIsOffline] = useState<boolean>(false);

  // Active Diagnostic Result State (Shared between Scanner, IPM Advisory & KVK Modal)
  const [diagnosticResult, setDiagnosticResult] = useState<DiagnosticResult>(
    TOMATO_EARLY_BLIGHT_HIGH_CONFIDENCE
  );

  // KVK Expert Portal Modal State
  const [isKvkModalOpen, setIsKvkModalOpen] = useState<boolean>(false);
  const [latestKvkNote, setLatestKvkNote] = useState<KvkAgronomistNote | null>(null);

  // Active Workspace Navigation & View Mode
  const [activeTab, setActiveTab] = useState<ActiveTab>('xai-studio');
  const [viewMode, setViewMode] = useState<ViewMode>('TABBED');

  // Weather & Community Coordinates Synchronization
  const [activeHubId, setActiveHubId] = useState<string>('nashik');
  const [selectedCluster, setSelectedCluster] = useState<VillageOutbreakCluster | null>(null);

  // Top candidate confidence & KVK flag calculation
  const topCandidate = diagnosticResult.topCandidates[0];
  const isConfidenceLow =
    diagnosticResult.requiresExpertVerification || topCandidate.confidence < 75.0;

  // Auto-open KVK Modal if confidence is low AND not yet confirmed
  useEffect(() => {
    if (isConfidenceLow && diagnosticResult.verificationStatus === 'PENDING_KVK_REVIEW') {
      // Optional: don't force popup immediately on load, but keep badge prominent
    }
  }, [isConfidenceLow, diagnosticResult.verificationStatus]);

  // Handle Diagnostic Completion from Scanner
  const handleDiagnosticComplete = (result: DiagnosticResult) => {
    setDiagnosticResult(result);
  };

  // Handle KVK Live Approval
  const handleKvkApproved = (
    updatedResult: DiagnosticResult,
    agronomistNote: KvkAgronomistNote
  ) => {
    setDiagnosticResult(updatedResult);
    setLatestKvkNote(agronomistNote);
  };

  // Handle Escalation request from SmartIPMAdvisory or Scanner
  const handleEscalateToKvk = (scanId: string) => {
    setIsKvkModalOpen(true);
  };

  // Handle Cluster Selection in Outbreak Map
  const handleClusterSelect = (cluster: VillageOutbreakCluster) => {
    setSelectedCluster(cluster);
    // Map cluster district to weather hub id
    const districtLower = cluster.district.toLowerCase();
    if (districtLower.includes('nashik')) setActiveHubId('nashik');
    else if (districtLower.includes('pune')) setActiveHubId('pune');
    else if (districtLower.includes('nagpur')) setActiveHubId('nagpur');
    else if (districtLower.includes('kolhapur')) setActiveHubId('kolhapur');
    else if (districtLower.includes('ratnagiri')) setActiveHubId('ratnagiri');
  };

  // Current advisory text for voice playback
  const activeCropName = diagnosticResult.cropName;
  const activeDiseaseName = topCandidate.name[language] || topCandidate.name.en;
  const currentAdvisoryVoiceText =
    language === 'mr'
      ? `${activeCropName} पिकावर ${activeDiseaseName} रोगाचे निदान झाले आहे. ICAR मार्गदर्शक तत्त्वांनुसार ट्रायकोडर्मा किंवा जैविक निंबोळी अर्क वापरा.`
      : language === 'hi'
      ? `${activeCropName} फसल में ${activeDiseaseName} रोग के लक्षण पाए गए हैं। ICAR दिशानिर्देशों के अनुसार जैविक ट्राइकोडर्मा का प्रयोग करें।`
      : `${activeCropName} diagnosed with ${activeDiseaseName} at ${topCandidate.confidence.toFixed(
          1
        )}% confidence. ICAR IPM Stage 1 and Stage 2 biological protocols recommended.`;

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans pb-28">
      {/* =================================================================== */}
      {/* TOP NAVIGATION BAR                                                  */}
      {/* =================================================================== */}
      <header className="sticky top-0 z-30 bg-slate-950/90 backdrop-blur-xl border-b border-emerald-500/30 shadow-2xl">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-3 flex flex-wrap items-center justify-between gap-3">
          {/* Left: Brand Identity & Team Accreditation */}
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-gradient-to-br from-emerald-400 via-teal-500 to-emerald-700 flex items-center justify-center text-slate-950 shadow-lg shadow-emerald-950">
              <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2.2}
                  d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
                />
              </svg>
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-lg font-black tracking-tight text-white flex items-center gap-2">
                  <span>FloraX</span>
                  <span className="text-[11px] font-mono font-bold px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/40">
                    Team: SRJ-0074 / AI-05
                  </span>
                </h1>
              </div>
              <p className="text-[11px] text-slate-400 font-medium">
                Predictive, Diagnostic & Advisory (PDA) Platform • ICAR-KVK Allied
              </p>
            </div>
          </div>

          {/* Right: Controls (Language Switcher, Offline Mode, KVK Badge & View Toggle) */}
          <div className="flex flex-wrap items-center gap-2.5">
            {/* KVK Status Hub Button */}
            <button
              type="button"
              onClick={() => setIsKvkModalOpen(true)}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold font-mono border flex items-center gap-2 transition-all shadow-md ${
                diagnosticResult.verificationStatus === 'KVK_CONFIRMED'
                  ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40 hover:bg-emerald-500/30'
                  : isConfidenceLow
                  ? 'bg-amber-500/20 text-amber-300 border-amber-500/50 hover:bg-amber-500/30 animate-pulse'
                  : 'bg-slate-900 text-slate-400 border-slate-800 hover:text-white'
              }`}
              title="Open KVK Tele-Diagnostic Expert Verification Modal"
            >
              <span
                className={`w-2 h-2 rounded-full ${
                  diagnosticResult.verificationStatus === 'KVK_CONFIRMED'
                    ? 'bg-emerald-400'
                    : isConfidenceLow
                    ? 'bg-amber-400 animate-ping'
                    : 'bg-slate-500'
                }`}
              />
              <span>
                {diagnosticResult.verificationStatus === 'KVK_CONFIRMED'
                  ? 'KVK Confirmed (Dr. Deshmukh)'
                  : isConfidenceLow
                  ? 'KVK Review Required'
                  : 'KVK Expert Portal'}
              </span>
            </button>

            {/* Offline / Online Field Toggle */}
            <button
              type="button"
              onClick={() => setIsOffline(!isOffline)}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold border flex items-center gap-2 transition-all ${
                isOffline
                  ? 'bg-amber-500/20 text-amber-300 border-amber-500/40 hover:bg-amber-500/30'
                  : 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40 hover:bg-emerald-500/30'
              }`}
              title={
                isOffline
                  ? 'Offline Field Mode active. Click to reconnect.'
                  : 'Cloud sync active. Click to simulate offline mode.'
              }
            >
              <span
                className={`w-2 h-2 rounded-full ${
                  isOffline ? 'bg-amber-400 animate-pulse' : 'bg-emerald-400'
                }`}
              />
              <span className="hidden sm:inline">
                {isOffline ? 'Offline Farm Mode' : 'Cloud Sync (4G/5G)'}
              </span>
            </button>

            {/* Regional Language Switcher */}
            <div className="flex items-center bg-slate-900 border border-slate-800 rounded-xl p-0.5 shadow-inner">
              <button
                type="button"
                onClick={() => setLanguage('mr')}
                className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all ${
                  language === 'mr'
                    ? 'bg-emerald-500 text-slate-950 shadow-md shadow-emerald-950 font-black'
                    : 'text-slate-400 hover:text-white'
                }`}
                title="मराठी (Maharashtra Agro-Zones)"
              >
                मराठी
              </button>
              <button
                type="button"
                onClick={() => setLanguage('hi')}
                className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all ${
                  language === 'hi'
                    ? 'bg-emerald-500 text-slate-950 shadow-md shadow-emerald-950 font-black'
                    : 'text-slate-400 hover:text-white'
                }`}
                title="हिन्दी (राजभाषा)"
              >
                हिन्दी
              </button>
              <button
                type="button"
                onClick={() => setLanguage('en')}
                className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all ${
                  language === 'en'
                    ? 'bg-emerald-500 text-slate-950 shadow-md shadow-emerald-950 font-black'
                    : 'text-slate-400 hover:text-white'
                }`}
                title="English (Agronomic Standard)"
              >
                English
              </button>
            </div>

            {/* View Mode Toggle: Tabbed vs Bento Grid */}
            <button
              type="button"
              onClick={() => setViewMode(viewMode === 'TABBED' ? 'BENTO_GRID' : 'TABBED')}
              className={`p-2 rounded-xl border text-xs font-bold transition-all flex items-center gap-1.5 ${
                viewMode === 'BENTO_GRID'
                  ? 'bg-purple-500/20 text-purple-300 border-purple-500/40'
                  : 'bg-slate-900 text-slate-400 border-slate-800 hover:text-white'
              }`}
              title="Toggle Bento Grid Command Center View"
            >
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"
                />
              </svg>
              <span className="hidden md:inline font-mono text-[11px]">
                {viewMode === 'BENTO_GRID' ? 'Grid View' : 'Tabbed View'}
              </span>
            </button>
          </div>
        </div>

        {/* Workspace Primary Tabs (Visible when in TABBED mode) */}
        {viewMode === 'TABBED' && (
          <div className="max-w-7xl mx-auto px-4 sm:px-6 flex items-center gap-2 overflow-x-auto border-t border-slate-900 pt-2 pb-2">
            {/* Tab 1 */}
            <button
              type="button"
              onClick={() => setActiveTab('xai-studio')}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 flex-shrink-0 ${
                activeTab === 'xai-studio'
                  ? 'bg-emerald-500 text-slate-950 shadow-md shadow-emerald-950 font-black'
                  : 'bg-slate-900/60 text-slate-400 hover:text-white hover:bg-slate-800'
              }`}
            >
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"
                />
              </svg>
              <span>1. XAI Diagnostic & Grad-CAM Studio</span>
              {isConfidenceLow && (
                <span className="w-2 h-2 rounded-full bg-amber-400 animate-pulse" />
              )}
            </button>

            {/* Tab 2 */}
            <button
              type="button"
              onClick={() => setActiveTab('weather-radar')}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 flex-shrink-0 ${
                activeTab === 'weather-radar'
                  ? 'bg-emerald-500 text-slate-950 shadow-md shadow-emerald-950 font-black'
                  : 'bg-slate-900/60 text-slate-400 hover:text-white hover:bg-slate-800'
              }`}
            >
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M3 15a4 4 0 004 4h9a5 5 0 10-.1-9.999 5.002 5.002 0 00-9.78 2.096A4.001 4.001 0 003 15z"
                />
              </svg>
              <span>2. Predictive Micro-Climate & Outbreak Map</span>
              <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-amber-500/20 text-amber-300">
                84% Spore Risk
              </span>
            </button>

            {/* Tab 3 */}
            <button
              type="button"
              onClick={() => setActiveTab('progression-tracker')}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 flex-shrink-0 ${
                activeTab === 'progression-tracker'
                  ? 'bg-emerald-500 text-slate-950 shadow-md shadow-emerald-950 font-black'
                  : 'bg-slate-900/60 text-slate-400 hover:text-white hover:bg-slate-800'
              }`}
            >
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z"
                />
              </svg>
              <span>3. Crop Recovery & Progression Tracker</span>
            </button>
          </div>
        )}
      </header>

      {/* =================================================================== */}
      {/* MAIN WORKSPACE CONTENT                                              */}
      {/* =================================================================== */}
      <main className="flex-1 max-w-7xl mx-auto w-full px-4 sm:px-6 py-6 space-y-8">
        {/* VIEW 1: TABBED FOCUSED STUDIOS */}
        {viewMode === 'TABBED' && (
          <div className="space-y-8 animate-fadeIn">
            {/* ------------------------------------------------------------- */}
            {/* TAB 1: XAI DIAGNOSTIC & GRAD-CAM STUDIO                       */}
            {/* ------------------------------------------------------------- */}
            {activeTab === 'xai-studio' && (
              <div className="space-y-8">
                {/* Explainable Vision Scanner */}
                <section>
                  <ExplainableScanner
                    initialLanguage={language}
                    activeResult={diagnosticResult}
                    onDiagnosticComplete={handleDiagnosticComplete}
                  />
                </section>

                {/* Smart IPM 3-Stage Advisory (Grounded in ICAR Knowledge Vault) */}
                <section>
                  <SmartIPMAdvisory
                    diagnosticResult={diagnosticResult}
                    language={language}
                    onLanguageChange={(newLang) => setLanguage(newLang)}
                    onEscalateToKvk={handleEscalateToKvk}
                  />
                </section>
              </div>
            )}

            {/* ------------------------------------------------------------- */}
            {/* TAB 2: PREDICTIVE WEATHER & OUTBREAK RADAR                    */}
            {/* ------------------------------------------------------------- */}
            {activeTab === 'weather-radar' && (
              <div className="space-y-8">
                {/* Predictive Weather Radar */}
                <section>
                  <PredictiveWeatherRadar
                    initialHubId={activeHubId}
                    initialLanguage={language}
                    onRiskChange={(prediction) => {
                      // Optional: sync risk
                    }}
                  />
                </section>

                {/* Community Outbreak Cluster Map */}
                <section>
                  <CommunityOutbreakMap
                    initialLanguage={language}
                    onClusterSelect={handleClusterSelect}
                  />
                </section>
              </div>
            )}

            {/* ------------------------------------------------------------- */}
            {/* TAB 3: CROP RECOVERY & PROGRESSION TRACKER                    */}
            {/* ------------------------------------------------------------- */}
            {activeTab === 'progression-tracker' && (
              <div className="space-y-8">
                <section>
                  <DiseaseProgressionTracker
                    initialLanguage={language}
                    onScanLogged={(updatedRecord) => {
                      // Optional: save logged scan
                    }}
                  />
                </section>
              </div>
            )}
          </div>
        )}

        {/* VIEW 2: COMMAND CENTER BENTO GRID (Presentation Mode for Hackathon) */}
        {viewMode === 'BENTO_GRID' && (
          <div className="space-y-10 animate-fadeIn">
            <div className="p-4 rounded-2xl bg-gradient-to-r from-purple-950/40 via-slate-900 to-emerald-950/40 border border-purple-500/30 flex items-center justify-between">
              <div>
                <h2 className="text-base font-black text-white flex items-center gap-2">
                  <span>Command Center Bento Grid</span>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-purple-500/20 text-purple-300 border border-purple-500/30">
                    Live Multi-Pillar Triangulation
                  </span>
                </h2>
                <p className="text-xs text-slate-300 mt-0.5">
                  Synchronous execution of Computer Vision XAI, Micro-Meteorology, Spatial Outbreaks & Chrono-Tracking.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setViewMode('TABBED')}
                className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-bold text-slate-200 border border-slate-700"
              >
                Switch to Tabs
              </button>
            </div>

            {/* Pillar 1: XAI Scanner */}
            <div className="space-y-4">
              <div className="flex items-center gap-2 text-sm font-black text-emerald-400 uppercase tracking-wider">
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-400" />
                Pillar 1: Explainable Vision & Grad-CAM Spatial Studio
              </div>
              <ExplainableScanner
                initialLanguage={language}
                activeResult={diagnosticResult}
                onDiagnosticComplete={handleDiagnosticComplete}
              />
            </div>

            {/* Pillar 1B: Smart IPM Advisory */}
            <div className="space-y-4">
              <div className="flex items-center gap-2 text-sm font-black text-emerald-400 uppercase tracking-wider">
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-400" />
                Pillar 1B: CIBRC-Regulated 3-Stage IPM Prescription
              </div>
              <SmartIPMAdvisory
                diagnosticResult={diagnosticResult}
                language={language}
                onLanguageChange={(newLang) => setLanguage(newLang)}
                onEscalateToKvk={handleEscalateToKvk}
              />
            </div>

            {/* Pillar 2: Weather & Community Outbreak */}
            <div className="space-y-4">
              <div className="flex items-center gap-2 text-sm font-black text-sky-400 uppercase tracking-wider">
                <span className="w-2.5 h-2.5 rounded-full bg-sky-400" />
                Pillar 2: Predictive Micro-Climate & Community Outbreak Map
              </div>
              <div className="grid grid-cols-1 gap-8">
                <PredictiveWeatherRadar
                  initialHubId={activeHubId}
                  initialLanguage={language}
                />
                <CommunityOutbreakMap
                  initialLanguage={language}
                  onClusterSelect={handleClusterSelect}
                />
              </div>
            </div>

            {/* Pillar 3: Disease Progression Tracker */}
            <div className="space-y-4">
              <div className="flex items-center gap-2 text-sm font-black text-amber-400 uppercase tracking-wider">
                <span className="w-2.5 h-2.5 rounded-full bg-amber-400" />
                Pillar 3: Multi-Temporal Plant Remission & Recovery Tracker
              </div>
              <DiseaseProgressionTracker initialLanguage={language} />
            </div>
          </div>
        )}
      </main>

      {/* =================================================================== */}
      {/* KVK EXPERT VERIFICATION PORTAL MODAL                                */}
      {/* =================================================================== */}
      <KVKExpertPortalModal
        isOpen={isKvkModalOpen}
        onClose={() => setIsKvkModalOpen(false)}
        diagnosticResult={diagnosticResult}
        language={language}
        onKvkApproved={handleKvkApproved}
      />

      {/* =================================================================== */}
      {/* OFFLINE VOICE ASSISTANT DOCKED CONSOLE                              */}
      {/* =================================================================== */}
      <OfflineVoiceAssistant
        language={language}
        onLanguageChange={(newLang) => setLanguage(newLang)}
        isOffline={isOffline}
        onOfflineToggle={(off) => setIsOffline(off)}
        currentAdvisoryText={currentAdvisoryVoiceText}
      />
    </div>
  );
}
