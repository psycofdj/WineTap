# Deferred Work

## Deferred from: code review of 5-1-drift-database-and-schema (2026-04-01)

- `getById` methods (`getDesignationById`, `getDomainById`, `getCuveeById`, `getBottleById`) use `.getSingle()` which throws opaque `StateError` on missing rows. Handler layer in Stories 5.3/5.4 should catch `StateError` and map to HTTP 404. Not actionable in the DB layer alone.

## Deferred from: code review of 5-2-shelf-http-server-and-middleware (2026-04-01)

- No startup error handling in `main()` — if `startServer` or `discovery.register` throws, app crashes before UI renders. Architectural concern; requires design decisions around error state UI.
- No app lifecycle teardown — AppDatabase, HttpServer, and DiscoveryService are never closed on app termination or background. Needs `WidgetsBindingObserver` or `AppLifecycleListener`.
- IPv6-only networks not supported — `shelf_io.serve` binds to `anyIPv4` only; IPv6-only or dual-stack networks preferring IPv6 cannot reach the server.
- WakelockPlus `idleTimer` closure not cancelled on server/app shutdown — timer continues firing on stale context after server is stopped.
- `discovery.register()` may hang — `_broadcast!.ready` has no timeout; Bonsoir init hang on permission denial blocks `main()` indefinitely.

## Deferred from: code review of 6-1-go-http-client-and-api-types (2026-04-01)

- `BulkUpdateBottles` with empty/nil IDs sends `{"ids":null,...}` to server — no client-side guard required by spec; server behavior undefined for zero IDs but not a real-world scenario.
- Null vs `[]` on list endpoints — if Dart/drift server ever returns JSON `null` instead of `[]` for an empty list, Go callers get a nil slice. Low risk: drift always returns proper arrays.

## Deferred from: code review of 5-4-bottle-rest-api-and-completions (2026-04-01)

- `setBottleTagId` 404 detection is fragile — fires via `StateError` from `getBottleById` after a silent no-op `update()`, not from the write itself; correct outcome but breaks if `getBottleById` ever returns null instead of throwing [database.dart:363-367].
- Empty `ids: []` in PUT /bulk returns `200 {"updated": 0}` — technically correct but could mask upstream type-filter bug; accepted as design choice, no guard enforced.
- Empty `fields: {}` in PUT /bulk is a silent no-op but returns correct matched-row count — Drift `update().write()` with all-absent companion generates no-op SQL; Drift limitation, no fix without spec change.

## Deferred from: code review of 6-2-manager-mdns-discovery-of-phone (2026-04-01)

- NFR8 worst-case recovery 8s vs spec's 5s — tick=5s + discovery=3s; accepted relaxed bound: ≤5s when phone IP is stable (common case); 8s only when IP changes and mDNS discovery times out.

- Immediate health check on empty `baseURL` causes double mDNS discovery at startup — when no phone is found in `New()`, `httpHealthLoop` immediately fires and re-triggers `DiscoverPhone`; low impact, pre-existing design side-effect [manager.go:224].
- IPv6 addresses silently ignored in `DiscoverPhone` — `len(entry.AddrIPv4) > 0` guard skips IPv6-only entries with no diagnostic log; not a real-world issue on current target home WiFi networks [discovery.go:32].

## Deferred from: code review of 5-5-local-consume-flow (2026-04-01)

- scanAck handler double-writes `_lastTagId` from server — canonical server ID overwrites NFC raw value without a second `notifyListeners()` call; intentional if server ID is authoritative, silent otherwise [intake_provider.dart].
- `onDone` in `_startContinuousRead` may overwrite intended state after deliberate `_stopContinuous()` call — no "intentional stop" flag; design tradeoff [intake_provider.dart].
- `_showBriefError` timer generation race — rapid double-call can strand `_briefErrorActive=true` permanently; low-probability edge case [intake_provider.dart].
- Shared `_resetTimer` between scanAck and `_showBriefError` — ack arrival during brief error display can leave `_briefErrorActive=true` permanently; low-probability [intake_provider.dart].
- `continuousRead()` yields after subscription cancel window — `yield` after `await readTagId()` returns is benign (value dropped by cancelled sub) but a post-await `_continuousActive` check would be safer [nfc_service.dart].
- No inter-scan delay in `continuousRead()` loop on Android — same physical tag may slip past the tag-ID dedup filter on aggressive NFC stacks; acceptable for MVP [nfc_service.dart].
- `_lastContinuousTagId` reset on new `scanRequestNotification` — nullifies dedup guard mid-session if server sends new request while tag in range [intake_provider.dart].
- No CPU backoff in `continuousRead()` catch branches — potential tight loop on persistent NFC hardware error; acceptable for MVP [nfc_service.dart].

## Deferred from: code review of 6-4-manager-nfc-scanner-stub-for-http (2026-04-01)

