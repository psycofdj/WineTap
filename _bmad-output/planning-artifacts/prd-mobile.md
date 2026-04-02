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
  - step-e-prd-v2-phone-as-server
  - step-e-prd-v2-flow-simplification
classification:
  projectType: mobile_app_server
  domain: general
  complexity: medium
  projectContext: brownfield
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-winetap-mobile.md
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-04-01.md
  - docs/project-overview.md
  - docs/architecture.md
  - docs/data-models.md
  - docs/api-contracts.md
  - docs/development-guide.md
  - docs/index.md
documentCounts:
  briefs: 1
  research: 0
  brainstorming: 0
  projectDocs: 6
workflowType: 'prd'
project_name: 'winetap-mobile'
user_name: 'Psy'
date: '2026-04-02'
editHistory:
  - date: '2026-04-02'
    changes: 'Simplified consume flow (single button, no post-scan confirmation), made intake fully phone-passive (auto screen switch, zero user interaction), renamed button to Consommer une bouteille'
---

# Product Requirements Document — WineTap Mobile v2

**Author:** Psy
**Date:** 2026-04-02 (v2.1 — simplified flows)
**Previous version:** 2026-04-01 (v2 — phone-as-server)

## Executive Summary

WineTap Mobile is a cross-platform app (iOS + Android) that replaces the dedicated UHF RFID hardware and the Raspberry Pi server in the WineTap cellar management system. The phone becomes the **server, database, and NFC scanner** — the single always-on device in the system. The desktop manager connects to the phone over the local network to manage the wine catalog and handle bottle intake.

The system reduces from three specialized components (desktop manager, Raspberry Pi server, cellar scanner) down to two — **a phone and a desktop manager** — by retiring the RPi server, the Chafon CF-RU5102 UHF reader, and the 24/7 cellar binary entirely.

The app serves two primary flows. The **consume flow** is fully local: the user opens the app, taps "Consommer une bouteille", holds the phone to the tag — the bottle is looked up, marked as consumed, and its details displayed. One button in, one button out ("Terminé"). No network, no desktop, no confirmation gate. The **intake flow** is fully manager-driven: when the desktop initiates an intake, the phone automatically switches to a scan screen — no user action on the phone. The user holds the phone to the tag, the UID is relayed to the manager via polling, and the phone returns to home. The phone has no intake button — the screen only appears when the manager requests it. This coordinated scanning pattern — phone reads the tag, desktop form completes itself — is a novel interaction that no existing wine management app offers.

The target users are hobbyist wine collectors (100–500 bottles) who buy wine online, register bottles at the desktop when deliveries arrive, and pull bottles from the cellar over weeks or months. The system is self-hosted, local-first, subscription-free, and uses commodity NFC tags. Built with Flutter for cross-platform delivery, hosting an HTTP REST server with embedded SQLite database.

### What Makes This Special

- **Phone is the server.** No dedicated hardware, no RPi, no always-on computer. The phone everyone already carries becomes the wine cellar brain. Open the app — the server starts. Simpler to deploy and use for a non-technical persona.
- **Phone as wireless desktop scanner.** The coordinated intake flow combines the editorial power of a desktop form with the physical convenience of a phone NFC tap. No competing product offers this multi-device coordination.
- **No proprietary hardware, no subscription, no cloud.** Commodity NFC tags, data stored on the phone, accessible from the desktop over WiFi. The user is never locked in to a vendor, a tag supplier, or a platform.

## Project Classification

| Dimension | Value |
|-----------|-------|
| Project type | Mobile app (server + NFC scanner) — hosts HTTP REST API, SQLite database, and NFC scanning; desktop manager connects as client |
| Domain | General (wine cellar management, no regulatory requirements) |
| Complexity | Medium — simple domain, medium technical complexity (NFC hardware, HTTP server on phone, multi-device coordination, cross-platform UX) |
| Project context | Brownfield — extends the WineTap Go monorepo; Flutter mobile app replaces RPi server; Go desktop manager becomes HTTP client |

## Success Criteria

### User Success

