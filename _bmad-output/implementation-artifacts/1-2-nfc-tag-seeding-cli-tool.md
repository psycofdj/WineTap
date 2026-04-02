# Story 1.2: NFC Tag Seeding CLI Tool

Status: done

## Story

As a developer,
I want a CLI tool that associates an NFC tag UID with an existing bottle,
So that I can re-tag bottles with NFC tags for testing and migration without needing the full intake flow.

## Acceptance Criteria

1. **Given** a new binary `cmd/nfc_seed/main.go`
   **When** run as `./bin/winetap-nfc-seed --server localhost:50051 --bottle-id 42 --tag-id 04A32BFF`
   **Then** it normalizes the tag_id (uppercase hex, no separators)
   **And** connects to the server via gRPC and updates the bottle's `tag_id`
   **And** prints confirmation: bottle ID, normalized tag_id, cuvee name

2. **Given** the tag_id is already in use by another in-stock bottle
   **When** the tool attempts to set it
   **Then** it displays an error with the conflicting bottle's details
   **And** does not modify either bottle

3. **Given** the bottle ID does not exist
   **When** the tool is run
   **Then** it displays a clear "bottle not found" error

4. **Given** the tag_id input contains colons, spaces, dashes, or lowercase
   **When** the tool normalizes it
   **Then** all separators are stripped and the result is uppercase hex (e.g., "04:a3:2b:ff" -> "04A32BFF")

5. **Given** the `Makefile`
   **Then** a `build-nfc-seed` target exists that produces `bin/winetap-nfc-seed`

## Tasks / Subtasks

