# WineTap — Project Specification

## Overview

WineTap is a wine cellar inventory system that uses RFID tags to track the lifecycle of each bottle — from purchase to consumption.

Each bottle receives an RFID tag when it enters the cellar. Scanning the tag on exit marks the bottle as consumed and removes it from the active inventory.

---

## Architecture

![Architecture](specs/generated/architecture.png)

Three components, all written in Go:

| Component    | Role                               | Runs on                     |
|--------------|------------------------------------|-----------------------------|
| `rpc-server` | Data persistence, business logic   | Raspberry Pi (24/7)         |
| `cellar`     | Scan bottles out of cellar         | Raspberry Pi (same machine) |
| `manager`    | Add bottles with metadata, GUI     | Desktop computer            |

---

## Components

### rpc-server

- Exposes a gRPC API consumed by both `cellar` and `manager`
- Persists data in a local SQLite database (bottles + designation reference table)
- Stateless per request; single-node deployment
- Owns the INAO designation database: stores it locally and can refresh it on demand

### cellar

- Runs on a Raspberry Pi with a USB UHF RFID reader (Chafon CF-RU5102)
- Runs a continuous read loop: the CF-RU5102 driver emits tag data whenever the reader detects a tag; the app processes each emission in sequence
- If multiple tags are read simultaneously in one cycle, only the first tag is processed; the rest are discarded silently
- User feedback via two Pi LEDs:

  | LED   | Event                                      | Pattern              |
  |-------|--------------------------------------------|----------------------|
  | PWR   | Successful consume                         | Fast blink           |
  | SYS   | Scan-level error (unknown tag)             | Fast blink (3 s)    |
  | SYS   | System-level error (RPC, reader, network)  | Slow blink (3 s)    |

- Single operation: scan a bottle → mark it as consumed via `ConsumeBottle` RPC (takes the EPC; the server resolves the bottle internally by EPC and clears the `rfid_epc` field — the physical tag memory is never modified)
- On a scan-level error: SYS fast blink + push `PushEvent` to server
- On a system-level error (server unreachable, RPC failure, reader fault): SYS slow blink; the error event is lost (no retry, no local queue)

### manager