- **Consume feels instant.** "Consommer une bouteille" → hold to bottle → bottle details shown and marked consumed: under 3 seconds. Two taps total (start + "Terminé"). No network dependency — the server is on the phone itself.
- **Intake feels seamless.** Manager initiates scan → phone auto-switches to scan screen within 2 seconds, zero phone interaction required. From tag read to UID in manager form: under 5 seconds. Phone returns to home automatically after scan.
- **Zero configuration for consume.** Open the app — the server starts, the database is local. No server address, no WiFi discovery needed for consuming bottles.
- **Simple setup for intake.** Manager discovers the phone automatically via mDNS on the local network. Manual IP fallback in settings for edge cases.
- **Dual scanning coexistence.** During transition, the manager supports both RFID (USB) and NFC (via phone), switchable in settings. Both paths produce identical results.

### Business Success

- Both primary users actively using the app for intake and consume within 2 weeks of deployment
- NFC scanning validated as reliable enough to replace RFID — gating post-transition RFID removal
- NFC tag migration (re-tagging existing bottles) completed within one session
- RPi server decommissioned — no dedicated hardware required

### Technical Success

- Same Flutter codebase runs on iOS (14+) and Android (9+) with NFC hardware
- Dart HTTP server (shelf) runs on phone, serves REST API to desktop manager
- SQLite database on phone stores all wine data (designations, domains, cuvees, bottles, events)
- Scan coordination via HTTP REST (manager POSTs request, polls for result)
- NFC UID format normalized (canonical uppercase hex, no separators)
- Manager HTTP client replaces gRPC client, discovers phone via mDNS
- Database backup/restore functional for resilience

### Measurable Outcomes

| Metric | Target | Conditions |
|--------|--------|------------|
| Consume flow latency ("Consommer une bouteille" → bottle details shown) | < 3s | Local server; iPhone XS+ / Android 10+ |
| Intake coordination latency (tag read → UID in manager) | < 5s | Local WiFi, polling interval 500ms |
| Scan request delivery (manager POST → phone auto-switches to scan screen) | < 2s | Local WiFi |
| mDNS discovery success rate (manager → phone) | > 95% first attempt | Home WiFi, phone app running |
| NFC read success rate | > 99% first attempt | NTAG215 on glass bottle side, < 2cm |
| Unknown tag → error displayed | < 2s | |
| Intake timeout → manager cancels | 30s | Configurable |
| Scan cancelled → both sides idle | < 2s | Polling interval |
| HTTP server startup time | < 1s | After app launch |
| Database backup export | < 10s | 500-bottle database |

### Constraints

- French-only UI (consistent with desktop manager; i18n deferred)
- WiFi-only trust model — no authentication (same as current system)
- Consume works offline (local server) — intake requires WiFi (manager must reach phone)
- TestFlight + sideloaded APK distribution only (no App Store for MVP)

## User Journeys

### Journey 1: Marc Consumes a Bottle — The Cellar Moment

**Persona:** Marc, 52, retired engineer, 200-bottle cellar. Tech-comfortable (runs his own NAS). Uses WineTap because he likes knowing exactly what he has.

**Opening scene:** Friday evening. Marc is cooking duck breast and wants a Madiran. He walks to the cellar, pulls a 2019 Château Montus from the rack.

**Rising action:** He opens WineTap Mobile. The app starts instantly — the server and database are right on his phone. The home screen shows a single action: "Consommer une bouteille". He taps it. iOS NFC sheet appears — he holds the phone to the tag on the bottle's side. (He could tap "Annuler" here if he changed his mind before scanning.)

**Climax:** Phone vibrates. The bottle is immediately marked as consumed. Screen shows: "Château Montus — Madiran 2019 — Domaine Brumont — Marquée comme consommée ✓". One button: "Terminé".

**Resolution:** 4 seconds, two taps total. No thought about servers, networks, or databases. Marc taps "Terminé", he's back on the home screen. Later, when the manager syncs, the Montus is gone from inventory.

**Capabilities revealed:** Single-purpose home button ("Consommer une bouteille"). Cancel available before scan, not after. Instant local lookup and consume on tag read (no confirmation gate). Result screen shows cuvée, domain, vintage, appellation.

---

### Journey 2: Marc Registers a Delivery — The Desktop + Phone Dance

**Opening scene:** Marc received 12 bottles — 6 Côtes du Rhône, 6 Cahors. He sits at his desk with the box, NFC tags, manager open, phone on desk with WineTap Mobile showing the home screen.

