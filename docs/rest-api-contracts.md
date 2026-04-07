# WineTap — REST API Contracts

## Overview

26 endpoints served by the phone (Dart shelf on port 8080). Desktop manager connects as HTTP client. All request/response bodies are JSON with `snake_case` field names. No authentication — WiFi-only trust model.

## Conventions

- **Base URL**: `http://<phone-ip>:8080`
- **Content-Type**: `application/json` for all requests and responses
- **Field naming**: `snake_case` throughout (matches database columns)
- **Timestamps**: RFC 3339 strings (e.g., `"2026-04-01T12:00:00Z"`)
- **Nullable fields**: omitted from JSON when null (not `"field": null`)
- **IDs**: integers (autoincrement)
- **Tag ID normalization**: server normalizes `tag_id` on all endpoints that accept it (strips colons, spaces, dashes; uppercases). Client can send any format — server stores canonical uppercase hex.
- **Partial updates**: on `PUT` endpoints, absent fields = don't update. Explicit `null` = clear the value. Handler uses `body.containsKey('field')` to distinguish.

## Error Format

All errors return a JSON body with an HTTP status code:

```json
{"error": "<code>", "message": "<human-readable description>"}
```

| HTTP Status | Error Code | Meaning |
|-------------|------------|---------|
| 400 | `invalid_argument` | Missing or malformed required field |
| 400 | `already_exists` | Unique constraint violation (name, tag_id) |
| 404 | `not_found` | Resource does not exist |
| 409 | `already_exists` | Conflict (e.g. scan already in progress) |
| 412 | `referenced` | Foreign key constraint violation (on delete: entity still referenced; on create/update: referenced entity does not exist) |
| 412 | `failed_precondition` | Sentinel entity cannot be deleted |
| 413 | `payload_too_large` | Upload exceeds size limit (restore) |
| 500 | `internal` | Unexpected server error |

---

## JSON Entity Shapes

### Designation

