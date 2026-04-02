# WineTap — Development Guide

## Prerequisites

### Mobile (Flutter)

| Requirement      | Version / Details                               |
|------------------|-------------------------------------------------|
| Flutter SDK      | 3.x (includes Dart 3.x)                         |
| Android SDK      | API 26+ target device or emulator               |
| NFC hardware     | Physical Android device for NFC testing         |

### Manager (Go)

| Requirement      | Version / Details                               |
|------------------|-------------------------------------------------|
| Go               | 1.26+                                           |
| Qt6 development  | Qt6 headers + miqt CGo bindings                 |
| RFID reader      | Chafon CF-RU5102 (optional — hardware testing)  |
| Chrome/Chromium  | Required for AI auto-fill (ChromeDP)            |

## Getting Started

### Mobile

```bash
cd mobile

# Install Flutter dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Run tests
flutter test
```

### Manager

```bash
# Install Go dependencies
go mod download

# Build manager binary
make build-manager
# Output: bin/winetap-manager

# Run manager
./bin/winetap-manager
```

## Build Targets (manager)

| Target           | Command              | Output                      |
|------------------|----------------------|-----------------------------|
| Manager          | `make build-manager` | `bin/winetap-manager`    |
| All binaries     | `make build`         | All in `bin/`               |
| Clean            | `make clean`         | Removes `bin/`              |

## Running Locally

### Mobile

```bash
cd mobile
flutter run
```

The app starts a shelf HTTP server on port 8080 and advertises itself via mDNS (`_winetap._tcp`). The server is visible on the local WiFi network as soon as the app is open.

### Manager

```bash
./bin/winetap-manager
```

Config is auto-created at `~/.config/winetap/manager.yaml` on first save from the Settings screen. The manager can auto-discover the phone's IP via mDNS, or it can be set manually in Settings.

**Config fields** (`manager.yaml`):
```yaml
phone_address: "192.168.1.x:8080"  # override if mDNS is not available
rfid_port: "/dev/ttyUSB0"          # serial port for RFID reader
log_level: "info"
log_format: "text"
```

## Project Structure Conventions

### Mobile

- **`lib/server/`**: HTTP handlers, database, scan coordinator — no Flutter imports
- **`lib/providers/`**: ChangeNotifier state — no direct HTTP handler calls
- **`lib/screens/`**: UI only — reads providers via `context.watch`, calls via `context.read`
- **Logging**: `dart:developer`'s `log()` function with `name:` tag. HTTP requests logged by shelf middleware.
- **Dependency injection**: providers receive dependencies via constructor; NfcService is injectable (mock for tests)

### Manager

- **`cmd/`**: Entry points only — config loading, flag parsing, signal handling
- **`internal/`**: All business logic
- **Logging**: Always `log/slog`. Accept `*slog.Logger` as dependency; never `slog.Default()` outside main
- **Error logs**: Must include `"error"` key with the error value
- **HTTP logging**: All requests/responses logged at `slog.Info` in `internal/client/http_client.go`

## Testing

### Mobile

```bash
cd mobile

# Run all tests
flutter test

# Run specific test file
flutter test test/providers/scan_provider_test.dart -v
```

Tests use in-memory SQLite (`NativeDatabase.memory()`) and a mock NfcService. `ScanCoordinator` uses short timeouts (`Duration(milliseconds: 100)`) in test setup.

### Manager

```bash
# Run all tests
go test ./...

# Run specific package
go test ./internal/manager/... -v
```

## RFID Reader Setup (manager)

### CF-RU5102

- USB serial at 57600 baud (8N1)
- Typically appears as `/dev/ttyUSB0`
- User needs permission: add to `dialout` group or use udev rule

```bash
sudo usermod -aG dialout $USER
# Log out and back in
```

## End-to-End Local Testing

1. Start mobile app on Android device connected to WiFi
2. Start manager: `./bin/winetap-manager`
3. Manager discovers phone via mDNS automatically (or enter IP in Settings)
4. Use "Add Bottles" screen: manager sends POST /scan/request → phone shows intake screen → scan tag with phone → manager saves bottle

No Raspberry Pi, no cloud, no gRPC — everything runs on local WiFi between phone and desktop.