**Rising action:** The manager discovers the phone on the network automatically (mDNS). Fills in bottle details on the manager (domain, cuvée, designation, vintage, price). Sticks an NFC tag on the first bottle, clicks "Scanner".

**The first scan:** Phone automatically switches to a scan screen — "En attente du scan…" with pulsing indicator. Marc never touches the phone. He holds the phone to the tag. Vibrate, "Tag lu ✓". Phone returns to home. Manager form shows the UID. Clicks "Enregistrer".

**The bulk flow:** Manager offers "Ajouter la même". Marc clicks it. Phone switches to scan screen again — automatically, no touch. Phone enters **continuous scan mode** — NFC stays active between bottles. Phone sits face-up on desk. Marc grabs bottle, sticks tag, holds to phone. Vibrate. Next bottle. Stick, tap. Six bottles in under 2 minutes.

**Physical choreography:** Stick each tag immediately before scanning — never pre-tag.

**Resolution:** Switches to Côtes du Rhône, new cuvée details, repeats. 12 bottles registered. Phone was a scanning pad — Marc never touched it once during intake.

**Capabilities revealed:** Two phone UX states during intake: idle (home) and scanning (auto-triggered by manager). Zero user interaction on phone. Instant scanned→ready transition in continuous mode. Idempotent protocol (duplicate reads ignored). Manager "Ajouter la même" triggers automatic consecutive scan requests. Phone returns to home after each scan cycle.

---

### Journey 3: Marc Hits a Snag — Error Recovery

**Scenario A — Tag already used (intake):** NFC UID already associated with an in-stock bottle. Phone shows "Tag déjà utilisé — [bottle details]". Marc sets it aside, scans the right bottle. Continuous mode stays active.

**Scenario B — Phone unreachable from manager:** WiFi rebooted during intake. Manager shows "Téléphone injoignable". Manager retries when WiFi returns. Desktop form data preserved. Consume still works on phone (local).

**Scenario C — Scan cancelled from desktop:** Marc hits "Annuler" on manager. Phone returns to home automatically. No orphaned state.

**Scenario D — NFC read failure:** Bad angle, read times out. Phone shows "Aucun tag détecté — réessayez". Scan request still active — retry without restart.

**Scenario E — Wrong bottle consumed:** Marc taps "Consommer une bouteille", scans, sees "Saint-Émilion 2018" — but he wanted a different vintage. The bottle is already marked as consumed (no pre-commit confirmation). To reverse, Marc must re-intake the bottle from the manager. Trade-off accepted: simpler flow outweighs rare accidental consumes.

**Scenario F — Duplicate scan in continuous mode (intake):** Same tag read twice. Phone silently ignores duplicate (idempotent). No error shown.

**Scenario G — Consume cancelled before scan:** Marc taps "Consommer une bouteille" then changes his mind. Taps "Annuler" before holding phone to tag. Returns to home. No side effects.

**Capabilities revealed:** Specific, actionable errors. Scan retry without form restart. Graceful cancellation from either device. Form data preserved across failures. Idempotent coordination.

### Journey Requirements Summary

| Capability | Source |
|------------|--------|
| Single-purpose home button ("Consommer une bouteille") | J1 |
| Consume on tag read — no post-scan confirmation gate | J1 |
| Cancel available before scan, not after | J1, J3G |
| Local server — no network dependency for consume | J1 |
| Auto screen switch on manager scan request (no phone interaction) | J2 |
| Continuous scan mode for bulk intake | J2 |
| Immediate feedback on both devices | J2 |
| Stick-then-scan choreography | J2 |
| Phone returns to home after scan cycle | J2 |
| Idempotent scan coordination | J2, J3F |
| Specific, actionable error messages | J3 |
| Scan retry without form restart | J3 |
| Graceful cancellation from either device | J3 |
| Manager reconnection after network loss | J3 |
| Form data preserved across scan failures | J3 |
| Accidental consume reversal via re-intake | J3E |

## Innovation & Novel Patterns

### Multi-Device NFC Coordination

The intake flow uses a phone as a wireless NFC scanner controlled by a desktop application. This "phone as peripheral" pattern has no precedent in wine management apps and is rare in consumer applications generally. It combines the ergonomic advantage of a phone (portable, NFC-equipped) with the editorial advantage of a desktop (keyboard, large screen, complex forms).

