# Sprint Change Proposal — Phone as Server

**Date:** 2026-04-01
**Author:** Psy
**Status:** Approved

## Issue Summary

**Trigger**: Post-MVP strategic decision to simplify deployment by eliminating the Raspberry Pi server. The phone becomes the HTTP REST server with embedded SQLite database. The desktop manager connects to the phone over the local network.

**Rationale**: A phone is always available, simpler for non-technical users, requires no dedicated hardware. The RPi added deployment complexity that doesn't match the target persona (hobbyist wine collector, 100-500 bottles).

**Evidence**: MVP validated NFC scanning works (Epics 1-4 complete, 14 stories). Technology risk resolved. System architecture can now be simplified.

## Impact Analysis

### Epic Impact

| Epic | Status | Impact |
|------|--------|--------|
| Epic 1: Tag ID Modernization | done | No change — proto rename + NFC seed tool still valid |
| Epic 2: Consume a Bottle by Phone | done | Major rework — gRPC → local HTTP, mDNS removed |
| Epic 3: Scan Coordination — Server & Manager | done | Replace entirely — bidi stream → REST polling |
| Epic 4: Coordinated Intake by Phone | done | Major rework — bidi stream → polling |

### Artifact Conflicts

**PRD**: Server topology reverses from standalone RPi to embedded in phone. "No offline mode" constraint changes (consume is always local). "Foreground-only" needs revision for background HTTP server during intake.

**Architecture**: gRPC → HTTP REST. Bidi streaming → polling. SQLite moves from RPi to phone. mDNS registration flips (phone registers, manager discovers). Proto definitions become data model reference only (JSON over HTTP).

**UX**: Consume flow simplifies (no connection to remote server). Intake adds phone mDNS discovery from manager. New backup/restore screens.

### Technical Impact

**Transport**: gRPC replaced by HTTP REST (Dart `shelf` package on phone, Go `net/http` client on manager).

**Coordination**: Bidi stream replaced by REST endpoints + manager polling:
- `POST /scan/request` — manager initiates scan
- `GET /scan/result` — manager polls for tag
- `POST /scan/cancel` — manager cancels

**Database**: SQLite moves from RPi (`modernc.org/sqlite`) to phone (`sqflite` or `drift`).

**Discovery**: Phone registers `_winetap._tcp` via bonsoir. Manager discovers phone.

## Recommended Approach

**Hybrid: Direct Adjustment + Partial Rollback**

- **Keep** (~60%): All UI screens, NFC service, Provider state machines, Scanner interface, Go manager UI, string localization, NormalizeTagID
- **Remove**: gRPC server, gRPC clients, bidi stream coordination, proto generated code, cellar binary, server mDNS (Go)
- **Build new**: Dart HTTP server, SQLite on phone, REST API, scan coordination endpoints, manager HTTP client, phone mDNS, backup/restore

**Effort**: High — 5 new epics, ~17 stories
**Risk**: Medium — well-understood patterns (HTTP REST, SQLite), existing UI/NFC code survives
**Timeline**: Comparable to original MVP cycle

## New Epic Structure

### Epic 5: Phone HTTP Server & Database
| Story | Description |
|-------|-------------|
| 5.1 | SQLite database setup on phone — schema matching current Go DB |
| 5.2 | HTTP server (shelf) embedded in Flutter app, starts on app launch |
| 5.3 | Catalog REST API — designations, domains, cuvees CRUD |
| 5.4 | Bottle REST API — add, list, consume, get-by-tag, update, bulk-update, delete, set-tag |
| 5.5 | Phone mDNS registration + background server lifecycle |

### Epic 6: Consume Flow Migration
| Story | Description |
|-------|-------------|
| 6.1 | Replace GrpcClient with local HTTP client service |
| 6.2 | Update ScanProvider + ConsumeScreen for HTTP |
| 6.3 | Remove gRPC dependencies and generated proto code |

### Epic 7: Intake Coordination via HTTP
| Story | Description |
|-------|-------------|
| 7.1 | Scan coordination REST endpoints on phone server |
| 7.2 | Update IntakeProvider — replace bidi stream with polling |
| 7.3 | Phone-side scan request queue + NFC trigger on pending request |

### Epic 8: Manager HTTP Migration
| Story | Description |
|-------|-------------|
| 8.1 | Manager HTTP client + mDNS discovery of phone |
| 8.2 | Manager catalog screens rewired for HTTP |
| 8.3 | Manager NFCScanner rewritten for HTTP polling |
| 8.4 | Manager inventory/intake screens updated |

### Epic 9: Data Resilience
| Story | Description |
|-------|-------------|
| 9.1 | SQLite backup export from phone (JSON or SQL dump) |
| 9.2 | Restore/import on phone |
| 9.3 | Migration tool — import existing RPi database into phone |

## Implementation Handoff

**Scope**: Major — fundamental replan required.

**Handoff sequence**:
1. `bmad-edit-prd` — Update PRD for phone-as-server topology
2. `bmad-create-architecture` — New architecture decisions (HTTP, SQLite on phone, polling coordination)
3. `bmad-create-epics-and-stories` — Generate Epics 5-9 with BDD acceptance criteria
4. `bmad-sprint-planning` — New sprint status
5. `bmad-create-story` → `bmad-dev-story` → `bmad-code-review` — Implementation cycle

**Success criteria**: Phone runs HTTP server with full API parity. Manager connects via HTTP. Consume works locally on phone. Intake works via polling. Database backup/restore functional.
