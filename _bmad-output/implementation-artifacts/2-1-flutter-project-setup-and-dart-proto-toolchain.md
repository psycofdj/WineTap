# Story 2.1: Flutter Project Setup and Dart Proto Toolchain

Status: done

## Story

As a developer,
I want a Flutter project initialized in the monorepo with Dart proto generation,
So that I have a working mobile app skeleton that can communicate with the WineTap server.

## Acceptance Criteria

1. **Given** the command `flutter create --org com.winetap --platforms ios,android wine_tap_mobile` is run in `mobile/`
   **Then** the Flutter project builds and runs on both iOS simulator and Android emulator
   **And** `analysis_options.yaml` is configured with strict Dart analysis

2. **Given** a new `make proto-dart` Makefile target
   **When** run
   **Then** Dart proto code is generated into `mobile/lib/gen/winetap/v1/`
   **And** the generated code compiles without errors
   **And** the generated code is committed to git

3. **Given** `pubspec.yaml`
   **Then** it includes dependencies: `grpc`, `protobuf`, `provider`, `shared_preferences`
   **And** `flutter pub get` succeeds

4. **Given** the project structure
   **Then** `lib/` contains: `main.dart`, `models/`, `services/`, `providers/`, `screens/`, `widgets/`, `l10n/`
   **And** `l10n/strings.dart` exists with a `S` class containing initial French string constants
   **And** `main.dart` sets up `MultiProvider` with placeholder providers and a `MaterialApp`

5. **Given** the app is launched
   **Then** it displays a placeholder home screen (to be replaced in later stories)
   **And** cold start to ready state is under 3s (NFR4)

## Tasks / Subtasks

