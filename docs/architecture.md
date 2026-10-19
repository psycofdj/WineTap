# WineTap — Architecture

## System Architecture

```
┌──────────────────────────┐              ┌──────────────────────────────────────┐
│  Desktop browser         │              │  Phone (Android / iOS)               │
│                          │  HTTP + SSE  │                                      │
│  WineTap site            │──── WiFi ───>│  shelf server (:8080)                │
│  (desktop layout)        │              │    /            embedded site        │
└──────────────────────────┘              │    /api/*       JSON API             │
                                          │    /api/events  server-sent events   │
                                          │  drift SQLite database               │
                                          │  NFC (nfc_manager)                   │
                                          │                                      │
                                          │  WebView -> http://localhost:8080    │
                                          │  (phone layout + JS bridge)          │
                                          │  Native screens N-E1 .. N-E4         │
                                          └──────────────────────────────────────┘
```

- The phone is the only server and holds the only copy of the data
- The same site serves both layouts: desktop from 720 px wide and 500 px high, phone otherwise (a phone in landscape keeps the phone layout)
- There is no discovery: the phone shows its address (N-E1) and the user types it in the browser

## Components

### Server (`mobile/lib/server/`)

- `server.dart` — builds the handler: `/api/*` routed by `shelf_router`, everything else served by the static site; pipeline = security middleware, then wakelock middleware. Listens on all IPv4 addresses, port 8080
- `server_lifecycle.dart` — starts the server, and restarts it (and the NFC session) when the app returns to the foreground, since the OS may have closed the socket
- `api/` — handlers: `system_api.dart` (session, events, settings, remote scan, backup/restore), `catalog_api.dart` (appellations, domaines, cuvées), `bottle_api.dart` (bouteilles, consumption, tastings), `security.dart` (Host/Origin/authorization), `json.dart`, `context.dart` (shared `ApiContext`)
- `database.dart` — drift schema and queries (see [data-models.md](./data-models.md))
- `db_holder.dart` — holds the open database; backup (WAL checkpoint then file read), inspection of a file to restore (SQLite header, the four tables, `user_version` ≤ 2), and replacement in place without restarting the app
- `sessions.dart` — browser identification, access requests, authorized sessions (hashes only), revocation, app token
- `events.dart` — server-sent events hub (`donnees`, `scan`, `session`); unauthorized browsers only receive `session`
- `remote_scan.dart` — one tag read at a time requested by a computer (`POST /api/scan`)
- `static_site.dart` — serves `assets/site/`; for the WebView, `/?jeton=<token>` sets the `wt_app` cookie and the bridge script is injected into `index.html`
- `preferences.dart` — key-value store interface and the shared settings (AI assistant: `claude` or `chatgpt`)
- `dev_seed.dart` — on dev builds (version 0.0.0), seeds a test catalogue when `bottles` is empty

### Native app (`mobile/lib/native/`)

- `app_shell.dart` — WebView opening `http://localhost:8080/?jeton=<token>`, with the native screens on top
- `bridge.dart` — native side of `window.winetapBridge`: `readTag`, `saveBackup`, `pickFile`, `openNative`, `openExternal`
- `address_screen.dart` (N-E1), `auth_sheet.dart` (N-E2), `connections_screen.dart` (N-E3), `nfc_screen.dart` (N-E4)
- `reading.dart` — `ReadingController`: runs every tag read through N-E4, local (bridge) or remote (`POST /api/scan`)
- `network.dart` — finds the phone's local IPv4 address (WiFi interface first)
- `prefs_store.dart` — `shared_preferences` implementation of the key-value store
- `theme.dart` — design tokens shared with the site

### Services (`mobile/lib/services/`)

- `nfc_service.dart` (+ `_android`, `_ios`) — NFC reading through `nfc_manager`
- `tag_id.dart` — tag id normalization (separators removed, uppercase hex)

### Site (`web/`)

Svelte 5 single-page application, built by Vite. `src/lib/api.js` and `session.js` call `/api` and listen to `/api/events`; `src/lib/nfc.js` reads a tag through the bridge in the app or through `POST /api/scan` from a computer. Screens are in `src/ecrans/telephone/` and `src/ecrans/ordinateur/`. See [web/README.md](../web/README.md).

## Security Model

There is no HTTPS. Access control relies on:

| Client | Authentication |
|--------|----------------|
| App WebView | Random token generated at each launch; passed once as `?jeton=` (sets the `wt_app` cookie, HttpOnly, SameSite=Strict), then as `X-WineTap-Token` header (or `?token=` for SSE and images). It never leaves the phone |
| Desktop browser | `wt_session` cookie (HttpOnly, SameSite=Strict) set by `POST /api/session`; the phone shows N-E2 (« Autoriser cette connexion ? ») with browser, system and IP address |

- Authorized sessions have no expiry; they are revoked one by one or all at once from N-E3
- Only SHA-256 hashes of session ids are stored, in the app preferences, with browser, OS, IP address, authorization date and last activity
- Pending and refused requests are kept in memory only
- `Host` must be `localhost` or an IP address (against DNS rebinding); `POST`, `PUT`, `PATCH`, `DELETE` require an `Origin` equal to `http://<Host>`
- Without an authorized session, only `GET`/`POST /api/session` and `GET /api/events` answer; everything else returns 401
- `index.html` is served with a Content-Security-Policy restricted to `'self'`

## NFC Reading Flow

Every tag read goes through the native N-E4 screen.

**In the app**

```
Site (WebView)                     App
  │── winetapBridge.readTag(objet) ─>│  N-E4 opens, NFC read
  │<── { tag_id } | { annule } ──────│  N-E4 closes
```

**From a desktop browser**

```
Browser                            Phone
  │── POST /api/scan {objet} ───────>│  RemoteScan.start → N-E4 « Demandé par un ordinateur »
  │<── 202 { id } ───────────────────│
  │                                  │  tag read (or cancelled)
  │<── SSE event: scan {id, statut, tag_id?}
  │── DELETE /api/scan/:id (cancel) ─>│
```

Only one remote read at a time (409 `occupe`). Consuming and identifying a bottle by its tag are only available in the app; intake and search by tag work from both.

## Live Updates

`GET /api/events` is a server-sent events stream (`retry: 5000`). After any data change the server sends `donnees` with what changed (`bouteilles`, `catalogue`, `reglages`); open pages reload the affected data. `scan` carries the result of a remote read, `session` the decision on the phone or a revocation.

## Configuration

No configuration file. Port 8080 is fixed. Settings (AI assistant) are edited in the site and stored in the app preferences.

## Deployment

- **Android**: signed app bundle, uploaded to Google Play (internal track) and attached to the GitHub release
- **iOS**: IPA uploaded to App Store Connect and attached to the GitHub release
- Built by `.github/workflows/release.yml` on a `v*` tag, after building the site
- No other server: the computer only needs a browser
