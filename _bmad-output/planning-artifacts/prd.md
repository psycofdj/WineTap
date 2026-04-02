---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
classification:
  projectType: desktop_app
  domain: general
  complexity: low
  projectContext: brownfield
inputDocuments:
  - docs/index.md
  - docs/project-overview.md
  - docs/architecture.md
  - docs/source-tree-analysis.md
  - docs/data-models.md
  - docs/api-contracts.md
  - docs/development-guide.md
  - spec.md
documentCounts:
  briefs: 0
  research: 0
  brainstorming: 0
  projectDocs: 8
workflowType: 'prd'
---

# Product Requirements Document - winetap

**Author:** Psy
**Date:** 2026-03-30

## Executive Summary

WineTap is an RFID-based wine cellar inventory system tracking bottles from purchase to consumption. The system is operational with a gRPC server (Raspberry Pi), a cellar scanner for exit tracking, and a Qt6 desktop manager for intake and browsing. This PRD defines a new **Dashboard screen** in the manager application that surfaces actionable insights from existing inventory data. The MVP delivers stock counts and breakdowns by color and designation with interactive drill-down. Future phases add domain/region breakdowns, consumption trends, cellar value, and drink-before alerts. All data is derived from the current gRPC API with no new server-side endpoints required.

### What Makes This Special

The inventory data already exists in the system but is only accessible through flat list browsing. The dashboard transforms this raw data into at-a-glance visual summaries that answer practical questions: what to drink soon, where the cellar value concentrates, how consumption trends over time, and which regions or domains dominate the collection. Interactive elements let the user drill from any summary into the relevant inventory subset, bridging insight and action without context-switching.

## Project Classification

- **Project Type:** Desktop application (Qt6 GUI with IoT/embedded backend)
- **Domain:** Personal inventory / asset tracking
- **Complexity:** Low — no regulatory requirements, single-user home network deployment, building on stable existing data model and API
- **Project Context:** Brownfield — new feature addition to a functional system with 17 gRPC endpoints, SQLite persistence, and established UI patterns

## Success Criteria

### User Success

- Dashboard provides immediate inventory overview without browsing individual bottles
- Clicking any summary element navigates to a filtered inventory view of those bottles
- Post-MVP: drink-before alerts surface bottles needing attention before they're past their prime

### Technical Success

- Dashboard renders smoothly with hundreds of bottles (target inventory size)
- All data computed client-side from existing `ListBottles` gRPC response (no new server endpoints)
- Follows existing manager patterns: `screen.Ctx` callbacks, `doAsync()` for gRPC calls, Qt6 widgets via miqt

### Measurable Outcomes

- Dashboard loads and renders within 1 second for an inventory of 500 bottles
- All MVP widgets display accurate, up-to-date data on screen open (refreshed from server)
- Interactive drill-down navigates to filtered inventory in a single click

## User Journeys

### Journey 1 — Quick Cellar Check (Happy Path)

You're heading to dinner and want to know what you have. You open the manager, click "Tableau de bord" in the sidebar. Instantly you see 127 bottles in stock, the color breakdown shows mostly rouge (68%), and the designation breakdown reveals your Bordeaux collection dominates. You click the "Bordeaux" segment — the inventory screen opens filtered to Bordeaux bottles. You pick one and head to the cellar.

### Journey 2 — Exploring the Collection (Browsing)

You're curious about how your cellar is composed. You open the dashboard and scan the color distribution — you realize you have very few blancs. You click "blanc" to see which ones you have, then decide to stock up next time you visit a cave.

### Journey 3 — Edge Case — Empty Cellar

You just moved, the cellar is empty. You open the dashboard and see "0 bouteilles en stock" with empty breakdown widgets. The dashboard is still useful — it confirms the state clearly rather than showing a confusing blank screen.

### Journey Requirements Summary

| Capability | Revealed By |
|---|---|
| Stock count widget | All journeys — always visible |
| Color breakdown widget (clickable) | Journeys 1, 2 |
| Designation breakdown widget (clickable) | Journey 1 |
| Navigate to filtered inventory on click | Journeys 1, 2 |
| Graceful empty state | Journey 3 |
| Data refresh on screen open | All journeys |

## Desktop App Specific Requirements

### Project-Type Overview

