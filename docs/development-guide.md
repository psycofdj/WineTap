# WineTap — Development Guide

## Prerequisites

| Requirement | Version / Details |
|-------------|-------------------|
| Node.js | 22 (see `web/.nvmrc`) |
| Flutter SDK | stable, Dart 3.11+ |
| Android SDK | API 26+ device or emulator |
| Xcode | for iOS builds (macOS) |
| NFC hardware | Physical phone for NFC testing |

## Web Site (`web/`)

```bash
cd web
npm install
npm run dev      # http://localhost:5173, mock API and simulated phone
npm run check    # svelte-check
npm run build    # dist/
```

`npm run dev` plugs into Vite a server (`web/mock/`) that implements [web/API.md](../web/API.md) in memory, with a cellar of about 180 bottles. A « Téléphone simulé » panel plays the phone: approve or refuse a connection, answer a tag read, cut the phone off. Useful URL parameters:

| Parameter | Effect |
|-----------|--------|
| `?app` | Simulates the app's WebView (simulated `window.winetapBridge`, imitation of N-E4) |
| `?mock_auth=attente` | This browser must be approved from the panel |
| `?nodev` | Hides the simulated phone panel |

See [web/README.md](../web/README.md) for the site's organisation.

## Mobile App (`mobile/`)

The site must be built into the app's assets before any Flutter build:

```bash
./scripts/build_web.sh        # web/ → mobile/assets/site/ (not versioned)
cd mobile
flutter pub get
flutter run
```

The app starts the HTTP server on port 8080 and shows the site in a WebView. On dev builds (version `0.0.0`, the version in `pubspec.yaml`), an empty `bottles` table is seeded with a test catalogue.

To try the real server with the built site in a desktop browser, without a phone:

```bash
./scripts/build_web.sh
cd mobile
WINETAP_E2E=1 WINETAP_E2E_SECONDES=300 flutter test test/e2e/serve_test.dart
# then open http://127.0.0.1:8099/ (connections are approved automatically)
```

`scripts/build_packages.sh` builds a signed Android package locally, with secrets read from a KeePassXC vault.

## Code Conventions (mobile)

- **`lib/server/`**: no Flutter UI code; the handler is built from an `ApiContext` (database holder, sessions, events, remote scan, settings) so tests can run it directly
- **`lib/native/`**: WebView shell, bridge and the four native screens only; all other UI is in the site
- **State outside the database**: through the `KeyValueStore` interface (`shared_preferences` in the app, `MemoryStore` in tests)
- **Logging**: `dart:developer` `log()` with a `name:` tag
- **Language**: API routes, fields, error messages and UI strings in French; code identifiers and comments in English

## Testing

```bash
cd web && npm run check

cd mobile
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

- `test/server/` — database tests (in-memory SQLite), dev seed, and API tests (`test/server/api/`: catalogue, bottles, system, security) that call the shelf handler directly
- `test/native/` — bridge, reading controller and widget tests of the native screens
- `test/services/` — NFC service (fake) and tag id normalization
- `test/e2e/serve_test.dart` — skipped unless `WINETAP_E2E=1`

## Continuous Integration and Releases

| Workflow | Trigger | Steps |
|----------|---------|-------|
| `web-ci.yml` | Pull requests touching `web/` | `npm ci`, `svelte-check`, build |
| `mobile-ci.yml` | Pull requests touching `mobile/` or `web/` | Build the site, `dart format`, `flutter analyze`, `flutter test` |
| `release.yml` | `v*` tag | Build the site; signed Android app bundle uploaded to Google Play (internal track); iOS IPA uploaded to App Store Connect; both attached to the GitHub release |

The repository is public: [psycofdj/WineTap](https://github.com/psycofdj/WineTap).
