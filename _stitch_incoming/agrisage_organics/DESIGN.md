---
name: AgriSage Organics
colors:
  surface: '#f2fcee'
  surface-dim: '#d3ddcf'
  surface-bright: '#f2fcee'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#edf7e8'
  surface-container: '#e7f1e3'
  surface-container-high: '#e1ebdd'
  surface-container-highest: '#dbe5d8'
  on-surface: '#151e15'
  on-surface-variant: '#424940'
  inverse-surface: '#2a3329'
  inverse-on-surface: '#eaf4e6'
  outline: '#72796f'
  outline-variant: '#c2c8bd'
  surface-tint: '#416740'
  primary: '#214623'
  on-primary: '#ffffff'
  primary-container: '#385e38'
  on-primary-container: '#abd6a6'
  inverse-primary: '#a7d2a2'
  secondary: '#506446'
  on-secondary: '#ffffff'
  secondary-container: '#d2eac3'
  on-secondary-container: '#566a4b'
  tertiary: '#2b4330'
  on-tertiary: '#ffffff'
  tertiary-container: '#425b46'
  on-tertiary-container: '#b5d1b7'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#c2eebd'
  primary-fixed-dim: '#a7d2a2'
  on-primary-fixed: '#002105'
  on-primary-fixed-variant: '#294f2b'
  secondary-fixed: '#d2eac3'
  secondary-fixed-dim: '#b7cda8'
  on-secondary-fixed: '#0e2008'
  on-secondary-fixed-variant: '#394c30'
  tertiary-fixed: '#cdeacf'
  tertiary-fixed-dim: '#b2ceb4'
  on-tertiary-fixed: '#08200f'
  on-tertiary-fixed-variant: '#344c38'
  background: '#f2fcee'
  on-background: '#151e15'
  surface-variant: '#dbe5d8'
typography:
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 30px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 26px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1.25rem
  space-xl: 1.75rem
---

## Brand & Style

This design system embodies an organic, grounded, and tranquil agricultural utility aesthetic. Tailored for intelligent agronomy, smart farming, and botanical management tools, the interface communicates reliability, effortless field utility, and natural calm. 

The aesthetic is clean, soft modernism paired with tactile organic tones. It replaces sterile digital whites and cold tech grays with sun-dappled sage, pistachio washes, and deep chlorophyll-infused forest tones. The visual mood evokes early morning moisture, healthy crops, and seamless technology working harmoniously with nature. Interfaces maintain high legibility under direct sunlight through crisp typography, purposeful contrast ratios, and generous touch targets designed for field accessibility.

## Colors

The palette is derived directly from botanical field notes, utilizing low-strain organic greens that reduce eye fatigue in outdoor environments while creating a distinctive, welcoming warmth.

### Roles & Implementation
- **Neutral Canvas (`#EBF5E7` / `#F3FAF0`):** The foundational ambient background. Replaces raw white with a soothing, desaturated mint/pistachio tint.
- **Surface & Cards (`#FFFFFF` & `#E2EEDC`):** High-level elevation containers use pure white for highlighted card modules or soft sage (`#E2EEDC`) for sunken panels, drawers, and secondary containers.
- **Primary Action (`#385E38`):** Deep botanical green used for primary action buttons, key brand stamps, and active icon badges.
- **Active Selection & Accents (`#CBE2BC` / `#D2E8C4`):** Soft herb/olive pill surfaces. Used behind selected navigation items, active chips, and progress fills, providing subtle distinction without visual noise.
- **Dark Forest Neutral / Typography (`#263E2B` & `#1F3624`):** Used across high-contrast typography, glyphs, and line icons instead of harsh neutral black. Ensures AAA contrast against pistachio backdrops while maintaining an organic feel.
- **Muted Subtext (`#5E735F`):** Medium olive-tinted slate for secondary metadata, disabled states, and offline status indicators.

## Typography

**Plus Jakarta Sans** provides rounded geometry and open counters, giving the interface a friendly, humane, and modern quality that remains legible under varying lighting conditions.