```json
{
  "id": 1,
  "name": "Madiran",
  "region": "Sud-Ouest",
  "description": ""
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | int | response only | autoincrement |
| `name` | string | yes | unique |
| `region` | string | no | |
| `description` | string | no | |

Note: `picture` (BLOB) excluded from JSON API for MVP. Served separately if needed later.

### Domain

```json
{
  "id": 1,
  "name": "Domaine Brumont",
  "description": ""
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | int | response only | autoincrement |
| `name` | string | yes | unique |
| `description` | string | no | |

### Cuvee

```json
{
  "id": 1,
  "name": "Château Montus",
  "domain_id": 1,
  "designation_id": 3,
  "color": 1,
  "description": "",
  "domain_name": "Domaine Brumont",
  "designation_name": "Madiran",
  "region": "Sud-Ouest"
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | int | response only | autoincrement |
| `name` | string | yes | |
| `domain_id` | int | yes | FK → domains.id |
| `designation_id` | int | no | FK → designations.id (0 = unassigned) |
| `color` | int | yes | enum: 0=unspecified, 1=rouge, 2=blanc, 3=rosé, 4=effervescent, 5=autre |
| `description` | string | no | |
| `domain_name` | string | response only | denormalized |
| `designation_name` | string | response only | denormalized |
| `region` | string | response only | denormalized from designation |

### Bottle

```json
{
  "id": 42,
  "tag_id": "04A32BFF",
  "cuvee_id": 1,
  "vintage": 2019,
  "description": "Acheté chez Nicolas",
  "purchase_price": 15.50,
  "drink_before": 2030,
  "added_at": "2026-03-15T10:30:00Z",
  "consumed_at": null,
  "cuvee": {
    "id": 1,
    "name": "Château Montus",
    "domain_id": 1,
    "color": 1,
    "domain_name": "Domaine Brumont",
    "designation_name": "Madiran",
    "region": "Sud-Ouest"
  }
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | int | response only | autoincrement |
| `tag_id` | string? | no | null after consumption; uppercase hex, no separators |
| `cuvee_id` | int | yes | FK → cuvees.id |
| `vintage` | int | yes | year |
| `description` | string | no | |
| `purchase_price` | float? | no | euros |
| `drink_before` | int? | no | year |
| `added_at` | string | response only | RFC 3339 |
| `consumed_at` | string? | response only | RFC 3339; null = in stock |
| `cuvee` | Cuvee | response only | denormalized, always included |

---

## Designation Endpoints

### GET /designations

List all designations ordered by name.

**Response**: `200`
```json
[
  {"id": 1, "name": "Madiran", "region": "Sud-Ouest", "description": ""},
  {"id": 2, "name": "Saint-Émilion", "region": "Bordeaux", "description": ""}
]
```

### POST /designations

Create a designation.

**Request**:
```json
{"name": "Cahors", "region": "Sud-Ouest", "description": ""}
```

**Response**: `201`
```json
{"id": 3, "name": "Cahors", "region": "Sud-Ouest", "description": ""}
```

**Errors**: `400 already_exists` (name unique)

### PUT /designations/:id

Update a designation.

**Request**:
```json
{"name": "Cahors", "region": "Sud-Ouest", "description": "Malbec country"}
```

**Response**: `200` — updated Designation

### DELETE /designations/:id

Delete a designation.

**Response**: `204` (no body)

**Errors**: `404 not_found`, `412 referenced` (referenced by cuvees)

---

## Domain Endpoints

### GET /domains

List all domains ordered by name.

**Response**: `200` — array of Domain

### POST /domains

**Request**: `{"name": "Domaine Brumont", "description": ""}`

**Response**: `201` — Domain

**Errors**: `400 already_exists`

### PUT /domains/:id

**Request**: `{"name": "Domaine Brumont", "description": "Madiran specialist"}`

**Response**: `200` — Domain

### DELETE /domains/:id

**Response**: `204`

**Errors**: `404`, `412 referenced` (referenced by cuvees)

---

## Cuvee Endpoints

### GET /cuvees

List all cuvees ordered by domain then name. Response includes denormalized fields.

**Response**: `200` — array of Cuvee

### POST /cuvees

**Request**:
```json
{
  "name": "Château Montus",
  "domain_id": 1,
  "designation_id": 3,
  "color": 1,
  "description": ""
}
```

**Response**: `201` — Cuvee (with denormalized fields)

### PUT /cuvees/:id

**Request**: same shape as POST

**Response**: `200` — Cuvee

### DELETE /cuvees/:id

**Response**: `204`

**Errors**: `404`, `412 referenced` (referenced by bottles)

---

## Bottle Endpoints

### GET /bottles

List bottles. Query parameter `include_consumed=true` to include consumed bottles (default: in-stock only).

**Response**: `200` — array of Bottle (with denormalized cuvee)

### GET /bottles/:id

Get a single bottle by ID.

**Response**: `200` — Bottle

**Errors**: `404`

### GET /bottles/by-tag/:tag_id

Get the in-stock bottle associated with a tag ID.

**Response**: `200` — Bottle

**Errors**: `404 not_found` (no in-stock bottle with this tag)

### POST /bottles

Add a new bottle.

**Request**:
```json
{
  "tag_id": "04A32BFF",
  "cuvee_id": 1,
  "vintage": 2019,
  "description": "Acheté chez Nicolas",
  "purchase_price": 15.50,
  "drink_before": 2030
}
```

**Response**: `201` — Bottle

**Errors**: `400 already_exists` (tag_id in use), `412 referenced` (cuvee_id does not exist)

### POST /bottles/consume

Consume a bottle by tag ID.

**Request**:
```json
{"tag_id": "04A32BFF"}
```

**Response**: `200` — Bottle (consumed, with consumed_at set and tag_id cleared)

**Errors**: `404 not_found` (no in-stock bottle with this tag)

### PUT /bottles/:id

Partial update a bottle. Only provided fields are written.

**Request** (only include fields to update):
```json
{
  "cuvee_id": 2,
  "vintage": 2020
}
```

**Response**: `200` — Bottle

**Errors**: `404`, `400 already_exists` (tag_id in use), `412 referenced` (cuvee_id does not exist)

### DELETE /bottles/:id

Hard delete a bottle.

**Response**: `204`

**Errors**: `404`

---

## Completions Endpoint

### GET /completions

Autocomplete search. Used by manager form fields.

**Query parameters**:
- `field` — one of: `designation`, `domain`, `cuvee`
- `prefix` — search prefix string

**Response**: `200`
```json
{"values": ["Madiran", "Margaux", "Médoc"]}
```

---

## Scan Coordination Endpoints

### POST /scan/request

Manager initiates a scan request. Phone auto-starts NFC and shows the intake screen.

**Request**: no body required

**Response**: `201`
```json
{"status": "requested"}
```

**Errors**: `409 already_exists` (scan already in progress)

### GET /scan/result

**Long polling.** Manager calls this and the phone holds the connection open until:
- A tag is scanned → responds with tag_id
- 30s timeout → responds with 204 (manager retries)
- Scan is cancelled → responds with 410

**Response (tag scanned)**: `200`
```json
{"status": "resolved", "tag_id": "04A32BFF"}
```

**Response (timeout)**: `204` — empty body, manager retries

**Response (cancelled)**: `410`
```json
{"status": "cancelled"}
```

### POST /scan/cancel

Manager cancels the pending scan request. Phone stops NFC session and returns to idle.

**Response**: `200`
```json
{"status": "cancelled"}
```

---

## Backup/Restore Endpoints

### GET /backup

Download the SQLite database file.

**Response**: `200` with `Content-Type: application/octet-stream`
- Body: raw SQLite file bytes
- Header: `Content-Disposition: attachment; filename="winetap.db"`

### POST /restore

Upload a SQLite database file to replace the current one.

**Request**: `Content-Type: application/octet-stream` — raw SQLite file bytes

**Response**: `200`
```json
{"status": "restored"}
```

**Behavior**: Replaces the current database atomically. Server restarts with new data.

---

## Type Reference

| JSON type | Dart type | Go type | SQLite type |
|-----------|-----------|---------|-------------|
| `int` | `int` | `int64` | `INTEGER` |
| `float` | `double` | `float64` | `REAL` |
| `string` | `String` | `string` | `TEXT` |
| `string?` (nullable) | `String?` | `*string` | `TEXT` (nullable) |
| `int?` (nullable) | `int?` | `*int32` | `INTEGER` (nullable) |
| `float?` (nullable) | `double?` | `*float64` | `REAL` (nullable) |
| `bool` | `bool` | `bool` | `INTEGER` (0/1) |

## Route Summary

| Method | Path | Description |
|--------|------|-------------|
| GET | / | Health check |
| GET | /designations | List all |
| POST | /designations | Create |
| PUT | /designations/:id | Update |
| DELETE | /designations/:id | Delete |
| GET | /domains | List all |
| POST | /domains | Create |
| PUT | /domains/:id | Update |
| DELETE | /domains/:id | Delete |
| GET | /cuvees | List all |
| POST | /cuvees | Create |
| PUT | /cuvees/:id | Update |
| DELETE | /cuvees/:id | Delete |
| GET | /bottles | List (query: include_consumed) |
| GET | /bottles/:id | Get by ID |
| GET | /bottles/by-tag/:tag_id | Get by tag |
| POST | /bottles | Add |
| POST | /bottles/consume | Consume by tag |
| PUT | /bottles/:id | Partial update |
| DELETE | /bottles/:id | Delete |
| GET | /completions | Autocomplete |
| POST | /scan/request | Initiate scan |
| GET | /scan/result | Long-poll for result |
| POST | /scan/cancel | Cancel scan |
| GET | /backup | Download database |
| POST | /restore | Upload database |
| **Total** | **26 routes** | |