- [x] Task 1: Add `SetBottleTagId` RPC to proto and regenerate (AC: #1, #2, #3)
  - [x] Add `SetBottleTagIdRequest` message (bottle_id int64, tag_id string) and `rpc SetBottleTagId` to proto
  - [x] Run `buf lint` and `make proto` to regenerate Go code
- [x] Task 2: Implement `NormalizeTagID` function with tests (AC: #4)
  - [x] Create `internal/server/service/tagid.go` with `NormalizeTagID(raw string) string`
  - [x] Create `internal/server/service/tagid_test.go` with test cases: colons, spaces, dashes, lowercase, mixed, already-normalized, empty string
- [x] Task 3: Implement `SetBottleTagId` server method (AC: #1, #2, #3)
  - [x] Add method to `internal/server/service/bottles.go`
  - [x] Normalize tag_id via `NormalizeTagID` before any DB operations
  - [x] Check for conflict: call `db.GetBottleByTagId(normalizedTagID)` — if found AND it's a different bottle, return ALREADY_EXISTS with conflicting bottle details
  - [x] Check bottle exists: call `db.GetBottleByID(req.BottleId)` — if not found, return NOT_FOUND
  - [x] Set tag_id: call `db.UpdateBottleFields(req.BottleId, []FieldUpdate{{Col: "tag_id", Val: normalizedTagID}})`
  - [x] Return the updated bottle
- [x] Task 4: Create CLI binary (AC: #1)
  - [x] Create `cmd/nfc_seed/main.go` with flags: `--server` (default "localhost:50051"), `--bottle-id` (required), `--tag-id` (required)
  - [x] Connect to server via gRPC (insecure, like cellar pattern)
  - [x] Call `SetBottleTagId` RPC
  - [x] Print confirmation: bottle ID, normalized tag_id, cuvee name (from returned Bottle)
  - [x] Print errors with actionable messages for NOT_FOUND and ALREADY_EXISTS
- [x] Task 5: Makefile target (AC: #5)
  - [x] Add `build-nfc-seed` target producing `bin/winetap-nfc-seed`
  - [x] Add `build-nfc-seed` to the `build` meta-target
- [x] Task 6: Full build and test verification
  - [x] Run `make build` — all 4 binaries compile (including new nfc-seed)
  - [x] Run `go test ./...` — all tests pass including TestNormalizeTagID

### Review Findings

- [x] [Review][Patch] CLI dereferences `resp.TagId` (`*string`) without nil guard [cmd/nfc_seed/main.go:69]
- [x] [Review][Patch] AC2: Conflict error should include bottle's cuvee details, not just ID [internal/server/service/bottles.go:138]
- [x] [Review][Patch] `SetBottleTagId` should catch UNIQUE constraint violation on `UpdateBottleFields` as AlreadyExists [internal/server/service/bottles.go:155]
- [x] [Review][Defer] `NormalizeTagID` does not validate hex-only content — architecture spec only requires strip+uppercase
- [x] [Review][Defer] `NormalizeTagID` does not strip tabs/null bytes — only specified separators (colons, spaces, dashes)
- [x] [Review][Defer] No tag ID length validation — not specified in story, deferred to hardware integration

## Dev Notes

### Approach: New dedicated RPC

The epic spec explicitly says to avoid `UpdateBottle` RPC due to FieldMask limitations — `BottleFields` does not include `tag_id` (only `cuvee_id`, `vintage`, `description`, `purchase_price`, `drink_before`). Instead, add a new `SetBottleTagId` RPC that uses the existing `db.UpdateBottleFields` method with `FieldUpdate{Col: "tag_id", Val: normalizedTagID}`.

### NormalizeTagID Function

This function is specified in the architecture doc and will be reused by later stories (3.2 server-side normalization, Dart equivalent). Place it in `internal/server/service/tagid.go` per architecture spec.

```go
// NormalizeTagID strips separators (colons, spaces, dashes) and uppercases.
func NormalizeTagID(raw string) string {
    // strip ':', ' ', '-'
    // strings.ToUpper
}
```

Test cases (must match the Dart test cases in future story 2.2):

| Input | Output |
|---|---|
| `"04:a3:2b:ff"` | `"04A32BFF"` |
| `"04 a3 2b ff"` | `"04A32BFF"` |
| `"04-a3-2b-ff"` | `"04A32BFF"` |
| `"04a32bff"` | `"04A32BFF"` |
| `"04A32BFF"` | `"04A32BFF"` |
| `"04:A3:2B:FF"` | `"04A32BFF"` |
| `""` | `""` |

### Proto Changes

Add to `winetap.proto` in the WineTap service block:

```protobuf
// SetBottleTagId associates a tag ID with an existing bottle.
// Returns ALREADY_EXISTS if the tag ID is in use by another in-stock bottle.
// Returns NOT_FOUND if the bottle does not exist.
rpc SetBottleTagId(SetBottleTagIdRequest) returns (Bottle);
```

Add new message:

```protobuf
message SetBottleTagIdRequest {
  int64  bottle_id = 1;
  string tag_id    = 2;
}
```

### SetBottleTagId Service Method Logic

```
1. Normalize tag_id via NormalizeTagID()
2. If normalized tag_id is empty -> return INVALID_ARGUMENT
3. Check conflict: db.GetBottleByTagId(normalized)
   - If found AND found.ID != req.BottleId -> return ALREADY_EXISTS with bottle details
4. Check bottle exists: db.GetBottleByID(req.BottleId)
   - If not found -> return NOT_FOUND
5. Update: db.UpdateBottleFields(req.BottleId, [{Col: "tag_id", Val: normalized}])
6. Return updated bottle
```

### CLI Binary Pattern

Follow `cmd/cellar/main.go` as reference for gRPC connection, but much simpler — no config file, no signal handling, just flags and a single RPC call.

```go
func main() {
    server := flag.String("server", "localhost:50051", "gRPC server address")
    bottleID := flag.Int64("bottle-id", 0, "bottle ID to tag")
    tagID := flag.String("tag-id", "", "NFC tag UID")
    flag.Parse()
    // validate required flags
    // connect gRPC (insecure)
    // call SetBottleTagId
    // print result or error
}
```

gRPC connection pattern (from cellar):
```go
conn, err := grpc.NewClient(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
client := v1.NewWineTapClient(conn)
```

### Error Output Format

- **Success:** `Bottle #42: tag_id set to 04A32BFF (Château Montus — Madiran 2019)`
- **Not found:** `Error: bottle 42 not found`
- **Conflict:** `Error: tag ID 04A32BFF is already in use by bottle #17 (Saint-Émilion 2018)`

### Logging

The CLI tool uses `fmt.Fprintf(os.Stderr, ...)` for errors and `fmt.Printf(...)` for output — no slog needed for a simple CLI tool. The server-side `SetBottleTagId` method uses `log/slog` like all other service methods.

### What NOT to Do

- Do NOT add `tag_id` to `BottleFields` proto message — this would allow tag reassignment via the regular UpdateBottle RPC
- Do NOT add a config file — flags are sufficient for a utility tool
- Do NOT add batch/CSV support — single bottle per invocation, keep it simple
- Do NOT add NFC reading — this tool takes a tag ID string, not an NFC reader

### Previous Story Intelligence

Story 1.1 completed the `rfid_epc` -> `tag_id` rename across all components. Key learnings:
- Proto field `tag_id` is `optional string` on Bottle (field 2), `string` on request messages
- DB column is `tag_id TEXT UNIQUE` — UNIQUE constraint exists
- `db.UpdateBottleFields` supports arbitrary column updates via `FieldUpdate{Col, Val}`
- `db.GetBottleByTagId(tagID)` exists for conflict checking (returns in-stock bottles only)
- `db.GetBottleByID(id)` exists for existence checking
- All logging uses `log/slog`

### Project Structure Notes

- Module path: `winetap`
- Existing binaries: `cmd/server`, `cmd/cellar`, `cmd/manager`, `cmd/cfru5102_read`
- New binary: `cmd/nfc_seed/main.go`
- Build: `make build` compiles all targets into `bin/`
- Proto: `make proto` runs `buf generate`

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile.md] — Story 1.2 acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture-mobile.md] — NormalizeTagID spec (line ~530), tag_id normalization (line ~536)
- [Source: internal/server/service/bottles.go] — AddBottle, UpdateBottle, fieldMaskToUpdates showing tag_id not in BottleFields
- [Source: internal/server/db/bottles.go] — UpdateBottleFields, GetBottleByTagId, GetBottleByID
- [Source: cmd/cellar/main.go] — gRPC client connection pattern
- [Source: proto/winetap/v1/winetap.proto] — BottleFields (lines 83-91), Bottle.tag_id (line 71)
- [Source: _bmad-output/implementation-artifacts/1-1-proto-rename-and-system-wide-tag-id-migration.md] — Previous story learnings

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Added `SetBottleTagId` RPC and `SetBottleTagIdRequest` message to proto; `buf lint` passes, `make proto` regenerates cleanly
- Created `NormalizeTagID()` in `internal/server/service/tagid.go` — strips colons/spaces/dashes, uppercases; 9 test cases all pass
- Implemented `SetBottleTagId` service method with: normalization, empty check (INVALID_ARGUMENT), conflict detection (ALREADY_EXISTS with bottle ID), existence check (NOT_FOUND), update via `db.UpdateBottleFields`
- Created CLI binary `cmd/nfc_seed/main.go` with `--server`, `--bottle-id`, `--tag-id` flags; human-readable error messages for each gRPC status code
- Added `build-nfc-seed` Makefile target and included in `build` meta-target
- `make build` compiles all 4 binaries, `go test ./...` passes with 0 failures

### Change Log

- 2026-03-30: Added SetBottleTagId RPC, NormalizeTagID function, and nfc-seed CLI tool

### File List

- proto/winetap/v1/winetap.proto (modified — new RPC + message)
- gen/winetap/v1/winetap.pb.go (regenerated)
- gen/winetap/v1/winetap_grpc.pb.go (regenerated)
- internal/server/service/tagid.go (new)
- internal/server/service/tagid_test.go (new)
- internal/server/service/bottles.go (modified — new SetBottleTagId method)
- cmd/nfc_seed/main.go (new)
- Makefile (modified — new build-nfc-seed target)