- Runs on a desktop computer with a Qt graphical interface (Go + Qt via [miqt](https://github.com/mappu/miqt) bindings)
- USB UHF RFID reader attached
- Four main sections (see screen layout below):
  1. **Inventory**: browse, search, and filter the full bottle collection
  2. **Add bottles**: intake flow with bulk scan support
  3. **Read bottle**: scan a tag to look up and edit a bottle's information
  4. **Settings**: server connection, refresh INAO designation database
- RFID reader is active **only** on the "Add bottles" and "Read bottle" screens; it is idle on Inventory and Settings to prevent accidental scans
- Subscribes to the server's event stream on startup; unacknowledged error events are shown as persistent notifications until the user dismisses them
- If the server becomes unreachable, auto-reconnects with exponential backoff; a "serveur inaccessible" notification is shown in the notification bar until the connection is restored

---

## Data Model

### Bottle

| Field           | Type     | Notes                                            |
|-----------------|----------|--------------------------------------------------|
| `id`            | UUID     | Internal primary key                             |
| `rfid_epc`      | string   | EPC of the currently attached tag; **null after consumption** (tag freed for reuse). Temporary association — not a permanent identifier. |
| `color`         | enum     | `rouge`, `blanc`, `rosé`, `effervescent`, `autre`|
| `designation`   | string   | AOC/AOP appellation, e.g. "Bordeaux", "Champagne"|
| `domain`        | string   | Producer / château / domaine name                |
| `vintage`       | int      | Year of the vintage                              |
| `description`   | string   | Free-form user notes (optional)                  |
| `purchase_price`| decimal  | Per-bottle price in euros (optional)             |
| `drink_before`  | int      | Estimated last good year (optional)              |
| `added_at`      | datetime | When the bottle was added to the cellar          |
| `consumed_at`   | datetime | When the bottle was taken out (null if in stock) |

A bottle is **in stock** when `consumed_at` is null.
A bottle is **consumed** when `consumed_at` is set; at that point `rfid_epc` is cleared to null so the physical tag can be reused on a new bottle. The physical tag memory is never modified — only the database record changes.
Bottles are always identified internally by their UUID (`id`). The EPC is a temporary, mutable association — it is the entry point for scans but is never used as a stable reference between services.
Bottles are never hard-deleted **except** in the lost/damaged tag scenario: if a physical tag is irrecoverable, the user deletes the bottle record in `manager` and re-enrolls the bottle with a new tag. This is the only case where a record is permanently removed.
The uniqueness constraint on `rfid_epc` applies only to non-null values (i.e. among currently tagged, in-stock bottles).

### Event

| Field             | Type     | Notes                                                        |
|-------------------|----------|--------------------------------------------------------------|
| `id`              | UUID     | Internal primary key                                         |
| `source`          | enum     | `cellar` (only cellar pushes events for now)                 |
| `kind`            | enum     | `unknown_tag`, `tag_already_consumed`, `reader_fault`, `rpc_error`, `other` |
| `message`         | string   | Human-readable description                                   |
| `payload`         | string   | Optional extra context (e.g. the unknown EPC)                |
| `occurred_at`     | datetime | When the event occurred on the source machine                |
| `acknowledged_at` | datetime | When the user dismissed it in manager (null = unacknowledged)|

Events are never deleted.

### Designation (reference table)

| Field    | Type   | Notes                                   |
|----------|--------|-----------------------------------------|
| `name`   | string | Official appellation name               |
| `region` | string | Wine region (e.g. "Bordeaux", "Alsace") |
| `color`  | string | Typical color(s) for this appellation   |

Populated and refreshed from the INAO open data (data.gouv.fr). Stored on the server.

---

## Autocompletion

All three text fields (color, designation, domain) offer completion sourced from **two layers**:

| Field         | Source 1 — INAO / static         | Source 2 — user's own inventory         |
|---------------|-----------------------------------|-----------------------------------------|
| `color`       | Static list (5 values)            | Distinct colors in bottle history       |
| `designation` | INAO designation table (server)   | Distinct designations in bottle history |
| `domain`      | _(none)_                          | Distinct domains in bottle history      |

The server merges both sources and returns a deduplicated list via the `GetCompletions` RPC. The manager requests completions on keystroke (debounced).

---

## Inventory — Filtering, Sorting, Grouping

`ListBottles` returns the **full inventory in one call** — no pagination. All filtering, sorting, and grouping are performed client-side in `manager`. This avoids firing multiple queries as the user adjusts filters.

**Sort options**: all sorts are reversible (clicking the active sort key toggles direction). Multiple sort columns are supported — the user can stack sorts (e.g. Domaine A→Z, then Millésime newest→oldest).

| Sort key       | Default direction               |
|----------------|---------------------------------|
| Domaine        | A → Z                           |
| Désignation    | A → Z                           |
| Millésime      | oldest → newest                 |
| Date d'ajout   | newest → oldest                 |
| Prix           | lowest → highest                |
| À boire avant  | soonest → latest (no date last) |

Default sort: Domaine A→Z, then Millésime oldest→newest.

**Grouping** (client-side toggle): collapses rows by (domain, designation, vintage, color) into one row with a bottle count. Expanding a group shows individual bottles.

---

## gRPC API

### Bottles service

```protobuf
service WineTap {
  // --- Bottle management ---

  // Add a new bottle (called by manager on intake)
  rpc AddBottle(AddBottleRequest) returns (Bottle);

  // Mark a bottle as consumed by its RFID EPC (called by cellar on exit)
  rpc ConsumeBottle(ConsumeBottleRequest) returns (Bottle);

  // List bottles; default filter is in-stock only
  rpc ListBottles(ListBottlesRequest) returns (ListBottlesResponse);

  // Get a single bottle by its internal UUID
  rpc GetBottle(GetBottleRequest) returns (Bottle);

  // Look up a bottle by its current EPC (used by manager on the Read screen after a scan)
  rpc GetBottleByEPC(GetBottleByEPCRequest) returns (Bottle);

  // Update editable fields of an existing bottle, identified by internal UUID
  rpc UpdateBottle(UpdateBottleRequest) returns (Bottle);

  // Update editable fields of multiple bottles at once (bulk edit from manager)
  rpc BulkUpdateBottles(BulkUpdateBottlesRequest) returns (BulkUpdateBottlesResponse);

  // Hard-delete a single bottle by internal UUID (only for lost/damaged tag recovery)
  rpc DeleteBottle(DeleteBottleRequest) returns (DeleteBottleResponse);

  // --- Autocompletion ---

  // Return completion candidates for a given field
  rpc GetCompletions(GetCompletionsRequest) returns (GetCompletionsResponse);

  // --- INAO designation database ---

  // Trigger a refresh of the designation table from INAO open data
  rpc RefreshDesignations(RefreshDesignationsRequest) returns (RefreshDesignationsResponse);

  // --- Events ---

  // Push an error event (called by cellar)
  rpc PushEvent(PushEventRequest) returns (Event);

  // Stream unacknowledged events to the manager (server-sent, stays open)
  rpc SubscribeEvents(SubscribeEventsRequest) returns (stream Event);

  // Acknowledge an event (called by manager when user dismisses a notification)
  rpc AcknowledgeEvent(AcknowledgeEventRequest) returns (Event);
}
```

#### Key messages

```protobuf
message AddBottleRequest {
  string rfid_epc      = 1;
  string color         = 2;
  string designation   = 3;
  string domain        = 4;
  int32  vintage       = 5;
  string description   = 6;
  double purchase_price = 7;  // 0 = not set
  int32  drink_before  = 8;   // year, 0 = not set
}

message ConsumeBottleRequest {
  string rfid_epc = 1;
  // Server resolves the bottle by EPC, sets consumed_at, clears rfid_epc in the DB.
  // The physical RFID tag memory is never modified.
}

message GetBottleRequest {
  string id = 1;  // internal UUID
}

message GetBottleByEPCRequest {
  string rfid_epc = 1;
}

message ListBottlesRequest {
  string color            = 1;
  string designation      = 2;
  string domain           = 3;
  int32  vintage_from     = 4;
  int32  vintage_to       = 5;
  bool   include_consumed = 6;  // default false
}

message GetCompletionsRequest {
  enum Field { COLOR = 0; DESIGNATION = 1; DOMAIN = 2; }
  Field  field  = 1;
  string prefix = 2;
}

message GetCompletionsResponse {
  repeated string values = 1;
}

// Both UpdateBottle and BulkUpdateBottles use a FieldMask to indicate which fields
// to write. Fields absent from the mask are left unchanged, allowing partial updates.
// Field names match the Bottle message field names.

message UpdateBottleRequest {
  string                id          = 1;  // internal UUID
  BottleFields          fields      = 2;  // values to write
  google.protobuf.FieldMask mask    = 3;  // which fields in `fields` to apply
}

message BulkUpdateBottlesRequest {
  repeated string       ids         = 1;  // internal UUIDs of bottles to update
  BottleFields          fields      = 2;  // values to write
  google.protobuf.FieldMask mask    = 3;  // which fields in `fields` to apply
}

message BulkUpdateBottlesResponse {
  int32 updated = 1;  // number of bottles successfully updated
}

// Editable bottle fields, shared by UpdateBottle and BulkUpdateBottles
message BottleFields {
  string color          = 1;
  string designation    = 2;
  string domain         = 3;
  int32  vintage        = 4;
  string description    = 5;
  double purchase_price = 6;
  int32  drink_before   = 7;
}

message ListBottlesResponse {
  repeated Bottle bottles = 1;
}

message DeleteBottleRequest {
  string id = 1;  // internal UUID
}

message DeleteBottleResponse {}

message RefreshDesignationsResponse {
  int32  imported   = 1;  // number of designations imported
  string updated_at = 2;
}

message PushEventRequest {
  string source      = 1;  // "cellar"
  string kind        = 2;  // unknown_tag | tag_already_consumed | reader_fault | rpc_error | other
  string message     = 3;
  string payload     = 4;  // optional, e.g. the unknown EPC
  string occurred_at = 5;  // RFC3339 timestamp from the source machine
}

message SubscribeEventsRequest {}  // server sends all unacknowledged events on connect, then streams new ones

message AcknowledgeEventRequest {
  string id = 1;  // event UUID
}
```

---

## gRPC Error Codes

| Situation                                             | gRPC status code     | Returned by                    |
|-------------------------------------------------------|----------------------|--------------------------------|
| EPC not associated with any in-stock bottle           | `NOT_FOUND`          | `ConsumeBottle`, `GetBottleByEPC` |
| Internal UUID not found                               | `NOT_FOUND`          | `GetBottle`, `UpdateBottle`, `BulkUpdateBottles`, `DeleteBottle` |
| EPC already associated with an in-stock bottle        | `ALREADY_EXISTS`     | `AddBottle`                    |
| Required field missing or malformed                   | `INVALID_ARGUMENT`   | `AddBottle`, `UpdateBottle`    |
| INAO refresh failed (network or parse error)          | `UNAVAILABLE`        | `RefreshDesignations`          |
| Unexpected server-side error                          | `INTERNAL`           | any                            |

---

## Bottle Lifecycle

![Bottle lifecycle](specs/generated/bottle_lifecycle.png)

Edge cases to handle:
- **Unknown tag scanned on exit**: tag not associated with any bottle — blink error LED (fast), push event, take no action
- **Tag already consumed**: this cannot happen — the EPC is cleared on consumption, so the tag is unrecognised on a second scan (falls into the case above)
- **Tag already associated on intake**: EPC is currently attached to an in-stock bottle — reject with an error in `manager`, do not create a new record

---

## manager — Screen Layout

Navigation is a left icon sidebar with four sections. A red badge on the sidebar icon shows the count of unacknowledged errors.

Unacknowledged error events appear as a persistent notification bar at the top of every screen. Each notification has an **✕** button that calls `AcknowledgeEvent` and removes it from the bar.

![Notifications](specs/generated/screen_notifications.png)

### 1. Inventory screen (default)

![Inventory screen](specs/generated/screen_inventory.png)

**Grouped view** (`Regrouper par vin: Oui`): rows are collapsed by (domain, designation, vintage, color) — one row per wine with a bottle count. Clicking a group expands it to show individual bottles (each with its own EPC). Filters and sorting apply the same way in both views.

**Drink-before warnings** (row background colour):
- **Yellow**: fewer than 12 months until `drink_before` (approaching limit)
- **Red**: `drink_before` year is in the past (overdue)
- No colour: more than 12 months remaining, or no `drink_before` set

The sort option `À boire avant` sorts ascending by `drink_before` so the most urgent bottles rise to the top. Bottles without a `drink_before` date sort last.

**Single selection**: clicking a row opens a detail panel on the right showing all fields (domain, designation, color, vintage, price, drink-before, date added, EPC, notes).

**Multi-selection**: Ctrl+click or Shift+click selects multiple rows (highlighted in blue). When 2 or more rows are selected, the detail panel is replaced by a bulk-edit panel:

![Bulk edit](specs/generated/screen_bulk_edit.png)

Only fields that the user fills in are sent in the update — blank fields are left unchanged on each bottle. Confirmation shows how many bottles were updated. This calls `BulkUpdateBottles` with the list of selected UUIDs and a field mask covering only the filled fields.

### 2. Add bottles screen

Single form. The RFID scan is the trigger that initiates each bottle — the user scans first, then fills in details.

![Add bottle — form](specs/generated/screen_add_bottle.png)

After the bottle is saved, the form is replaced by a confirmation and three action buttons:

![Add bottle — confirmation](specs/generated/screen_add_bottle_confirm.png)

Button behaviour:
- **Fermer**: return to the inventory screen
- **Ajouter la même**: enter bulk scan mode (see below)
- **Ajouter une autre**: reopen a blank form; EPC field resets to "waiting for scan"

Normal flow:
1. App listens for an RFID scan in the background; EPC field shows "waiting"
2. User scans a tag → EPC field is populated; form fields become editable
3. User fills in the fields (autocompletion on designation and domain)
4. User clicks **Ajouter** → bottle is saved via `AddBottle` RPC
5. Confirmation screen appears with the three action buttons

Bulk scan mode ("Ajouter la même"):
- The form is shown pre-filled and locked (read-only) — metadata is fixed
- EPC field shows "waiting for scan"
- Scanning a tag **immediately saves** the bottle without any extra confirmation click
- The confirmation screen reappears after each save, still in bulk mode
- The user exits bulk mode via **Fermer** or **Ajouter une autre**

### 3. Read bottle screen

The app listens for a scan as soon as the user navigates to this screen.

Once a tag is scanned, the bottle's information is fetched via `GetBottle` and displayed in an editable form:

![Read bottle](specs/generated/screen_read_bottle.png)

- EPC, `added_at`, and `consumed_at` are read-only — they cannot be modified
- All other fields are editable, with the same autocompletion as the add flow
- **Annuler**: discard changes, return to the waiting-for-scan state
- **Enregistrer**: save changes via `UpdateBottle` RPC, then return to waiting-for-scan state (ready to read the next bottle)
- A scan on this screen calls `GetBottleByEPC`; the returned bottle is then displayed by its internal UUID for all subsequent operations
- If the scanned tag is unknown (no in-stock bottle associated), display an error message and return to waiting state
- A **Supprimer** button is available on this screen for the lost/damaged tag recovery case: it hard-deletes the bottle record via `DeleteBottle` after a confirmation prompt, then returns to waiting state. The user can then re-enroll the bottle via the "Add bottles" screen with a new tag.

### 4. Settings screen

![Settings](specs/generated/screen_settings.png)

---

## Hardware

- Reader: Chafon CF-RU5102, UHF, ISO 18000-6C / EPC Gen2
- Interface: USB serial
- Driver package: `internal/integration/chafon_huf` (already implemented)
- Both `cellar` and `manager` use the same driver package
- **Driver behaviour**: the CF-RU5102 pushes tag data over serial whenever it detects a tag — there is no polling. Both `cellar` and `manager` run a read loop that blocks on the driver and processes each incoming tag event.

---

## Decisions

- **`cellar` UI**: two Pi LEDs. PWR LED fast blink = success. SYS LED fast blink (3 s) = scan error; SYS LED slow blink (3 s) = system error. No screen.
- **Auth**: none. Local home network deployment only.
- **History**: bottles are soft-deleted by default (`consumed_at` preserved). Hard delete (`DeleteBottle`) is available only to recover from a lost/damaged tag — the user deletes the record and re-enrolls with a new tag.
- **Wrong scan recovery**: user re-enrolls the accidentally consumed bottle via the normal "Add bottles" flow. No undo RPC.
- **GUI framework**: Qt via [miqt](https://github.com/mappu/miqt) bindings (Go + CGo, Qt6).
- **Designation reference data**: INAO open data (data.gouv.fr), stored server-side in SQLite, refreshable on demand from `manager`.
- **Autocompletion**: server merges INAO table + distinct values from bottle history; domain completion is inventory-only (no external source).
- **Language**: UI labels in French (target user is French-speaking).
- **Bulk add**: scan-then-fill flow; after saving, user picks "Fermer / Ajouter la même / Ajouter une autre". No quantity field — each bottle is a separate scan+save.
- **Error events**: cellar pushes events to the server on any error and blinks the LED for 3 s. Manager subscribes via a persistent gRPC server-stream (`SubscribeEvents`); unacknowledged events are shown as a notification bar on every screen. Dismissing a notification calls `AcknowledgeEvent`. Events are never deleted.
- **LED blink patterns**: fast blink = scan-level error (unknown tag, already consumed); slow blink = system-level error (reader fault, server unreachable). Both last 3 s.
- **Inventory grouping**: toggle near filters; grouped view collapses by (domain, designation, vintage, color) with a bottle count, expandable to individual bottles.
- **Drink-before warnings**: amber background when `drink_before` is the current year, red when past. Sort option `À boire avant` sorts ascending by `drink_before` (no date = last).
- **Database migrations**: versioned SQL migrations applied automatically on server startup. Migration state tracked in a `schema_migrations` table in SQLite.
- **Packaging**: systemd unit files for `rpc-server` and `cellar` included in the repo under `deploy/systemd/`. Final packaging format (Docker / Debian / install script) to be decided later.
- **Config format**: YAML for all config files. `manager` uses Qt `QSettings` (cross-OS). Server and cellar read from `/etc/winetap/*.yaml`.
- **gRPC default port**: `50051`, overridable in config.
- **Filtering/sorting/grouping**: client-side in `manager`. Server returns the full inventory in a single `ListBottles` call.
- **Sort options**: domain, designation, vintage, date added, price, drink-before. Default: domain A→Z then vintage oldest→newest.
- **UHF tag debouncing**: if the same EPC is read again within 5 s of the previous read of that EPC, the read is silently ignored. After any successful scan (consume or add), a 500 ms cooldown prevents the next scan from being processed immediately.
- **Multiple simultaneous tags**: if the reader detects several tags in one cycle, only the first is processed; the rest are discarded silently.
- **EPC as temporary association**: bottles are always identified internally by UUID. EPC is a mutable field — it is set on intake and cleared on consumption. The physical tag memory is never modified.
- **System-level errors in cellar**: slow blink for 3 s; error event is lost (not queued or retried) if the server is unreachable.
- **`cellar --console` flag**: for running `cellar` on a desktop Linux machine without Pi LEDs. LED sysfs paths have no default when `--console` is active; LED blinking is replaced by structured log entries (`"led starts blinking"` / `"led stops blinking"` with `led=PWR|SYS` attribute).
- **`cmd/` main files**: each `main.go` is limited to log initialisation, config loading, flag parsing, and signal handling. All functional logic — including gRPC client/server initialisation — lives in the corresponding `internal/` package (e.g. `internal/cellar`).
- **Manager reader scope**: RFID reader active only on "Add bottles" and "Read bottle" screens.
- **Manager reconnection**: auto-reconnect with exponential backoff; "serveur inaccessible" notification shown until connection restored.
- **Drink-before thresholds**: yellow = fewer than 12 months remaining; red = past the drink_before year.
- **Sort behaviour**: all sort keys are reversible; multiple sort columns can be stacked.
- **Read bottle flow**: scan triggers `GetBottleByEPC`; all subsequent operations use the returned internal UUID.
- **Bulk edit**: multi-selection in the inventory via Ctrl+click / Shift+click; bulk edit panel shows all editable fields blank; only filled fields are applied via `BulkUpdateBottles` with a `FieldMask`. `UpdateBottle` uses the same `BottleFields` + `FieldMask` pattern for consistency.
- **Partial updates**: both `UpdateBottle` and `BulkUpdateBottles` use `google.protobuf.FieldMask` to indicate which fields to write; absent fields are untouched.

---

## Configuration

All config files use **YAML** format.

### manager (desktop)

Uses Qt's `QSettings` for cross-OS config storage (resolves to the correct platform path automatically: `AppData\` on Windows, `~/.config/` on Linux/macOS).

Settings stored:
- Server address (default: `localhost:50051`)
- RFID reader port
- Log level and log format

### rpc-server and cellar (Linux only)

Config files read from `/etc/winetap/`:

| File                          | Used by      | Contents                                        |
|-------------------------------|--------------|-------------------------------------------------|
| `/etc/winetap/server.yaml` | `rpc-server` | Listen address, SQLite DB path, log level/format|
| `/etc/winetap/cellar.yaml` | `cellar`     | Server address, RFID port, LED sysfs paths, log level/format |

Missing file → startup error with a clear message.

**Default gRPC port: `50051`**, overridable in each config file.

---

## Logging

All three applications use the Go standard library `slog` package for structured logging.

### Configuration

| Setting      | Values                           | Default  |
|--------------|----------------------------------|----------|
| `log_level`  | `debug`, `info`, `warn`, `error` | `info`   |
| `log_format` | `plain`, `json`                  | `plain`  |

`rpc-server` and `cellar` read these from their YAML config files. `manager` exposes them in Qt Settings.

### Log levels

| Level   | What is logged                                                                          |
|---------|-----------------------------------------------------------------------------------------|
| `error` | Any error condition with context (unexpected failures, RPC errors, I/O faults)          |
| `info`  | Functional events: bottle added/consumed/deleted, event pushed/acknowledged, INAO refreshed, client connected/disconnected, server started |
| `debug` | Full payload of every RPC request and response sent or received                         |

### Rules for all code

- Use `slog.Default()` only at the entry point (`main`); everywhere else accept `*slog.Logger` as a dependency.
- All `error`-level logs must include the error value as `"error"` key.
- All `info`-level logs must include enough context to be actionable without reading the code (e.g. bottle ID, EPC, count).
- `debug`-level request/response logging is handled by a gRPC interceptor on the server — individual handlers do not need to repeat it.

---

## Database Migrations

Migrations are versioned SQL files applied automatically when `rpc-server` starts. A `schema_migrations` table tracks which have been applied.

```
internal/migrations/
  0001_initial.sql
  0002_add_drink_before.sql
  ...
```

Rules:
- Migrations are append-only — never edit an applied migration
- Applied in numeric order; server refuses to start if a migration fails
- Embedded in the binary at build time (Go `embed`)

---

## Deployment

Systemd unit files live in `deploy/systemd/`:

| File                        | Service        |
|-----------------------------|----------------|
| `winetap-server.service` | `rpc-server`   |
| `winetap-cellar.service` | `cellar`       |

Both units:
- `Restart=on-failure`
- `After=network.target`
- Run as a dedicated non-root user

Final packaging format (Debian package, Docker image, install script) is not yet decided.
