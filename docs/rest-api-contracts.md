# WineTap — API Contracts

The v2 REST API (English routes such as `/bottles`, `/scan/request`, `/scan/result`, used by the desktop manager) **no longer exists**. Since v3 the phone serves a JSON API under `/api/*`, designed for the embedded site, with French route and field names.

**The full contract (authentication, payloads, errors, events, JavaScript bridge) is [web/API.md](../web/API.md).** It is implemented by `mobile/lib/server/api/` and, in memory for development, by `web/mock/`.

## Conventions

- Base URL: `http://<phone IP>:8080` from a computer, `http://localhost:8080` in the app's WebView
- JSON bodies, `snake_case` fields; errors as `{ "erreur": "<code>", "message": "<French text>" }`
- Authentication: `wt_session` cookie for browsers approved on the phone, `X-WineTap-Token` for the app's WebView
- Without an authorized session, only `/api/session` and `/api/events` answer (401 otherwise)

## Routes

| Route | Purpose |
|-------|---------|
| `GET`, `POST /api/session` | Session state; request approval of this browser on the phone |
| `GET`, `POST /api/appellations` · `PUT`, `DELETE /api/appellations/:id` · `GET /api/appellations/:id/image` | Appellations (designations) and their image |
| `GET`, `POST /api/domaines` · `PUT`, `DELETE /api/domaines/:id` | Domains |
| `GET`, `POST /api/cuvees` · `PUT`, `DELETE /api/cuvees/:id` | Cuvées |
| `GET`, `POST /api/bouteilles` · `PUT`, `DELETE /api/bouteilles/:id` | Bottles in stock (`?consommees=1` to include consumed ones) |
| `POST /api/bouteilles/:id/consommer` | Consume a bottle without its tag |
| `POST /api/consommer` | Consume a bottle by tag |
| `GET /api/bouteilles/tag/:tag_id` | In-stock bottle carrying a tag |
| `GET /api/degustations` | Consumed bottles, newest first, paginated |
| `GET`, `PUT /api/reglages` | Shared settings (AI assistant) |
| `POST /api/scan` · `DELETE /api/scan/:id` | Ask the phone to read a tag (from a computer); cancel |
| `GET /api/sauvegarde` | Download the database file |
| `POST /api/restauration/examen` | Check a file to restore, without changing anything |
| `POST /api/restauration` | Replace the database with the uploaded file |
| `GET /api/events` | Server-sent events: `donnees`, `scan`, `session` |
