# WineTap — Data Models

## Overview

WineTap uses SQLite managed by the drift ORM on the phone (`mobile/lib/server/database.dart`). The database is named `winetap` and opened via `driftDatabase(name: 'winetap')` (platform-default path). Foreign keys are enabled via `PRAGMA foreign_keys = ON` in `beforeOpen`.

The schema is **unchanged since v2** (drift `schemaVersion = 2`, constraint C-01 of [specs/v3-web.md](../specs/v3-web.md)): a v2 database or backup opens in v3, and a v3 backup restores in v2. State specific to v3 is kept outside the database (see [below](#state-kept-outside-the-database)).

The API exposes these tables with French field names; the mapping is in [web/API.md](../web/API.md) §2–3.

## Entity Relationship Diagram

```
┌──────────────┐     ┌──────────────┐
│ designations │     │   domains    │
│──────────────│     │──────────────│
│ id (PK)      │     │ id (PK)      │
│ name (UNIQUE)│     │ name (UNIQUE)│
│ region       │     │ description  │
│ description  │     └──────┬───────┘
│ picture      │            │
└──────┬───────┘      ┌─────┴──────┐
       └──────────────┤   cuvees   │
                      │────────────│
                      │ id (PK)    │
                      │ name       │
                      │ domain_id  │──→ domains.id
                      │ designation│──→ designations.id
                      │   _id      │
                      │ color      │
                      │ description│
                      └─────┬──────┘
                            │
                      ┌─────┴──────┐
                      │  bottles   │
                      │────────────│
                      │ id (PK)    │
                      │ tag_id     │  UNIQUE, nullable
                      │ cuvee_id   │──→ cuvees.id
                      │ vintage    │
                      │ description│
                      │ purchase   │
                      │   _price   │
                      │ drink      │
                      │   _before  │
                      │ added_at   │
                      │ consumed_at│  null = in stock
                      └────────────┘
```

## Table Definitions

### bottles

The core entity — each row represents a physical bottle with an optional NFC tag.

| Column           | Type    | Constraints                  | Notes |
|------------------|---------|------------------------------|-------|
| `id`             | INTEGER | PRIMARY KEY, AUTOINCREMENT   | Internal identifier |
| `tag_id`         | TEXT    | UNIQUE, nullable             | Tag UID, uppercase hex without separators; **null after consumption** (freed). SQLite allows several NULLs |
| `cuvee_id`       | INTEGER | FOREIGN KEY → cuvees.id      | Wine reference |
| `vintage`        | INTEGER | NOT NULL                     | Vintage year (the API requires 1900 to the current year; old rows with 0 show as « NM ») |
| `description`    | TEXT    | default ''                   | Free-form notes, tasting comment |
| `purchase_price` | REAL    | nullable                     | Per-bottle price in euros |
| `drink_before`   | INTEGER | nullable                     | Last good year |
| `added_at`       | TEXT    | NOT NULL                     | ISO 8601 UTC timestamp, set on insert |
| `consumed_at`    | TEXT    | nullable                     | ISO 8601 UTC timestamp; null = in stock |

**Lifecycle:**
- **In stock**: `consumed_at` IS NULL, `tag_id` usually set
- **Consumed**: `consumed_at` is set, `tag_id` cleared to NULL (tag freed for reuse)
- **Hard delete**: for lost or damaged tags, or entry errors

Because the tag is cleared on consumption, the database cannot tell which bottle a freed tag was on. To answer « déjà consommée », the server keeps in memory, since its start, the association between freed tags and their bottle, and forgets it once the tag is put on another bottle.

### cuvees

A named wine produced by a domain under a designation.

| Column           | Type    | Constraints                       | Notes |
|------------------|---------|-----------------------------------|-------|
| `id`             | INTEGER | PRIMARY KEY, AUTOINCREMENT        | Internal identifier |
| `name`           | TEXT    | NOT NULL                          | Cuvée name |
| `domain_id`      | INTEGER | FOREIGN KEY → domains.id          | Producer |
| `designation_id` | INTEGER | FOREIGN KEY → designations.id, default 0 | Appellation (0 = unassigned) |
| `color`          | INTEGER | default 0                         | 0 = unknown, 1 = rouge, 2 = blanc, 3 = rosé, 4 = effervescent, 5 = autre |
| `description`    | TEXT    | default ''                        | Optional notes |

**Foreign key protection:** a cuvée referenced by a bottle, even consumed, cannot be deleted (API: 409 `referencee`).

### domains

Wine producers / estates / châteaux.

| Column        | Type    | Constraints                | Notes |
|---------------|---------|----------------------------|-------|
| `id`          | INTEGER | PRIMARY KEY, AUTOINCREMENT | Internal identifier |
| `name`        | TEXT    | UNIQUE, NOT NULL           | Producer name |
| `description` | TEXT    | default ''                 | Optional notes |

**Foreign key protection:** a domain referenced by a cuvée cannot be deleted.

### designations

AOC/AOP wine appellations.

| Column        | Type    | Constraints                | Notes |
|---------------|---------|----------------------------|-------|
| `id`          | INTEGER | PRIMARY KEY, AUTOINCREMENT | Internal identifier |
| `name`        | TEXT    | UNIQUE, NOT NULL           | Official appellation name |
| `region`      | TEXT    | default ''                 | Wine region |
| `description` | TEXT    | default ''                 | Optional notes |
| `picture`     | BLOB    | nullable                   | Image (in v3: a map locating the appellation); added in schema version 2 |

**Sentinel row:** `id = 0`, `name = '(unassigned)'` is inserted on database creation to represent cuvées with no appellation. The API hides it.

## Migration Strategy

- `schemaVersion = 2`; v3 adds no migration
- `onCreate`: creates all tables, inserts the sentinel designation, then seeds reference data (`seed_data.dart`: INAO AOC/AOP designations with their region, and a list of domains). Seeding is skipped for test databases (`AppDatabase.forTesting`)
- `onUpgrade`: from version 1, adds `designations.picture`
- `beforeOpen`: enables foreign keys
- Restoring a file (`db_holder.dart`) accepts a SQLite file containing the four tables with `user_version` ≤ 2; drift migrations run when it is reopened

On dev builds (version 0.0.0), `dev_seed.dart` also seeds a test catalogue with bottles when the `bottles` table is empty.

## State Kept Outside the Database

Stored in the app preferences (`shared_preferences`), not in the database, and therefore not included in backups:

| Key | Content |
|-----|---------|
| `v3.sessions` | Authorized browser sessions (JSON list): SHA-256 hash of the session id, browser, OS, last IP address, authorization date, last activity |
| `v3.assistant` | AI assistant for « Demander à l'IA »: `claude` (default) or `chatgpt` |

Pending and refused access requests, the app token, the freed-tag memory and the current remote scan live in memory only.
