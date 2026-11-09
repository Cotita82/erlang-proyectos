---
name: Distributed Observability Console
colors:
  surface: '#0b1326'
  surface-dim: '#0b1326'
  surface-bright: '#31394d'
  surface-container-lowest: '#060e20'
  surface-container-low: '#131b2e'
  surface-container: '#171f33'
  surface-container-high: '#222a3d'
  surface-container-highest: '#2d3449'
  on-surface: '#dae2fd'
  on-surface-variant: '#bec8d2'
  inverse-surface: '#dae2fd'
  inverse-on-surface: '#283044'
  outline: '#88929b'
  outline-variant: '#3e4850'
  surface-tint: '#89ceff'
  primary: '#89ceff'
  on-primary: '#00344d'
  primary-container: '#0ea5e9'
  on-primary-container: '#003751'
  inverse-primary: '#006591'
  secondary: '#c0c1ff'
  on-secondary: '#1000a9'
  secondary-container: '#3131c0'
  on-secondary-container: '#b0b2ff'
  tertiary: '#4edea3'
  on-tertiary: '#003824'
  tertiary-container: '#00b17b'
  on-tertiary-container: '#003b26'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#c9e6ff'
  primary-fixed-dim: '#89ceff'
  on-primary-fixed: '#001e2f'
  on-primary-fixed-variant: '#004c6e'
  secondary-fixed: '#e1e0ff'
  secondary-fixed-dim: '#c0c1ff'
  on-secondary-fixed: '#07006c'
  on-secondary-fixed-variant: '#2f2ebe'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#0b1326'
  on-background: '#dae2fd'
  surface-variant: '#2d3449'
typography:
  headline-xl:
    fontFamily: Geist
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Geist
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Geist
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Geist
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
  body-md:
    fontFamily: Geist
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  body-sm:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  telemetry-metric:
    fontFamily: JetBrains Mono
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.03em
  telemetry-mono:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
  telemetry-code:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 16px
  label-caps:
    fontFamily: JetBrains Mono
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 12px
    letterSpacing: 0.08em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-desktop: 1.5rem
  margin: 1rem
  margin-desktop: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
  space-2xl: 2rem
---

## Brand & Style
The design system establishes a high-density, mission-critical operations environment tailored for systems engineers and operators managing distributed topologies, specifically Erlang/OTP actor clusters and fault-tolerant nodes.

The aesthetic fuses **Precision Technical Minimalism** with **Industrial Telemetry UI** (reminiscent of low-latency database engines, Datadog dashboards, and CockroachDB console interfaces). 

- **Personality:** Resilient, exact, unyielding, diagnostic, highly structured.
- **Visual Stance:** Dark graphite architectural foundations, razor-sharp information boundaries, high functional contrast, zero frivolous decoration. Every pixel conveys status, heartbeat, or operational telemetry.
- **Emotional Response:** Confidence under pressure, instantaneous situational awareness, clarity during split-brain or network partition incidents.

## Colors
The palette utilizes dark graphite values to reduce eye fatigue across multi-screen monitoring environments while ensuring vital state shifts stand out sharply against the canvas.

### Core Architecture
- **Primary (`#0EA5E9` - Cyber Sky):** Interactive focal points, active connections, follower indicators, operational throughput graphs.
- **Secondary (`#6366F1` - Erlang Iris):** Actor topology boundaries, Raft/Erlang Leader nodes, consensus rings, primary coordinators.
- **Tertiary (`#10B981` - Emerald Healthy):** Quorum healthy, write operations active, heartbeat synced, node UP.
- **Neutral Base (`#0F172A` - Slate Obsidian):** Deep background frame, layered with tinted surface steps (`#0B0F19`, `#1E293B`, `#334155`).

### Semantic Status Matrix
- **Status OK (`#10B981`):** Write accepted, healthy consensus, replica lag &lt; 5ms.
- **Status Warning (`#F59E0B`):** Lag spike (&gt; 50ms), election in-progress, degraded peer count.
- **Status Critical (`#EF4444`):** Quorum lost, partition detected, write rejected, node uncontactable (`nodedown`).
- **Telemetry Muted (`#64748B`):** Standby channels, secondary labels, structural hairpins.

## Typography
The system enforces a dual-engine typographic protocol:

1. **Interface Engine (`Geist`):** Used for structural chrome, navigation, dialogs, and macro headings. Chosen for its geometric discipline, compact vertical metrics, and clarity at compact sizes.
2. **Telemetry Engine (`JetBrains Mono`):** Non-negotiable for telemetry values, Erlang node strings (`node1@10.0.1.12`), process IDs (`&lt;0.151.0&gt;`), memory addresses, timestamps, and log feeds. Fixed-width character cells guarantee alignment across scanning tabular data and metrics trees.

