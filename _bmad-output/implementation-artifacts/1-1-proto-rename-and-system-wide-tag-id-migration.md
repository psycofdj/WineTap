# Story 1.1: Proto Rename and System-Wide Tag ID Migration

Status: done

## Story

As a developer,
I want all references to `rfid_epc` renamed to `tag_id` across proto, database, and all Go components,
So that the system uses universal tag naming that supports both UHF RFID and NFC tags.

## Acceptance Criteria

1. **Given** the proto file `winetap.proto`
   **When** the rename is applied
   **Then** all `rfid_epc` fields are renamed to `tag_id` across all messages
   **And** `GetBottleByEPC` RPC is renamed to `GetBottleByTagId` with updated request/response type names
   **And** `buf lint` passes
   **And** `make proto` regenerates Go code without errors

2. **Given** a new SQL migration `0002_rename_rfid_epc.sql`
   **When** the server starts
   **Then** the `bottles.rfid_epc` column is renamed to `tag_id`
   **And** the UNIQUE constraint is preserved on non-null values

3. **Given** the server service layer (`bottles.go`, `convert.go`)
   **When** updated for `tag_id`
   **Then** `AddBottle`, `ConsumeBottle`, `GetBottleByTagId`, `ListBottles` all use `tag_id`
   **And** all existing server tests pass

4. **Given** the server db layer (`db/bottles.go`)
   **When** updated for `tag_id`
   **Then** all SQL queries reference the `tag_id` column

5. **Given** the manager code (`rfid.go`, `inventory_form.go`, `inventory.go`)
   **When** updated for `tag_id`
   **Then** the manager builds and runs without errors
   **And** RFID scanning still works (functional regression)

6. **Given** the cellar binary (`internal/cellar/cellar.go`, `cmd/cellar/main.go`)
   **When** updated for `tag_id`
   **Then** the cellar builds, runs, and consumes bottles via RFID as before

7. **Given** all components are updated
   **When** `make build` is run
   **Then** all three binaries (server, cellar, manager) compile without errors

## Tasks / Subtasks