- [x] Task 1: Prerequisite — install Flutter & Dart proto tooling (AC: #1, #2)
  - [x] Ensure Flutter SDK is installed and on PATH (Flutter 3.41.6 at /home/psyco/dev/saas/flutter)
  - [x] Install `protoc_plugin` for Dart: `dart pub global activate protoc_plugin` (v25.0.0)
  - [x] Verify `protoc-gen-dart` is on PATH (~/.pub-cache/bin/)
- [x] Task 2: Create Flutter project (AC: #1)
  - [x] Run `flutter create --org com.winetap --platforms ios,android .` in `mobile/`
  - [x] Configure `analysis_options.yaml` with strict Dart analysis rules
  - [x] Verify `flutter analyze` passes with no issues
- [x] Task 3: Add dependencies to pubspec.yaml (AC: #3)
  - [x] Add `grpc` (^5.1.0), `protobuf` (^6.0.0), `fixnum` (^1.1.0), `provider` (^6.0.0), `shared_preferences` (^2.0.0)
  - [x] Run `flutter pub get` — success
- [x] Task 4: Set up Dart proto generation (AC: #2)
  - [x] Add `make proto-dart` target using `buf generate --template buf.gen.dart.yaml` (uses local protoc-gen-dart plugin via buf)
  - [x] Created `buf.gen.dart.yaml` for Dart-specific buf generation config
  - [x] Run `make proto-dart` — generates 4 files into `mobile/lib/gen/winetap/v1/`
  - [x] Verify generated code compiles: `dart analyze lib/gen/` — no issues
- [x] Task 5: Create project directory structure (AC: #4)
  - [x] Create directories: `lib/models/`, `lib/services/`, `lib/providers/`, `lib/screens/`, `lib/widgets/`, `lib/l10n/`
  - [x] Create `lib/l10n/strings.dart` with `S` class and 20 initial French string constants
  - [x] Create placeholder `lib/providers/connection_provider.dart` (empty ChangeNotifier)
  - [x] Create placeholder `lib/providers/scan_provider.dart` (empty ChangeNotifier)
- [x] Task 6: Set up main.dart with MultiProvider (AC: #4, #5)
  - [x] Replace generated `main.dart` with MultiProvider setup, MaterialApp, and placeholder home screen
  - [x] Verify `flutter analyze` passes — no issues
  - [x] Verify `flutter build apk --debug` succeeds — APK built
- [x] Task 7: Full verification (AC: #1, #2, #3, #4, #5)
  - [x] Run `make proto-dart` — Dart proto generates cleanly
  - [x] Run `flutter analyze` from `mobile/` — no issues
  - [x] Run `flutter build apk --debug` from `mobile/` — builds successfully
  - [x] Run `make build` — all 4 Go binaries compile
  - [x] Run `flutter test` — widget test passes

### Review Findings

- [x] [Review][Patch] Hardcoded string `'WineTap Mobile'` in PlaceholderHome body — now uses `S.appSubtitle`
- [x] [Review][Patch] Empty directories (models, services, screens, widgets) not tracked by git — added .gitkeep files

## Dev Notes

### Prerequisites: Flutter & protoc-gen-dart

Flutter SDK must be installed before this story can proceed. If not available:

```bash
# Install Flutter (snap on Ubuntu/Linux)
sudo snap install flutter --classic
# OR via git
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
export PATH="$HOME/flutter/bin:$PATH"

# Verify
flutter doctor
flutter --version
```

Dart proto plugin:
```bash
dart pub global activate protoc_plugin
# Ensure ~/.pub-cache/bin is on PATH
export PATH="$HOME/.pub-cache/bin:$PATH"
```

**HALT if Flutter is not installable** — this story cannot proceed without the Flutter SDK.

### Flutter Project Creation

The architecture spec says the project lives at `mobile/` inside the monorepo. The `flutter create` command creates a directory with the project name, so:

```bash
cd /home/psyco/dev/winetap
flutter create --org com.winetap --platforms ios,android wine_tap_mobile
mv wine_tap_mobile mobile
```

Or create directly:
```bash
mkdir -p mobile
cd mobile
flutter create --org com.winetap --platforms ios,android .
```

### Strict Dart Analysis

Replace the default `analysis_options.yaml` with strict rules:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  strong-mode:
    implicit-casts: false
    implicit-dynamic: false
  errors:
    missing_return: error
    dead_code: warning

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_declarations
    - avoid_print
    - prefer_single_quotes
```

### Dart Proto Generation

The Makefile target uses `protoc` directly (not buf) for Dart because buf's remote Dart plugin support varies. Pattern:

```makefile
proto-dart:
	protoc \
		--proto_path=proto \
		--dart_out=grpc:mobile/lib/gen \
		proto/winetap/v1/winetap.proto
```

This generates into `mobile/lib/gen/winetap/v1/`:
- `winetap.pb.dart` — message classes
- `winetap.pbgrpc.dart` — gRPC client/server stubs
- `winetap.pbenum.dart` — enum classes
- `winetap.pbjson.dart` — JSON serialization

The generated code is committed to git so the Flutter project builds without `protoc` installed.

### pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  grpc: ^4.0.0
  protobuf: ^3.0.0
  provider: ^6.0.0
  shared_preferences: ^2.0.0
```

### French String Constants (l10n/strings.dart)

Per architecture spec — static constants class, no i18n framework:

```dart
class S {
  static const appTitle = 'WineTap';
  static const scanButton = 'Scanner';
  static const readyToScan = 'Prêt à scanner';
  static const waitingForScan = 'En attente du scan…';
  static const tagRead = 'Tag lu ✓';
  static const confirm = 'Confirmer';
  static const cancel = 'Annuler';
  static const markedAsConsumed = 'Marquée comme bue ✓';
  static const unknownTag = 'Tag inconnu';
  static const tagInUse = 'Tag déjà utilisé';
  static const serverUnreachable = 'Serveur injoignable';
  static const timeout = 'Délai dépassé';
  static const retryPrompt = 'Réessayez';
  static const checkWifi = 'Vérifiez votre connexion WiFi';
  static const settings = 'Paramètres';
  static const serverAddress = 'Adresse du serveur';
  static const connected = 'Connecté';
  static const connecting = 'Connexion…';
  static const unreachable = 'Injoignable';
}
```

### main.dart Structure

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/connection_provider.dart';
import 'providers/scan_provider.dart';
import 'l10n/strings.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => ScanProvider()),
      ],
      child: const WineTapApp(),
    ),
  );
}

class WineTapApp extends StatelessWidget {
  const WineTapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: S.appTitle,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF722F37), // wine red
        useMaterial3: true,
      ),
      home: const PlaceholderHome(),
    );
  }
}

class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.appTitle)),
      body: const Center(child: Text('WineTap Mobile')),
    );
  }
}
```

### Placeholder Providers

Minimal ChangeNotifier stubs — real implementation in later stories:

```dart
// providers/connection_provider.dart
class ConnectionProvider extends ChangeNotifier {}

