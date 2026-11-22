import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'FloraX | Predictive, Diagnostic & Advisory (PDA) Crop Health Platform',
  description:
    'FloraX (Team ID: SRJ-0074 / AI-05) - ICAR-allied crop health diagnostic, explainable Grad-CAM, predictive micro-climate epidemiology, and KVK verification loop.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className="bg-slate-950 text-slate-100 antialiased selection:bg-emerald-500 selection:text-slate-950">
        {children}
      </body>
    </html>
  );
}
