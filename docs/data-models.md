# WineTap — Data Models

## Overview

WineTap uses SQLite managed by the drift ORM on the Android phone. The database is named `winetap` and opened via `driftDatabase(name: 'winetap')` (platform-default path). Foreign keys are enabled via `PRAGMA foreign_keys = ON` in `beforeOpen`. Schema migrations are managed by drift's `MigrationStrategy`.

## Entity Relationship Diagram

```
┌──────────────┐     ┌──────────────┐
│ designations │     │   domains    │
│──────────────│     │──────────────│
│ id (PK)      │     │ id (PK)      │
│ name (UNIQUE)│     │ name (UNIQUE)│
│ region       │     │ description  │
│ description  │     └──────┬───────┘
└──────┬───────┘            │
       │              ┌─────┴──────┐
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
                      │ tag_id     │  UNIQUE (among non-null)
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

The core entity — each row represents a physical bottle with an optional RFID tag.

| Column          | Type    | Constraints                       | Notes                                                   |
|-----------------|---------|-----------------------------------|---------------------------------------------------------|
| `id`            | INTEGER | PRIMARY KEY, AUTOINCREMENT        | Internal identifier                                     |
| `tag_id`        | TEXT    | UNIQUE (partial: non-null only)   | Scanned NFC/RFID tag hex; **null after consumption** (freed) |
| `cuvee_id`      | INTEGER | FOREIGN KEY → cuvees.id           | Wine reference                                          |
| `vintage`       | INTEGER | NOT NULL                          | Year of the vintage                                     |
| `description`   | TEXT    | default ''                        | Free-form user notes                                    |
| `purchase_price`| REAL    | nullable                          | Per-bottle price in euros                               |
| `drink_before`  | INTEGER | nullable                          | Last good year                                          |
| `added_at`      | TEXT    | NOT NULL                          | RFC 3339 UTC timestamp — set on insert                  |
| `consumed_at`   | TEXT    | nullable                          | RFC 3339 UTC timestamp — null = in stock                |

**Lifecycle:**
- **In stock**: `consumed_at` IS NULL, `tag_id` is set
- **Consumed**: `consumed_at` is set, `tag_id` cleared to NULL (tag freed for reuse)
- **Hard delete**: only for lost/damaged tag recovery

### cuvees

A named wine selection produced by a domain under a designation.

| Column           | Type    | Constraints                    | Notes                             |
|------------------|---------|--------------------------------|-----------------------------------|
| `id`             | INTEGER | PRIMARY KEY, AUTOINCREMENT     | Internal identifier               |
| `name`           | TEXT    | NOT NULL                       | Cuvée name                        |
| `domain_id`      | INTEGER | FOREIGN KEY → domains.id       | Producer                          |
| `designation_id` | INTEGER | FOREIGN KEY → designations.id  | Appellation (0 = unassigned)      |
| `color`          | INTEGER | default 0                      | Enum: 0=unspecified, 1=rouge, 2=blanc, 3=rosé, 4=effervescent, 5=autre |
| `description`    | TEXT    | default ''                     | Optional notes                    |

**Foreign key protection:** Cannot delete a cuvee that has bottles referencing it.

### domains

Wine producers / estates / châteaux.

| Column        | Type    | Constraints                | Notes               |
|---------------|---------|----------------------------|---------------------|
| `id`          | INTEGER | PRIMARY KEY, AUTOINCREMENT | Internal identifier |
| `name`        | TEXT    | UNIQUE, NOT NULL           | Producer name       |
| `description` | TEXT    | default ''                 | Optional notes      |

**Foreign key protection:** Cannot delete a domain that has cuvees referencing it.

### designations

AOC/AOP wine appellations, populated from INAO open data or entered manually.

| Column        | Type    | Constraints                | Notes                     |
|---------------|---------|----------------------------|---------------------------|
| `id`          | INTEGER | PRIMARY KEY, AUTOINCREMENT | Internal identifier       |
| `name`        | TEXT    | UNIQUE, NOT NULL           | Official appellation name |
| `region`      | TEXT    | default ''                 | Wine region               |
| `description` | TEXT    | default ''                 | Optional notes            |

**Sentinel row:** `id=0`, `name='(unassigned)'` is inserted on database creation to represent cuvees with no appellation.

## Migration Strategy

- Schema version declared in `AppDatabase.schemaVersion`
- `MigrationStrategy.onCreate` creates all tables and seeds the sentinel designation
- `MigrationStrategy.beforeOpen` enables foreign keys
- Managed entirely by drift — no hand-written SQL migration files

## SQLite Configuration

```dart
await customStatement('PRAGMA foreign_keys = ON');  // in beforeOpen
```

Drift's default connection uses a single isolate with WAL mode enabled by `drift_flutter`.