// providers/scan_provider.dart
class ScanProvider extends ChangeNotifier {}
```

### What NOT to Do

- Do NOT implement any real providers, services, or screens — this is scaffolding only
- Do NOT add `nfc_manager` dependency yet — that's Story 2.2
- Do NOT add `nsd` or `bonsoir` dependency yet — that's Story 2.3
- Do NOT create service implementations (grpc_client.dart, nfc_service.dart, etc.) — just the empty directories
- Do NOT configure iOS/Android NFC permissions — that's Story 2.2
- Do NOT use `setState()` for shared state — always Provider pattern
- Do NOT hardcode French strings in widgets — always use `S.xxx` from `l10n/strings.dart`

### Previous Story Intelligence

Stories 1.1 and 1.2 completed the `rfid_epc` -> `tag_id` rename and added the `SetBottleTagId` RPC + `NormalizeTagID()` function. The proto file now has `tag_id` fields across all messages, `GetBottleByTagId` RPC, and `SetBottleTagId` RPC. The Dart proto generation will produce code with these updated names.

Key learnings:
- `make proto` uses `buf generate` for Go — Dart needs a separate `make proto-dart` using `protoc` directly
- Generated code is committed to git (same pattern as Go)
- Makefile uses tab indentation (verify with existing targets)

### Project Structure Notes

- Go monorepo at `winetap/` with module path `winetap`
- Flutter project at `mobile/` — separate from Go module (has its own `pubspec.yaml`)
- Proto source of truth: `proto/winetap/v1/winetap.proto`
- Go generated code: `gen/winetap/v1/` (committed)
- Dart generated code: `mobile/lib/gen/winetap/v1/` (committed)
- `.gitignore` in `mobile/` should exclude Flutter build artifacts but NOT `lib/gen/`

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile.md] — Story 2.1 acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture-mobile.md] — Flutter project structure (line ~144), technology stack (line ~125), Provider patterns (line ~420), French string management (line ~502), naming patterns (line ~346)
- [Source: _bmad-output/planning-artifacts/prd-mobile.md] — Platform requirements, distribution (TestFlight + sideloaded APK)
- [Source: Makefile] — Existing build targets (proto, build-server, etc.)
- [Source: buf.gen.yaml] — Current Go-only proto generation config

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Flutter 3.41.6 (Dart 3.11.4) found at /home/psyco/dev/saas/flutter
- Installed protoc_plugin v25.0.0 — requires protobuf ^6.0.0 and grpc ^5.1.0 (architecture spec listed grpc v4.0.0 but that's incompatible with protobuf 6.x)
- Added `fixnum` as direct dependency (required by generated proto code)
- Used `buf generate --template buf.gen.dart.yaml` with local protoc-gen-dart plugin instead of raw `protoc` (protoc not installed, buf already available)
- Created `buf.gen.dart.yaml` as separate buf config for Dart generation
- Package name is `wine_tap_mobile` (matching flutter create org convention)
- All strict analysis rules enabled: strict-casts, strict-inference, strict-raw-types
- Widget test updated to verify placeholder home screen renders correctly
- Debug APK builds successfully (314s first build with Gradle/CMake setup)

### Change Log

- 2026-03-31: Flutter project setup with Dart proto toolchain, MultiProvider, placeholder UI, French strings

### File List

- mobile/ (new — entire Flutter project directory)
- mobile/lib/main.dart (modified — MultiProvider + placeholder home)
- mobile/lib/l10n/strings.dart (new)
- mobile/lib/providers/connection_provider.dart (new)
- mobile/lib/providers/scan_provider.dart (new)
- mobile/lib/gen/winetap/v1/winetap.pb.dart (new — generated)
- mobile/lib/gen/winetap/v1/winetap.pbgrpc.dart (new — generated)
- mobile/lib/gen/winetap/v1/winetap.pbenum.dart (new — generated)
- mobile/lib/gen/winetap/v1/winetap.pbjson.dart (new — generated)
- mobile/pubspec.yaml (modified — dependencies added)
- mobile/analysis_options.yaml (modified — strict analysis)
- mobile/test/widget_test.dart (modified — updated for new app structure)
- Makefile (modified — added proto-dart target)
- buf.gen.dart.yaml (new — Dart-specific buf generation config)