The dashboard is a new screen within the existing Qt6 manager application. It follows the same patterns as other screens (Inventory, Add Bottles, Read Bottle, Settings) and integrates into the sidebar navigation.

### Platform Support

- **Linux** — primary development platform
- **Windows** — must also run on Windows (Qt6/miqt cross-platform)
- No macOS requirement
- Dashboard must render identically on both platforms (Qt6 handles this natively)

### Technical Architecture Considerations

- Dashboard is a new screen implementing the existing `screen.Ctx` callback pattern
- Data fetched via `ListBottles` gRPC call using the established `doAsync()` async pattern
- All aggregation (counts, breakdowns) computed client-side from the full bottle list
- No new server endpoints or database changes required
- Server unreachability handled by the existing manager-level error notification — no dashboard-specific offline logic needed

### Implementation Considerations

- Follow the existing screen registration pattern (sidebar entry + screen widget)
- Reuse existing gRPC client connection and error handling
- French UI labels ("Tableau de bord", "Bouteilles en stock", color names, etc.)
- Widget layout should use Qt6 layout managers for consistent rendering across Linux and Windows
- Interactive elements (clickable breakdown segments) must trigger navigation to the Inventory screen with appropriate filters applied

## Product Scope

### MVP Strategy & Philosophy

**MVP Approach:** Problem-solving MVP — deliver the minimum dashboard that turns raw inventory data into actionable insight.
**Resource Requirements:** Solo developer, no external dependencies. Builds entirely on existing codebase patterns and gRPC API.

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**
- Quick cellar check (Journey 1) — stock count + breakdown + drill-down
- Collection exploration (Journey 2) — color/designation distribution
- Empty cellar (Journey 3) — graceful empty state

**Must-Have Capabilities:**
1. New "Tableau de bord" sidebar entry and screen
2. Stock count widget (total bottles in stock)
3. Color breakdown widget (rouge, blanc, rosé, effervescent, autre) — clickable
4. Designation breakdown widget (by appellation) — clickable
5. Click-to-filter navigation to Inventory screen
6. Graceful empty state when no bottles in stock
7. Data refresh on screen open via existing `ListBottles` API

### Post-MVP Features

**Phase 2 (Growth):**
- Domain breakdown (by producer)
- Region breakdown (by wine region)
- Cellar value summary (total + by category)
- Consumption trends (bottles consumed per month/year)
- Drink-before alerts (approaching/overdue bottles)

**Phase 3 (Vision):**
- Customizable dashboard layout
- Historical trend charts
- Export/print dashboard summary

### Risk Mitigation Strategy

**Technical Risks:** Low. All data already available via `ListBottles`. Main risk is Qt6 widget layout complexity for breakdown displays — mitigated by keeping MVP to simple count/list widgets before attempting charts.
**Market Risks:** N/A — personal tool.
**Resource Risks:** Minimal — small feature scope, single developer, no external dependencies.

## Functional Requirements

### Dashboard Navigation

- **FR1:** User can navigate to the dashboard screen via a "Tableau de bord" entry in the manager sidebar
- **FR2:** User can return to the dashboard from any other screen via the sidebar

### Inventory Overview

- **FR3:** User can view the total count of bottles currently in stock
- **FR4:** User can view the distribution of in-stock bottles by wine color (rouge, blanc, rosé, effervescent, autre)
- **FR5:** User can view the distribution of in-stock bottles by designation (appellation)

### Interactive Drill-Down

- **FR6:** User can click a color segment in the color breakdown to navigate to the Inventory screen filtered to that color
- **FR7:** User can click a designation entry in the designation breakdown to navigate to the Inventory screen filtered to that designation

### Data Freshness

- **FR8:** Dashboard data is refreshed from the server each time the user navigates to the dashboard screen
- **FR9:** Dashboard displays data derived from the existing `ListBottles` API response (in-stock bottles only)

### Empty State

- **FR10:** User can see a clear, meaningful empty state when no bottles are in stock (zero count, empty breakdowns)

## Non-Functional Requirements

### Performance

- Dashboard screen renders all widgets within 1 second for an inventory of up to 500 bottles
- Navigation from dashboard to filtered Inventory screen completes without perceptible delay
- Client-side aggregation (counting, grouping) does not block the Qt UI thread (use existing `doAsync()` pattern for the gRPC call)