## Layout & Spacing
The layout implements a high-density, multi-panel grid system that scales from dense terminal consoles to ultra-wide control center displays:

- **12-Column Technical Grid:** Accommodates three-node cluster topologies smoothly across 3-column splits (4 columns per node card: `n1`, `n2`, `n3`).
- **Horizontal Density:** Strict `4px` baseline interval (`0.25rem`). Padding inside dense diagnostic tables and log lines drops to `space-xs` and `space-sm` to maximize vertical viewport capacity.
- **Breakpoints & Layout Behavior:**
  - **Mobile (< 768px):** Single-column stacked node cards; horizontally scrollable metric timelines; collapsed system logs.
  - **Tablet (768px - 1024px):** 2+1 node arrangement, persistent system quorum banner on top.
  - **Desktop (1024px+):** 3-column symmetrical node array (`n1 | n2 | n3`), synchronized crosshairs, side-panel diagnostic inspector, bottom-pinned live Erlang trace log.

## Elevation & Depth
Elevation is rendered strictly via **Tonal Stacking and Razor Wire Outlines** rather than soft diffuse shadows. This preserves crisp diagnostic readability without ambient blur pollution.

- **Canvas Base (`#0B0F19`):** Root background, void of any highlights.
- **Surface Tier 1 (`#0F172A`):** Core panels, module blocks, console workspace. Bordered by `1px solid #1E293B`.
- **Surface Tier 2 (`#1E293B`):** Node cards, interactive sub-containers, log viewer background. Bordered by `1px solid #334155`.
- **Overlay & Popovers (`#1E293B`):** Tooltips, process inspection drawers. Rendered with an additional micro-glow outline: `box-shadow: 0 0 0 1px #475569, 0 8px 24px -4px rgba(0, 0, 0, 0.6)`.
- **Status Glow (Pulsing Depth):** For critical cluster partitions or leader changes, surfaces utilize directional accent borders (e.g., `border-left: 3px solid #EF4444` with `box-shadow: inset 1px 0 8px -2px rgba(239, 68, 68, 0.25)`).

## Shapes
A constrained roundedness level (`1` / Soft) enforces an engineered instrument appearance:

- Standard controls, node cards, and inputs use `4px` (`0.25rem`) corners.
- Micro telemetry chips, pills, and status tags cap at `2px` or `4px` max.
- Strictly no circular or capsule pill designs for data containers. Rectilinear structure communicates stability and deterministic behavior.

## Components

### Node Cluster Cards (`n1`, `n2`, `n3`)
- **Structure:** Surface Tier 2 container with top-edge status bar: Emerald (OK), Amber (Degraded), Rose-Red (Partition/Down).
- **Header:** Node name (`n1.erlang.internal`) in `telemetry-mono`, paired with a role badge (Leader: Indigo `#6366F1` background at 15% opacity + solid border; Follower: Sky `#0EA5E9`).
- **Body:** Live heartbeat indicator (pulsing dot), Erlang BEAM process count, memory allocation (`ETS` / `Atom` / `Binary`), and replication lag micro-gauge.

### Latency & Replication Bars
- Linear horizontal bars showing real-time latency (ms). 
- Threshold tracking: &lt; 10ms (Emerald fill), 10–50ms (Amber fill), &gt; 50ms (Rose fill).
- Monospaced readout docked flush-right (`2.4ms` / `±0.3ms`).

### Tactical Action Buttons
- **Primary Action (Heal, Failover, Step Down):** `#0EA5E9` background with dark slate text, or high-contrast outlined variants with monospaced uppercase typography (`label-caps`).
- **Destructive Action (Kill Node, Partition Inject):** Border `#EF4444`, text `#EF4444`, background `rgba(239, 68, 68, 0.08)`. Hover increases saturation to solid fill.
- **Micro-sizing:** Compact padding (`4px 10px`), active state exhibits instant 1px scale inset.

### Severity Badges & System Event Logs
- **Event Feeds:** JetBrains Mono terminal log entries with timestamp (`YYYY-MM-DDTHH:mm:ss.sssZ`), Erlang node tag, and severity badge.
- **Badge Tokens:**
  - `[INFO]` Blue/Sky border and subtle fill.
  - `[WARN]` Amber text with subtle tinted border.
  - `[CRIT]` Rose-Red high-contrast fill with white text.
  - `[SYNC]` Emerald monospace label.

### Form Inputs & Telemetry Toggles
- Inputs display a `#0B0F19` inset well with `#334155` border. Focused state switches border to `#0EA5E9` with zero ambient ring blur.
- Toggles utilize square mechanical slide indicators instead of soft pill switches.