### Phone as Server

The phone hosts the entire WineTap backend — HTTP REST API, SQLite database, mDNS registration. No dedicated server hardware required. The desktop manager is a pure client that discovers the phone on the local network. This "phone as infrastructure" pattern eliminates deployment complexity for non-technical users.

### Zero-Touch Phone Intake

The phone requires zero user interaction during the entire intake flow. The manager triggers a scan request; the phone auto-switches to the scan screen, reads the tag, relays the UID, and returns to home — all without a single tap. During bulk intake ("Ajouter la même"), the phone maintains an active NFC session and acts as a scanning pad. Bottles are brought to the phone rather than the phone to bottles — inverting the typical mobile NFC model.

### Competitive Landscape

- **InVintory** — NFC stickers for bottle lookup, phone-only, no desktop coordination
- **CellarTracker** — barcode scanning, phone-only, no desktop coordination
- **No existing product** combines desktop editorial interface with phone NFC scanning in real-time, nor uses the phone as both server and scanner

### Validation Strategy

NFC scanning validated during MVP v1 (Epics 1-4). Phone-as-server is the v2 evolution. Success criteria: all existing consume/intake flows work identically over HTTP REST.

## Mobile App Specific Requirements

### Platform Requirements

| Requirement | iOS | Android |
|-------------|-----|---------|
| Minimum OS | iOS 14+ | Android 9+ (API 28) |
| Minimum device | iPhone 7 (NFC hardware) | Any device with NFC |
| Framework | Flutter | Flutter |
| NFC plugin | `nfc_manager` v4+ | `nfc_manager` v4+ |
| HTTP server | `shelf` (Dart) | `shelf` (Dart) |
| Database | `sqflite` or `drift` (SQLite) | `sqflite` or `drift` (SQLite) |
| Distribution | TestFlight | Sideloaded APK |

### Device Permissions

| Permission | Platform | Purpose |
|------------|----------|---------|
| NFC | iOS | `NFCReaderUsageDescription` in Info.plist; NFC entitlement (requires paid Apple Developer account) |
| NFC | Android | `android.permission.NFC` in AndroidManifest.xml |
| Network | Both | Local network access for HTTP server (iOS: `NSLocalNetworkUsageDescription`) |
| Bonjour | iOS | `NSBonjourServices` for mDNS registration (`_winetap._tcp`) |

No camera, location, or storage permissions required.

### NFC Session Lifecycle

**iOS:** Every read requires an explicit `NFCTagReaderSession` with a system modal sheet. Continuous scan mode restarts sessions between reads. Requires paid Apple Developer account for NFC entitlement.

**Android:** Foreground dispatch delivers tag reads as intents. No system modal. Continuous scan mode naturally supported.

### HTTP Server Lifecycle

Phone runs a Dart HTTP server (`shelf`) that starts when the app launches. The server listens on a configurable port (default 8080) and serves the REST API. During intake, the server must remain active while the app is in use.

### mDNS Service Registration

Phone registers as `_winetap._tcp.local.` via `bonsoir` package. Desktop manager browses for this service. Fallback: manual IP:port in manager settings. 3-second discovery timeout.

## Product Scope & Phased Development

### Strategy

**Approach:** Evolutionary — v1 MVP validated NFC scanning with RPi server. v2 moves the server to the phone, simplifying deployment and eliminating dedicated hardware.

**Resource:** Solo developer. Go expertise (manager), learning Flutter/Dart (phone server). Implications: leverage existing Flutter UI code, build Dart HTTP server and SQLite layer.

### Feature Set

**Mobile app (Flutter, iOS + Android) — server + scanner:**
- HTTP REST server (shelf) with full API (designations, domains, cuvees, bottles, events, completions)
- SQLite database (sqflite/drift) — all wine data stored on phone
- Consume screen: "Consommer une bouteille" → NFC scan → auto-consume → details + "Terminé" (fully local — no network needed)
- Intake listener: receives scan requests from manager via HTTP, auto-switches to scan screen (zero phone interaction), continuous scan mode
- mDNS registration (`_winetap._tcp`) so manager can discover phone
- NFC scanning (single + continuous mode)
- Scan coordination REST endpoints (request, result, cancel)
- Database backup/restore/export
- Error states: unknown tag, tag in use, NFC failure, timeout