- **`m.scanner` hot-swap race in `SaveSettings`** — `m.scanner` is read by scan callbacks on the Qt main thread and written by `SaveSettings` also on the Qt main thread; no explicit mutex protects the field. Pre-existing design from story 6.3 (not introduced by 6.4). Needs an explicit lock or architectural change once Epic 7 adds concurrent scan paths [manager.go:SaveSettings].
- **`StartScan` ignores caller context** — `_ context.Context` discards the caller's cancellation signal; consistent with `RFIDScanner` pattern but means upstream context propagation is unavailable. Acceptable for current use (screens pass `context.Background()`); revisit if Epic 7 adds deadline-aware scan coordination.
- **204 poll loop has no backoff** — on 204 (server timeout), the manager immediately re-issues `GET /scan/result`; no sleep or exponential backoff. Server contract guarantees 30s long-hold before returning 204, so back-to-back 204s are rare. Revisit if server contract changes or network profiling shows excess traffic [nfc_scanner.go:pollLoop].

## Deferred from: code review of 7-1-scan-coordination-rest-endpoints (2026-04-01)

- **Continuous mode: tag submitted between timeout and next poll is lost** — ScanCoordinator creates a fresh Completer on timeout; if `submitResult` fires before the next `waitForResult` call, the result completes a Completer nobody is awaiting. Pre-existing Completer-per-poll design limitation [scan_coordinator.dart].
- **Request body not size-limited before readAsString** — `jsonDecode(await req.readAsString())` reads entire body into memory with no size limit. Pre-existing pattern across all handler files (bottles, cuvees, etc.) [scan.dart:16].

## Deferred from: code review of 7-2-intake-provider-rewrite (2026-04-01)

- **`cancelScan` in single-read mode races with still-pending `_singleRead` future** — `cancelScan()` calls `_stopContinuous()` and transitions state, but the `_singleRead` async future is still awaiting `readTagId()`. When the NFC session cancels, `_showBriefError` fires and may flash a brief error. Functionally harmless (both paths end at `scanRequested`). Pre-existing design from v1 [intake_provider.dart].

## Deferred from: code review of 7-4-continuous-scan-mode-and-error-handling (2026-04-01)

- `refreshThen`/`errCallback` ordering race in continuous mode: error dispatch and save completion both post to Qt main thread queue; if error queued first, `refreshThen`'s `then` sees `continuousActive=false` and calls `addBottleFrom` (starts new scan) rather than re-registering. Low probability; not a crash.
- `OnCopy` calls `addBottleFrom` unconditionally while `continuousActive` is true — abruptly exits the current continuous session. `StartScan` cancels the old poll loop first so no double goroutine, but the UX interruption is surprising.
- `populate` calls `s.ts.HideRight()` before the `then` callback runs, causing a brief panel flash on each bottle save in the continuous chain. Pre-existing behavior worsened by rapid repeated saves.
- Spurious "phone inaccessible" dialog possible on cancel: if `pollLoop` gets a non-context error at the exact moment the context is cancelled, `errCallback` fires after `StopScan` has already returned, showing an error dialog the user didn't expect. Very tight timing window.
- `QMessageBox_Warning` downgraded to `QMessageBox_Information` for tag-not-found case in `onSearchByTag`. Could be reverted if operators want higher-visibility feedback for unknown tags.

## Deferred from: code review of 8-1-backup-and-restore-endpoints (2026-04-02)

- No authentication on backup/restore endpoints — all app routes are unauth'd by design (local-network MVP); pre-existing architectural decision.
- WAL checkpoint return value not verified — Drift's `customStatement` returns void; checking partial-checkpoint status would require a raw SQL query returning rows; pre-existing limitation.
- SQLite magic check covers only 16 bytes — full header validation (page size, page count cross-check) is beyond story scope (story specifies magic header check only).
- Concurrent backup+restore race — simultaneous `/backup` + `/restore` requests can race on `db.close()` / WAL checkpoint; requires an architectural mutex or request serialization; beyond story scope.

## Deferred from: code review of 8-2-settings-screen-with-backup-restore (2026-04-02)

- Uint8List.fromList double-copy in _downloadBackup — minor memory optimization; _downloadBackup should return Uint8List directly to avoid copy at call site.
- FilePicker.saveFile path≠success on desktop — on some desktop platforms, saveFile returns a path but doesn't write the bytes; mobile-focused app makes this moot.
- No progress feedback during slow upload — POST /restore has no progress callbacks; user sees static spinner for large files on slow connections; beyond story scope.
- Connection reset after restore — server calls exit(0) after restore; HttpClient may see SocketException instead of HTTP 200; already accepted as MVP design in story 8.1 review (decision b).
- _showSnackBar no internal mounted guard — all callers explicitly check mounted before calling; safe as-is but could be hardened.
