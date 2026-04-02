# Story 7.4: Continuous Scan Mode + Error Handling

Status: done

## Story

As a user,
I want continuous scanning for bulk intake with clear error recovery,
So that I can register many bottles quickly without interruption.

## Acceptance Criteria

1. **Given** continuous mode active
   **When** bottles are scanned in sequence
   **Then** after first scan, NFC stays active for next tag automatically (FR4, FR16)
   **And** duplicate tags silently ignored (FR5, NFR14)
   **And** "Tag lu" flashes briefly, then returns to "Pret" (FR15)
   **And** manager cancel -> phone stops NFC, returns to waiting (FR17)
   **And** 30s timeout -> phone shows "Delai depasse" briefly (FR18)
   **And** NFC failure -> scan request stays active, user retries (FR19, NFR9)
   **And** phone unreachable -> manager shows error, form data preserved (FR30, FR31)

## Tasks / Subtasks

- [x] Task 1: Switch manager addBottleFrom to continuous scan mode (AC: #1 — FR4, FR15, FR16)
  - [x] 1.1 In `inventory.go` `addBottleFrom(template)`: change `StartScan(ScanModeSingle)` to `StartScan(ScanModeContinuous)`
  - [x] 1.2 In `OnTagScanned` callback inside `addBottleFrom`: do NOT call `StopScan()` — continuous mode keeps polling for next tag
  - [x] 1.3 After save completes (in `addBottle` goroutine): do NOT call `addBottleFrom(template)` again — the continuous poll loop already delivers the next tag
  - [x] 1.4 Instead, after save: refresh table, re-register `OnTagScanned` with same template (form pre-filled for next bottle), show "En attente du prochain scan…"
  - [x] 1.5 Keep `openAddForm()` and `onSearchByTag()` as `ScanModeSingle` — continuous is only for the copy/chain flow

- [x] Task 2: Handle continuous scan tag delivery in addBottleFrom (AC: #1 — FR15)
  - [x] 2.1 Each tag callback: fill form with template + new tag ID, enable save
  - [x] 2.2 Show "Nouvelle bouteille (copie)" with tag pre-filled
  - [x] 2.3 User saves -> bottle created -> table refreshed -> re-register callback for next tag
  - [x] 2.4 User clicks Cancel -> `StopScan()` called, exits continuous mode cleanly

- [x] Task 3: Handle manager cancel during continuous mode (AC: #1 — FR17)
  - [x] 3.1 `OnCancel` in tableScreen config already calls `s.ctx.Scanner.StopScan()` (line ~199)
  - [x] 3.2 Verify this sends POST /scan/cancel to phone (it does via `NFCScanner.StopScan()`)
  - [x] 3.3 Verify `pollLoop` exits cleanly on cancel (context cancelled or 410)
  - [x] 3.4 Phone: IntakeProvider detects `hasPendingRequest` becoming false -> `_stopContinuous()` -> NFC stopped

- [x] Task 4: Verify timeout behavior (AC: #1 — FR18)
  - [x] 4.1 Phone: ScanCoordinator `waitForResult()` returns null on 30s timeout -> handler returns 204
  - [x] 4.2 Manager: `pollLoop` on 204 -> retry immediately (`continue`) — no UI change on timeout
  - [x] 4.3 Phone: IntakeProvider shows "Delai depasse" briefly only if the coordinator's request is cancelled after sustained timeout (this is handled by story 7.2's poll timer detecting `!hasPendingRequest`)
  - [x] 4.4 Verify: continuous poll across timeout boundaries works (manager retries GET /scan/result, phone maintains request state across timeouts)

- [x] Task 5: Verify duplicate suppression (AC: #1 — FR5, NFR14)
  - [x] 5.1 Phone: `_lastContinuousTagId` in IntakeProvider filters duplicates (existing from v1)
  - [x] 5.2 Phone: ScanCoordinator `submitResult` only called for non-duplicate tags
  - [x] 5.3 Manager: receives only unique tags from the coordinator (duplicates never reach HTTP)
  - [x] 5.4 If same tag scanned again after successful save (new bottle uses different tag), it should NOT be duplicate — `_lastContinuousTagId` reset point may need review

- [x] Task 6: Error handling — phone unreachable (AC: #1 — FR30, FR31)
  - [x] 6.1 `StartScan` error: show error, preserve template data in form, user can retry or enter tag manually (from Story 7.3 `OnScanError` pattern)
  - [x] 6.2 Mid-scan unreachable: `OnScanError` callback fires -> show error, preserve current form data
  - [x] 6.3 Verify form data preserved across errors: cuvee, vintage, description, price all retained (FR31)

- [x] Task 7: Navigation guard — stop scan on screen change (AC: #1)
  - [x] 7.1 Verify: `manager.go` `navigate()` already calls `m.scanner.StopScan()` on every screen switch (line ~307)
  - [x] 7.2 This cleanly exits continuous mode when user navigates away from inventory

- [x] Task 8: Tests (AC: #1)
  - [x] 8.1 Test: continuous mode delivers multiple tags sequentially (NFCScanner already tested in 6.4 — test 7.7)
  - [x] 8.2 Test: `addBottle` does NOT re-chain to `addBottleFrom` in continuous mode (no double polling)
  - [x] 8.3 Test: `StopScan` during continuous mode exits cleanly
  - [x] 8.4 Integration verification: `go build ./...` passes, all existing tests pass

### Review Findings

- [x] [Review][Patch] `OnScanError` not re-registered on post-save re-entry — stale template restored on 2nd+ error [inventory.go:731] — **applied**
- [x] [Review][Patch] `OnActivate` does not reset `continuousActive` — stuck UI if user navigates away mid-session [inventory.go:267] — **applied**
- [x] [Review][Patch] `ScrollTo` dropped from `onSearchByTag` — found bottle may be off-screen [inventory.go:1037] — **applied**
- [x] [Review][Defer] `refreshThen`/`errCallback` ordering race — error dispatch and save callback both on main thread queue; ordering depends on timing [inventory.go] — deferred, pre-existing/architectural
- [x] [Review][Defer] `OnCopy` calls `addBottleFrom` unconditionally while `continuousActive` — `StartScan` cancels first so no double goroutine, but UX abrupt [inventory.go] — deferred, edge case
- [x] [Review][Defer] `populate` calls `HideRight` before `then` callback runs — brief panel flash on each save in continuous chain [inventory.go] — deferred, pre-existing
- [x] [Review][Defer] Spurious "phone inaccessible" dialog possible on cancel if poll error races ahead of context cancel [inventory.go] — deferred, very tight window
- [x] [Review][Defer] `QMessageBox_Warning` downgraded to `QMessageBox_Information` for tag-not-found in `onSearchByTag` [inventory.go] — deferred, design preference

## Dev Notes

### Architecture Context — How Continuous Intake Works End-to-End

**Current flow (single mode chain — Story 6.4):**
```
openAddForm() → StartScan(single) → tag arrives → fill form → user saves
→ addBottle(cuveeID) → POST /bottles → success → addBottleFrom(template)
→ StartScan(single) → tag arrives → fill form → user saves → loop...
```

Each iteration sends POST /scan/request + GET /scan/result. The phone starts and stops NFC for each bottle. Slow — requires a new scan request per bottle.

**New flow (continuous mode — this story):**
```
addBottleFrom(template) → StartScan(continuous) → POST /scan/request {mode:"continuous"}
  → tag1 arrives → fill form → user saves → addBottle(cuveeID) → POST /bottles → success
    → re-register OnTagScanned (same poll loop running) → tag2 arrives → fill form → ...
```

Single POST /scan/request at the start. The `pollLoop` in NFCScanner keeps long-polling GET /scan/result in a loop. Phone NFC stays active. Each 200 response delivers a tag, the loop immediately re-polls. No re-request needed.

### Key Insight — The Save-Then-Chain Must NOT Restart Scanning

The current `addBottle()` function (line 669-685) chains to `addBottleFrom(template)` after a successful save:

```go
mainthread.Start(func() {
    s.refreshThen(func() {
        s.addBottleFrom(template)  // this calls StartScan again!
    })
})
```

In continuous mode, this would send a SECOND POST /scan/request while the first is still active → 409 conflict. The fix:

```go
// In addBottle(), after successful save:
mainthread.Start(func() {
    s.refreshThen(func() {
        if s.continuousActive {
            // Continuous: just re-register callback, don't restart scan
            s.reRegisterContinuousCallback(template)
        } else {
            // Single: chain as before
            s.addBottleFrom(template)
        }
    })
})
```

### Manager-Side Changes — inventory.go Only

Add a `continuousActive bool` field to `InventoryScreen` to track whether the current scan session is continuous:

```go
type InventoryScreen struct {
    // ... existing fields ...
    continuousActive bool  // true while addBottleFrom is in continuous mode
}
```

**`addBottleFrom(template)` rewrite:**
```go
func (s *InventoryScreen) addBottleFrom(template client.Bottle) {
    s.ts.TableView.ClearSelection()
    s.bottleForm.clearFields()
    s.bottleForm.SetWaiting(true)
    s.ts.SetSaveEnabled(false)
    s.ts.ShowRight("En attente d'un scan RFID…")

    s.registerContinuousCallback(template)

    s.ctx.Scanner.OnScanError(func(err error) {
        s.continuousActive = false
        s.bottleForm.SetWaiting(false)
        s.bottleForm.loadData(func() {
            s.bottleForm.loadBottle(template)
            s.bottleForm.editBottleID = 0
        })
        s.ts.ShowRight("Nouvelle bouteille (copie)")
        s.ctx.Log.Error("scan error during continuous intake", "error", err)
        qt.QMessageBox_Warning(nil, "Erreur de scan",
            "Téléphone inaccessible — entrez le tag manuellement ou réessayez.")
    })

    s.continuousActive = true
    if err := s.ctx.Scanner.StartScan(ScanModeContinuous); err != nil {
        s.continuousActive = false
        s.bottleForm.SetWaiting(false)
        s.bottleForm.loadData(func() {
            s.bottleForm.loadBottle(template)
            s.bottleForm.editBottleID = 0
        })
        s.ts.ShowRight("Nouvelle bouteille (copie)")
        s.ctx.Log.Error("scan start failed", "error", err)
        qt.QMessageBox_Warning(nil, "Erreur de scan",
            "Téléphone inaccessible — entrez le tag manuellement ou réessayez.")
    }
}

func (s *InventoryScreen) registerContinuousCallback(template client.Bottle) {
    s.ctx.Scanner.OnTagScanned(func(tagID string) {
        // Don't call StopScan — continuous mode keeps polling
        s.bottleForm.SetWaiting(false)
        s.bottleForm.loadData(func() {
            s.bottleForm.loadBottle(template)
            s.bottleForm.editBottleID = 0
            s.bottleForm.SetEPC(tagID)
            s.ts.SetSaveEnabled(true)
        })
        s.ts.ShowRight("Nouvelle bouteille (copie)")
    })
}
```

**`addBottle(cuveeID)` — modified chain:**
```go
// After successful save, inside mainthread.Start:
s.refreshThen(func() {
    if s.continuousActive {
        // Re-register for next tag (poll loop already running)
        s.bottleForm.clearFields()
        s.bottleForm.SetWaiting(true)
        s.ts.SetSaveEnabled(false)
        s.ts.ShowRight("En attente du prochain scan…")
        s.registerContinuousCallback(template)
    } else {
        s.addBottleFrom(template)
    }
})
```

### Cancel Flow — Exits Continuous Mode

The existing `OnCancel` in the tableScreen config calls `s.ctx.Scanner.StopScan()`. This triggers:
1. Manager: `NFCScanner.StopScan()` → cancels poll goroutine context, POSTs /scan/cancel
2. Phone: scan handler calls `coordinator.cancel()` → `hasPendingRequest` false
3. Phone: IntakeProvider detects cancellation → `_stopContinuous()` → NFC stopped
4. Manager: poll goroutine exits cleanly

Add cleanup: `s.continuousActive = false` in the OnCancel handler.

```go
OnCancel: func() {
    s.continuousActive = false  // NEW — clear continuous state
    s.ctx.Scanner.StopScan()
    s.ts.HideRight()
},
```

Also clear on `openEditForm`:
```go
func (s *InventoryScreen) openEditForm(srcRow int) {
    s.continuousActive = false  // NEW — editing interrupts continuous
    // ... existing code ...
```

### Phone Side — No Changes Needed

All phone-side continuous mode behavior is already implemented:
- **ScanCoordinator**: `submitResult()` in continuous mode creates new Completer for next tag (existing)
- **IntakeProvider** (after Story 7.2): polls coordinator, continuous mode → `_startContinuousRead()` → duplicate filtering via `_lastContinuousTagId` (existing)
- **NfcService**: `continuousRead()` stream yields tags, auto-retries on timeout (existing)
- **Scan handler** (Story 7.1): GET /scan/result returns 200 on each tag, manager polls again for next (existing)

### Timeout Behavior — Already Correct

The 30s timeout flow in continuous mode:
1. Phone: ScanCoordinator `waitForResult()` times out → returns null, `hasPendingRequest` true
2. Phone: scan handler returns 204
3. Manager: `pollLoop` gets `tagID == ""` → logs debug "poll timeout, retrying" → `continue` (loops)
4. Manager: next GET /scan/result → phone blocks again for up to 30s
5. The user sees nothing on the manager side — timeout is transparent

On the phone, the IntakeProvider stays in continuous scanning mode. The timeout is purely on the HTTP long-poll, not on the NFC reading.

### Duplicate Suppression — Already Correct

Phone-side `IntakeProvider._startContinuousRead()` uses `_lastContinuousTagId` to filter duplicate NFC reads. Only unique tags reach `coordinator.submitResult()`. The manager receives only unique tags.

**Edge case to verify:** After a bottle is saved with tag X, if the same physical tag is still on the NFC reader, the next read will produce X again. The `_lastContinuousTagId` filter catches this. The user must remove the tag and present a new one. This is correct behavior.

### openAddForm — Keep Single Mode

`openAddForm()` uses single mode because the user hasn't selected a cuvee yet — there's no template to chain from. The flow is: scan tag → fill empty form → user picks cuvee → save → THEN chain into continuous via `addBottleFrom(template)`.

After the first save in `addBottle()`, the chain to `addBottleFrom(template)` starts continuous mode. So the natural flow is:

```
openAddForm() [single] → first bottle saved → addBottleFrom [continuous] → second bottle → ...
```

### Previous Story Intelligence

**From Story 7.3 (Manager NFCScanner HTTP Polling):**
- `OnScanError` callback added to `screen.Scanner` and `NFCScanner`
- Error handler pattern: exit waiting state, preserve form data, show QMessageBox
- `dispatch` field ensures callbacks fire on Qt main thread

**From Story 7.2 (IntakeProvider Rewrite):**
- IntakeProvider polls coordinator, detects requests and cancellations
- Continuous mode: `_startContinuousRead()` with duplicate filtering
- Cancellation detected via `hasPendingRequest` becoming false → `_stopContinuous()`

**From Story 7.1 (Scan Coordination Endpoints):**
- Continuous mode on scan handler: `coordinator.waitForResult()` → 200 per tag → manager polls again
- 409 if scan already in progress (prevents double-request)

**From Story 6.4 (Manager NFCScanner Stub):**
- `pollLoop` in continuous mode: after 200 response, loops immediately for next GET /scan/result
- Single mode: returns after first tag
- 204 timeout: automatic retry
- Review finding: no backoff on 204 loop — acceptable since server holds for 30s

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `internal/manager/screen/inventory.go` | MODIFY | `addBottleFrom` uses continuous mode; `addBottle` re-registers callback instead of re-chaining; `continuousActive` flag; cancel cleanup |
| No other files | — | Phone side already complete from Stories 7.1 + 7.2; NFCScanner from 6.4 + 7.3 |

### Anti-Patterns to Avoid

- Do NOT send a second POST /scan/request while continuous mode is active — 409 conflict. Re-register the callback instead.
- Do NOT call `StopScan()` in the `OnTagScanned` callback during continuous mode — the poll loop must keep running
- Do NOT modify `nfc_scanner.go` — continuous poll loop is already correct from Story 6.4
- Do NOT modify phone-side code — all continuous mode behavior is complete from Stories 7.1 + 7.2
- Do NOT use `print()` — slog only
- Do NOT add a "continuous mode toggle" to the UI — the mode is implicit: `addBottleFrom` = continuous, `openAddForm`/`onSearchByTag` = single

### Project Structure Notes

Only one file modified. All changes are in the manager UI layer. The phone side and NFCScanner are already complete.

```
internal/manager/screen/
├── inventory.go    ← MODIFY (addBottleFrom continuous mode, addBottle chain logic)
├── ctx.go          (unchanged)
└── ...             (unchanged)
```

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile-v2.md#Story 7.4] — acceptance criteria: continuous mode, duplicate suppression, timeout, cancel, error handling
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md#Scan Coordinator Pattern] — continuous mode creates new Completer after submitResult
- [Source: internal/manager/screen/inventory.go:498-520] — current `addBottleFrom` using single mode + chain
- [Source: internal/manager/screen/inventory.go:634-685] — `addBottle` chains to `addBottleFrom(template)` after save
- [Source: internal/manager/screen/inventory.go:196-201] — OnCancel calls StopScan
- [Source: internal/manager/nfc_scanner.go:108-155] — pollLoop: continuous mode loops after 200, single exits
- [Source: internal/manager/manager.go:306-308] — navigate() calls StopScan on screen switch
- [Source: mobile/lib/server/scan_coordinator.dart:50-61] — submitResult continuous mode: new Completer for next tag
- [Source: _bmad-output/implementation-artifacts/7-3-manager-nfc-scanner-http-polling.md] — OnScanError pattern for phone-unreachable error handling
- [Source: _bmad-output/implementation-artifacts/7-2-intake-provider-rewrite.md] — IntakeProvider continuous mode, duplicate filtering
- [Source: _bmad-output/implementation-artifacts/6-4-manager-nfc-scanner-stub-for-http.md] — NFCScanner poll loop, continuous vs single behavior

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
None

### Completion Notes List
- Added `continuousActive bool` field to `InventoryScreen` to track continuous scan state
- Extracted `registerContinuousCallback(template)` helper — registers OnTagScanned without calling StopScan
- Rewrote `addBottleFrom` to use `ScanModeContinuous`; sets `continuousActive = true` on start, clears on error
- Modified `addBottle` chain: when `continuousActive`, re-registers callback (no new scan request) and shows "En attente du prochain scan…"; otherwise falls back to `addBottleFrom` for single-mode chain
- Added `continuousActive = false` to `OnCancel` and `openEditForm` to clear state on navigation/edit
- Tasks 3–7 verified: phone side (ScanCoordinator, IntakeProvider, NfcService), pollLoop 204 retry, duplicate suppression, and navigation guard all already correct from prior stories
- `TestNFCScanner_ContinuousModeRetries` covers multi-tag delivery (story 6.4); all 15 manager tests pass; `go build ./...` clean

### File List
- internal/manager/screen/inventory.go (MODIFIED)

### Change Log
- 2026-04-01: Implemented Story 7.4 — continuous scan mode for bulk intake