**Manager (Go/Qt) — HTTP client:**
- HTTP client connecting to phone (replaces gRPC client)
- mDNS discovery of phone (replaces RPi discovery)
- Dual scanning backend: RFID (USB) + NFC (via phone HTTP polling)
- Settings toggle for scan mode
- All catalog/inventory management screens (unchanged)

### Suggested Build Order

1. **Phone SQLite database** — schema matching current Go DB, migrations
2. **Phone HTTP server (shelf)** — embedded in Flutter app, starts on launch
3. **Catalog REST API** — designations, domains, cuvees CRUD
4. **Bottle REST API** — add, list, consume, get-by-tag, update, delete, set-tag
5. **Consume flow migration** — local HTTP calls instead of gRPC
6. **Scan coordination REST endpoints** — request, result, cancel + polling
7. **Manager HTTP client migration** — replace gRPC with HTTP, mDNS discovery of phone
8. **Intake flow migration** — manager polling, phone scan request queue
9. **Data resilience** — backup, restore, import from RPi database
10. **Integration testing** — end-to-end consume and intake over HTTP

### Post-Transition

- Remove RFID support (cfru5102 driver, USB integration, settings toggle)
- Decommission RPi server and cellar binary
- Remove gRPC dependencies from manager and phone

### Growth Features

- Inventory browsing on phone (read-only list with search)
- Drink-before notifications (local push)
- Bottle detail view on scan
- Scan history
- Share cellar view with dinner guests via local network
- App Store / Play Store distribution

## Functional Requirements

### NFC Tag Scanning

- FR1: User can read an NFC tag UID by holding the phone to a tagged bottle
- FR2: System normalizes NFC tag UIDs to a canonical format (uppercase hex, no separators) regardless of platform
- FR3: User can initiate a consume NFC scan via "Consommer une bouteille" on the home screen; user can cancel before a tag is read
- FR4: User can enter continuous scan mode where the phone stays NFC-ready for rapid consecutive scans
- FR5: System silently ignores duplicate reads of the same tag within a single scan session (idempotent)

### Consume Flow

- FR6: User can scan a bottle's NFC tag to look up the associated in-stock bottle via the local HTTP server
- FR7: System marks the bottle as consumed immediately upon successful tag read — no post-scan confirmation gate
- FR8: System displays bottle details (cuvée, domain, vintage, appellation) as post-consume feedback with a single "Terminé" button to return to home
- FR9: User can reverse an accidental consume by re-registering the bottle via the manager intake flow
- FR10: System displays a specific error when the scanned tag is not associated with any in-stock bottle

### Intake Coordination

- FR11: Manager can initiate a scan request by sending a request to the phone's server
- FR12: Mobile app automatically switches to the scan screen and initiates NFC when the server receives a scan request — no user interaction on the phone
- FR13: Phone returns to the home screen after relaying the scanned tag UID or when the manager cancels the request
- FR14: Manager retrieves the scanned tag UID by querying the phone's server for the scan result
- FR15: Manager can initiate consecutive scan requests for bulk intake ("Ajouter la même") without re-filling the form
- FR16: Mobile app enters continuous scan mode during bulk intake — no user action on the phone at any point (screen auto-switches, NFC stays active between reads)
- FR17: Manager can cancel a pending scan request via HTTP POST, returning both devices to idle
- FR18: System enforces a configurable timeout (default 30s) on pending scan requests, notifying the manager and returning both devices to idle
- FR19: Scan requests survive phone-side errors (NFC read failure, user cancel) and can be retried without restarting the desktop form
- FR19b: Pending scan requests from the manager take priority over an active consume scan — the phone interrupts consume, switches to intake mode, and the user can re-initiate consume after intake completes
- FR19c: The intake scan screen displays a label identifying the flow as intake (e.g., "Ajout en cours — Scannez le tag pour le manager"), distinguishing it from consume scanning

### Phone Server & Database

- FR20: Phone hosts an HTTP REST server that starts automatically when the app launches
- FR21: Phone stores all wine data (designations, domains, cuvees, bottles, events) in a local SQLite database
- FR22: Phone registers as a discoverable mDNS service (`_winetap._tcp`) on the HTTP port
- FR23: Phone REST API provides full CRUD for designations, domains, cuvees, and bottles
- FR24: Phone REST API provides event push and subscription endpoints
- FR25: Phone REST API provides autocompletion endpoints