- [x] Task 1: Proto rename (AC: #1)
  - [x] Rename `rfid_epc` -> `tag_id` in all messages in `proto/winetap/v1/winetap.proto`
  - [x] Rename `GetBottleByEPC` RPC -> `GetBottleByTagId`
  - [x] Rename `GetBottleByEPCRequest` message -> `GetBottleByTagIdRequest`
  - [x] Update all comments referencing EPC -> tag ID
  - [x] Run `buf lint` and `make proto` to regenerate Go code
- [x] Task 2: SQL migration (AC: #2)
  - [x] Create `internal/migrations/0002_rename_rfid_epc.sql`
  - [x] Register migration in `internal/migrations/migrations.go` (N/A — embed.FS auto-embeds all .sql files)
- [x] Task 3: DB layer update (AC: #4)
  - [x] Rename `RFIDEPC` struct field -> `TagID` in `internal/server/db/bottles.go`
  - [x] Update all SQL queries from `rfid_epc` -> `tag_id`
  - [x] Rename `GetBottleByEPC` method -> `GetBottleByTagId`
- [x] Task 4: Service layer update (AC: #3)
  - [x] Update `internal/server/service/bottles.go` — all `req.RfidEpc` -> `req.TagId`, method rename
  - [x] Update `internal/server/service/convert.go` — proto field mapping
  - [x] Update error messages and log fields from "EPC" -> "tag ID"
  - [x] Run server tests
- [x] Task 5: Manager update (AC: #5)
  - [x] Update `internal/manager/screen/inventory.go` — `RfidEpc` -> `TagId` field refs
  - [x] Update `internal/manager/screen/inventory_form.go` — `RfidEpc` -> `TagId` field refs
  - [x] Update `internal/manager/rfid.go` — no proto field references found (only local vars)
  - [x] Build manager
- [x] Task 6: Cellar update (AC: #6)
  - [x] Update `internal/cellar/cellar.go` — `RfidEpc` -> `TagId` in ConsumeBottleRequest
  - [x] Build cellar
- [x] Task 7: Full build verification (AC: #7)
  - [x] Run `make build` — all three binaries compile
  - [x] Run all Go tests (`go test ./...`)

### Review Findings

- [x] [Review][Patch] Fix `TagID` struct field whitespace alignment [internal/server/db/bottles.go:13]
- [x] [Review][Patch] Update cellar slog key from `"epc"` to `"tag_id"` [internal/cellar/cellar.go:100]
- [x] [Review][Defer] `GetBottleByTagId` uses proto-style `TagId` not Go-idiomatic `TagID` — proto convention propagates, not fixable without breaking generated code
- [x] [Review][Defer] `docs/api-contracts.md` still references `rfid_epc` and `GetBottleByEPC` — pre-existing docs, out of story scope
- [x] [Review][Defer] `docs/data-models.md` still references `rfid_epc` — pre-existing docs, out of story scope
- [x] [Review][Defer] `docs/architecture.md` still references `rfid_epc` and `GetBottleByEPC` — pre-existing docs, out of story scope

## Dev Notes

### Execution Order

This is a pure rename — no behavioral changes. The order matters because generated code must exist before consuming code compiles:

1. **Proto first** — edit `.proto`, run `make proto` to regenerate `gen/`
2. **DB layer** — rename struct field and SQL references
3. **Migration** — create new migration file and register it
4. **Service layer** — update to use new DB method names and proto field names
5. **Manager + cellar** — update proto field references
6. **Full build + test** — `make build` then `go test ./...`

### Critical: SQLite Column Rename

SQLite `ALTER TABLE ... RENAME COLUMN` is supported since SQLite 3.25.0 (2018-09-15). The migration should be:

```sql
ALTER TABLE bottles RENAME COLUMN rfid_epc TO tag_id;
```

This preserves the existing UNIQUE constraint. No need to recreate the table. The initial migration at `internal/migrations/0001_initial.sql` defines the column as `rfid_epc TEXT UNIQUE` — the rename carries the constraint forward.

### Exact Files to Modify and What Changes

**Proto (1 file):**
| File | Changes |
|---|---|
| `proto/winetap/v1/winetap.proto` | 5 field renames (`rfid_epc` -> `tag_id`), 1 RPC rename (`GetBottleByEPC` -> `GetBottleByTagId`), 1 message rename (`GetBottleByEPCRequest` -> `GetBottleByTagIdRequest`), update comments |

**Generated (auto — do NOT edit manually):**
| File | Action |
|---|---|
| `gen/winetap/v1/winetap.pb.go` | Regenerated by `make proto` |
| `gen/winetap/v1/winetap_grpc.pb.go` | Regenerated by `make proto` |

**DB layer (1 file):**
| File | Changes |
|---|---|
| `internal/server/db/bottles.go` | Struct field `RFIDEPC` -> `TagID`, all SQL `rfid_epc` -> `tag_id`, method `GetBottleByEPC` -> `GetBottleByTagId`, comment updates |

**Migrations (2 files):**
| File | Changes |
|---|---|
| `internal/migrations/0002_rename_rfid_epc.sql` | NEW — `ALTER TABLE bottles RENAME COLUMN rfid_epc TO tag_id;` |
| `internal/migrations/migrations.go` | Register `0002_rename_rfid_epc.sql` in the migration list |

**Service layer (2 files):**
| File | Changes |
|---|---|
| `internal/server/service/bottles.go` | `req.RfidEpc` -> `req.TagId`, `s.db.GetBottleByEPC` -> `s.db.GetBottleByTagId`, `s.db.ConsumeBottle` (param rename in logs/errors), method `GetBottleByEPC` -> `GetBottleByTagId`, error strings "EPC" -> "tag ID", log field `"epc"` -> `"tag_id"` |
| `internal/server/service/convert.go` | `pb.RfidEpc` -> `pb.TagId`, `b.RFIDEPC` -> `b.TagID` |

**Manager (3 files):**
| File | Changes |
|---|---|
| `internal/manager/screen/inventory.go` | `RfidEpc` -> `TagId` (lines ~649, 945, 956, 959, 979) |
| `internal/manager/screen/inventory_form.go` | `b.RfidEpc` -> `b.TagId` (lines ~196-197) |
| `internal/manager/rfid.go` | Any proto field references using `RfidEpc` |

**Cellar (1 file):**
| File | Changes |
|---|---|
| `internal/cellar/cellar.go` | `RfidEpc: epc` -> `TagId: epc` in ConsumeBottleRequest (line ~102) |

### Proto Field Rename Details

In the proto file, these specific fields and messages need renaming:

```protobuf
// Bottle message — field 2
optional string rfid_epc = 2;  -->  optional string tag_id = 2;

// AddBottleRequest — field 1
string rfid_epc = 1;  -->  string tag_id = 1;

// ConsumeBottleRequest — field 1
string rfid_epc = 1;  -->  string tag_id = 1;

// GetBottleByEPCRequest — rename message AND field
message GetBottleByEPCRequest  -->  message GetBottleByTagIdRequest
string rfid_epc = 1;  -->  string tag_id = 1;

// RPC
rpc GetBottleByEPC(GetBottleByEPCRequest) returns (Bottle);
-->
rpc GetBottleByTagId(GetBottleByTagIdRequest) returns (Bottle);

// Comments: "rfid_epc" -> "tag_id", "EPC" -> "tag ID"
```

**Field numbers are preserved** — this is a name-only rename, so wire format is unchanged. However, since this is a monorepo where all consumers are updated simultaneously, wire compatibility is not a concern.

### Go Generated Code Mapping

After `make proto`, the generated Go code will change:
- `RfidEpc` fields on proto structs become `TagId`
- `GetBottleByEPC` method on gRPC client/server interfaces becomes `GetBottleByTagId`
- `GetBottleByEPCRequest` type becomes `GetBottleByTagIdRequest`

All consuming Go code must use these new names after regeneration.

### Migration Registration

Check `internal/migrations/migrations.go` for the pattern used to register migrations. The existing `0001_initial.sql` is embedded/registered there. Follow the exact same pattern for `0002_rename_rfid_epc.sql`.

### Logging Convention

All logging uses `log/slog`. When updating log fields, use `"tag_id"` as the key (not `"epc"`):

```go
s.log.Info("bottle consumed", "bottle_id", b.ID, "tag_id", req.TagId)
```

### What NOT to Change

- **Do NOT rename local Go variables** named `epc` in `rfid.go` or `cellar.go` — these are internal variables, not API surface. The variable name `epc` is fine; only proto field references (`RfidEpc` -> `TagId`) and DB column references (`rfid_epc` -> `tag_id`) must change.
- **Do NOT modify `0001_initial.sql`** — the initial migration stays as-is; the rename happens in a new migration.
- **Do NOT add any new functionality** — this is a pure rename story. No NFC support, no new RPCs, no new endpoints.
- **Do NOT manually edit files in `gen/`** — these are regenerated by `make proto`.

### Project Structure Notes

- Build system: `make proto` runs `buf generate` for Go proto generation
- Three binaries: `cmd/server`, `cmd/cellar`, `cmd/manager`
- `make build` compiles all three into `bin/`
- Tests: `go test ./...` from project root

### References

- [Source: proto/winetap/v1/winetap.proto] — field definitions lines 68-71, 252, 261, 277; RPC line 141
- [Source: internal/server/db/bottles.go] — struct field line 13, SQL queries lines 31, 68, 93-100, 156-164
- [Source: internal/server/service/bottles.go] — service methods lines 17, 28, 35, 43-52, 81-92
- [Source: internal/server/service/convert.go] — proto conversion line 62
- [Source: internal/manager/screen/inventory.go] — proto field refs lines 649, 945, 956, 959, 979
- [Source: internal/manager/screen/inventory_form.go] — proto field refs lines 196-197
- [Source: internal/cellar/cellar.go] — ConsumeBottleRequest line 102
- [Source: internal/migrations/0001_initial.sql] — column definition line 29
- [Source: _bmad-output/planning-artifacts/architecture-mobile.md] — cross-cutting concern #1, implementation sequence step 1
- [Source: _bmad-output/planning-artifacts/epics-mobile.md] — Epic 1, Story 1.1 acceptance criteria

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- All `rfid_epc` fields renamed to `tag_id` across proto (5 fields), 1 RPC rename, 1 message type rename
- `buf lint` passes, `make proto` regenerates Go code cleanly
- New migration `0002_rename_rfid_epc.sql` uses `ALTER TABLE ... RENAME COLUMN` (SQLite 3.25+)
- DB layer: struct field `RFIDEPC` -> `TagID`, method `GetBottleByEPC` -> `GetBottleByTagId`, all SQL updated
- Service layer: all proto field refs, error messages, and log fields updated
- Manager: 5 proto field references updated across inventory.go and inventory_form.go; rfid.go had no proto refs
- Cellar: ConsumeBottleRequest field updated
- `make build` compiles all 3 binaries, `go test ./...` passes with 0 failures
- Verified zero remaining `RfidEpc`/`rfid_epc`/`GetBottleByEPC` references in non-generated code

### Change Log

- 2026-03-30: Proto rename rfid_epc -> tag_id across all components (pure rename, no behavioral changes)

### File List

- proto/winetap/v1/winetap.proto (modified)
- gen/winetap/v1/winetap.pb.go (regenerated)
- gen/winetap/v1/winetap_grpc.pb.go (regenerated)
- internal/migrations/0002_rename_rfid_epc.sql (new)
- internal/server/db/bottles.go (modified)
- internal/server/service/bottles.go (modified)
- internal/server/service/convert.go (modified)
- internal/manager/screen/inventory.go (modified)
- internal/manager/screen/inventory_form.go (modified)
- internal/cellar/cellar.go (modified)