- **Headlines:** Set with confident medium and bold weights. Tight line heights keep grouped titles compact, prioritizing data density without feeling crowded.
- **Body & Navigation Items:** Rendered in `500` (Medium) weight rather than regular 400 to prevent thin stroke drop-off against soft green tinted surfaces.
- **Labels & Microcopy:** Rendered with semi-bold weights for metadata badges, offline status bars, and calculator outputs.

## Layout & Spacing

The layout is built upon an 8pt modular rhythm tuned for handheld and field-tablet operation:
- **Margins & Gutters:** Mobile layouts leverage compact `1rem` (16px) margins to preserve horizontal real estate for data cards, sliding sheets, and multi-column sensor metrics.
- **Vertical Spacing:** Generous vertical padding within interactive elements guarantees effortless finger tapping (minimum 44px hit zones for menu rows and action buttons).
- **Sheet & Drawer Pattern:** Modal sheets and navigation drawers use 85% viewport coverage with generous internal edge insets (`1.25rem`), preserving visual context of the underlaid screen.

## Elevation & Depth

Visual hierarchy avoids heavy drop shadows, relying instead on **tonal stepping** and soft ambient backdrops:

- **Tonal Layers:** Elevation is expressed through value contrast. The canvas sits at `#EBF5E7`; cards and drawers elevate with `#FFFFFF` or `#F4FAF2`; interactive active selections nest inside with `#CBE2BC`.
- **Soft Ambient Occlusion:** When elevation separation is required (such as sticky bottom navigations or floating bottom sheets), use a gentle diffuse shadow: `0 8px 24px -4px rgba(38, 62, 43, 0.08)`. The shadow is tinted with the tertiary dark forest hue rather than neutral gray, preserving color harmony.
- **Ghost Outlines:** Crisp, 1px low-contrast borders (`rgba(38, 62, 43, 0.08)`) separate cards on low-tint surfaces to ensure structure without visual heaviness.

## Shapes

The shape vocabulary prioritizes rounded, organic geometry:
- **Base Components:** Input fields, list containers, and dialogs utilize rounded corners (`0.5rem` to `1rem`).
- **Interactive Pills:** Selection states, tabs, status tags, and menu active highlights use full pill styling (`9999px` / `rounded-full` or `1rem`) to echo pebble and leaf motifs.
- **Sheets & Drawers:** Top-level containers (sliding menus, bottom sheets) feature generous `1.5rem` to `2rem` rounded corners on exposed edges.

## Components

### Navigation Drawers & Menus
- **Container:** Rounded sheet with top and right radius of `1.5rem` filled with `#EBF5E7` or `#F4FAF2`.
- **Header:** Features a circular badge (`#385E38`) containing an icon in white, paired with title and subtitle metadata in `#263E2B`.
- **List Items:** Default state has transparent background, `#263E2B` icons and text. Active items gain a full `#CBE2BC` rounded pill background with `#1F3624` bold typography.
- **Bottom Status Footer:** Anchored banner with `#DCEFD4` fill, micro-icon, and offline-sync status typography.

### Buttons
- **Primary:** Background `#385E38`, foreground `#FFFFFF`, border-radius `0.75rem` or full pill. Subtle hover/pressed state drops to `#2B482B`.
- **Secondary / Soft:** Background `#CBE2BC`, foreground `#1F3624`.
- **Ghost / Outlined:** Transparent surface with 1px border `#263E2B` at 15% opacity, foreground `#263E2B`.

### Cards & Tile Containers
- **Standard Card:** Crisp `#FFFFFF` surface with `1rem` radius and optional 1px border `rgba(38, 62, 43, 0.06)`.
- **Muted Card:** Soft tint `#E2EEDC` used for contextual telemetry, scan history items, and weather modules.
- **Dark Emphasis Module:** Rich `#263E2B` forest surface with `#FFFFFF` text and `#CBE2BC` secondary accents for high-priority camera scanners and diagnostic tools.

### Form Inputs & Selectors
- **Input Fields:** Filled `#FFFFFF` or `#F3FAF0` background, subtle border, placeholder `#5E735F`, text `#1F3624`. Focused state introduces a 2px outline in `#385E38`.
- **Toggles & Radios:** Unchecked states use soft muted olive lines; active states fill with `#385E38`.