### Manager Connection

- FR26: Manager discovers the phone automatically via mDNS on the local network
- FR27: User can manually configure the phone address (IP:port) in manager settings as a fallback
- FR28: Manager caches the last-known phone address to expedite reconnection
- FR29: Manager displays a clear connection state indicator (connected, connecting, unreachable)

### Error Handling

- FR30: System displays specific, actionable error messages for: unknown tag, tag already in use, phone unreachable, scan timeout, NFC read failure
- FR31: System preserves desktop form data across all scan failures
- FR32: System provides clear recovery guidance (e.g., "réessayez", "vérifiez votre connexion WiFi")

### Manager Dual Scanning

- FR33: Manager supports two scanning backends: RFID (USB) and NFC (via phone HTTP)
- FR34: User can switch between RFID and NFC scanning mode via a setting
- FR35: Both scanning backends produce identical results across all operations

### Data Resilience

- FR36: User can export the phone's SQLite database as a backup file
- FR37: User can restore the database from a backup file
- FR38: User can import an existing RPi server database into the phone (migration tool)

## Non-Functional Requirements

### Performance

- NFR1: Consume flow: "Consommer une bouteille" → bottle details displayed (consumed) in < 3s (local server, excluding iOS NFC sheet)
- NFR2: Intake coordination: tag read → UID in manager in < 5s (WiFi, 500ms polling)
- NFR3: Scan request delivery: manager POST → phone displays prompt in < 2s
- NFR4: App cold start to ready state (server + database) in < 3s on iPhone XS+ / Android 10+
- NFR5: Continuous scan: < 500ms between reads (Android); < 1.5s (iOS, including session restart)
- NFR6: mDNS discovery (manager → phone) completes within 3s; falls back to cached address on timeout
- NFR7: HTTP server startup in < 1s after app launch

### Reliability

- NFR8: Manager HTTP client auto-recovers after WiFi reconnection within 5s of network availability
- NFR9: Intake scan requests survive phone-side NFC failures — retry without form restart
- NFR10: No data loss on manager side during any scan failure, timeout, or cancellation
- NFR11: Phone database survives app restart, phone restart, and OS updates

### Integration

- NFR12: NFC UID reading works on both iOS (Core NFC) and Android (foreground dispatch) via single Flutter plugin
- NFR13: mDNS service type `_winetap._tcp` discoverable by manager (Go mDNS browser)
- NFR14: Scan coordination protocol is idempotent — duplicate reads produce no side effects
- NFR15: REST API returns JSON; manager parses standard JSON responses

### Data Resilience

- NFR16: Database backup export completes in < 10s for a 500-bottle database
- NFR17: Database restore is atomic — partial restore does not corrupt data
- NFR18: Migration from RPi database preserves all bottle, cuvee, domain, and designation data

## Risk Mitigation

| Risk | Severity | Mitigation |
|------|----------|------------|
| NFC plugin reliability | Medium | Already validated in MVP v1. `flutter_nfc_kit` as backup. |
| iOS continuous scan mode infeasible | Medium | Android-first for continuous mode; iOS falls back to per-scan "Prêt à scanner". |
| iOS NFC requires paid Apple Developer account | Medium | Android is primary target. iOS support deferred until paid account available. |
| Dart HTTP server performance | Low | `shelf` is production-tested. SQLite queries are simple. 500-bottle scale is trivial. |
| Phone battery drain from HTTP server | Medium | Server only active while app is open. Foreground-only for MVP. |
| SQLite on phone — data loss risk | High | Backup/restore feature (Epic 9). Export to desktop for redundancy. |
| Manager polling latency vs bidi stream | Medium | 500ms polling interval. < 2s delivery target. Acceptable for intake UX. |
| mDNS unreliable on some routers | Medium | Manual IP fallback + cached phone address. Same mitigation as v1. |
| Solo Flutter learning curve | Low | UI code preserved from v1. New work is Dart HTTP server + SQLite layer. |
| Accidental consume (no post-scan undo) | Low | Cancel available before scan. Post-scan reversal via re-intake from manager. Rare scenario — user physically holds bottle while scanning. |
