---
title: "Product Brief: WineTap Mobile"
status: "final"
created: "2026-03-30"
updated: "2026-03-30"
inputs:
  - docs/project-overview.md
  - docs/architecture.md
  - docs/api-contracts.md
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
  - proto/winetap/v1/winetap.proto
---

# Product Brief: WineTap Mobile

## Executive Summary

WineTap Mobile is a cross-platform companion app (iOS + Android) that turns any smartphone into an NFC scanner for the WineTap cellar management system. It replaces the dedicated UHF RFID hardware with the phone's built-in NFC reader, simplifying the system from three specialized components down to two — a desktop manager and a phone.

Today, adding a bottle to the cellar requires a desktop PC connected to a USB RFID reader, and consuming a bottle requires a Raspberry Pi running 24/7 with its own reader. Both devices are anchored to fixed locations. WineTap Mobile removes this hardware dependency: tap a bottle's NFC tag with your phone during intake (coordinated with the desktop manager) or walk to the cellar and tap to consume. The phone you already carry becomes the universal scanner.

This is a personal tool first — built for the creator and a fellow hobbyist wine collector — but designed with product-grade UX so it could serve anyone interested in a self-hosted, subscription-free wine cellar system. Your cellar, your data, no cloud, no recurring fees.

## The Problem

The current WineTap system works, but its hardware requirements create friction:

- **Fixed-location scanning.** The UHF RFID reader is USB-tethered to a desktop or RPi. You must walk to the device, not the other way around.
- **Dedicated hardware.** The Chafon CF-RU5102 reader costs ~€150, requires custom driver code, and only runs on Linux. It's a single-purpose device.
- **24/7 server dependency.** The cellar exit scanner needs the RPi running around the clock — just to catch the moment someone pulls a bottle. Overkill for a personal cellar.
- **No mobile interaction.** Checking what's in the cellar or marking a bottle as consumed means sitting at the desktop. There is no way to interact with the system on the go.

For a hobbyist with 100-300 bottles, this setup is over-engineered. The phone in your pocket already has an NFC reader. It's always with you. It's the obvious scanner.

## The Solution

A Flutter-based mobile app with two core flows:

**Consume flow (standalone):** Walk to the cellar, open the app, tap "Scan", hold the phone to a bottle's NFC tag. The app reads the tag UID, calls the server, and confirms with bottle details (cuvée, vintage, domain). Two taps and a tap-to-tag. Note: on iOS, the system presents a mandatory NFC scan sheet (~1s overhead); the consume target is under 3 seconds from scan initiation to confirmation, excluding app launch.

**Intake flow (coordinated with manager):** On the desktop manager, fill in the bottle details and hit "Scan". The mobile app shows that the manager is waiting. The user taps "Ready to Scan" on the phone, then holds it to the bottle. The tag UID flows back through the server to the manager, completing the form. The phone acts as a wireless NFC reader for the desktop. This coordination flow requires new server-side RPCs (scan request/response protocol) — the current API does not support it.

**Communication model:** The mobile app connects to the WineTap gRPC server on the local home network. Service discovery via mDNS with automatic fallback to a manually configured IP address (mDNS can be unreliable on some consumer routers and after phone sleep/wake cycles). Real-time coordination for the intake flow uses new dedicated streaming RPCs.

**NFC tag migration:** Replace existing UHF-only tags with NFC tags (NTAG213/215/216, flexible adhesive labels stuck on the side of the bottle). The tag UID replaces the UHF EPC as the bottle identifier — the proto field is renamed from `rfid_epc` to `tag_id` to reflect this generalization. The UHF hardware (Chafon reader) and cellar binary are retired. Migration is a one-time re-tagging effort across the existing cellar stock.

## What Makes This Different

- **No proprietary hardware, no subscription.** The reader is the phone you already own. No special equipment, no cloud accounts, no recurring fees. Competitors like InVintory require cloud subscriptions and sell proprietary NFC stickers. WineTap uses commodity NFC tags (pennies each) and keeps everything local.
- **Open tags, open data.** NFC tags are a universal standard — any phone can read them, any NTAG will work. The user is never locked in to a tag vendor, an app, or a platform.
- **Phone as wireless desktop scanner.** The coordinated intake flow — phone scans the tag, desktop form completes itself in real-time — is a novel interaction pattern that no wine management app offers. It combines the editorial power of a desktop form with the physical convenience of a phone.
- **Deliberate simplification.** We built the complex version first (UHF reader, RPi, 24/7 cellar scanner), learned what mattered, and stripped it back to just a phone. That journey — sophisticated system deliberately simplified — is the product thesis.

## Who This Serves

**Primary user — the hobbyist wine collector.** Maintains a personal cellar of 100-500 bottles. Buys wine online — sitting at the desktop, browsing reseller websites for good opportunities — then enters everything through the manager when the delivery arrives. Pulls bottles over weeks or months. Wants the tracking to be effortless — not a chore that interrupts the pleasure of opening a bottle. Tech-comfortable but not a developer; expects things to just work on the home network.

## Success Criteria

- Consume flow completes in under 3 seconds from scan initiation to confirmation (excluding app launch; measured on iPhone XS+ and Android 10+ devices)
- Intake coordination completes in under 5 seconds from the user tapping "Ready to Scan" on the phone to the UID appearing in the manager form
- mDNS server discovery succeeds on first attempt in the common case; manual IP fallback available in settings
- App runs on iPhone 7+ (iOS 14+) and Android 9+ with NFC hardware
- The UHF RFID hardware and cellar binary can be fully decommissioned after NFC tag migration

## Scope

**MVP (in scope):**
- Cross-platform app (iOS + Android) built with Flutter
- NFC tag reading (NTAG UID extraction, canonical hex format)
- Consume flow: scan → server call → confirmation screen
- Intake flow: new scan coordination protocol (server RPCs), "Ready to Scan" UX, UID relay to manager
- mDNS server discovery with manual IP fallback
- gRPC client for the WineTap API (existing + new coordination RPCs)
- French-only UI (consistent with the desktop manager; i18n deferred)
- Error handling: unknown tag, server unreachable, intake timeout, scan cancellation

**Explicitly out of MVP:**
- Inventory browsing on mobile
- Offline mode / scan queueing
- Push notifications (drink-before alerts)
- Catalogue management (CRUD for designations, domains, cuvées)
- Authentication (WiFi-only trust model, same as current system — conscious trade-off)
- Cloud sync or remote access
- App Store / Play Store distribution (TestFlight + sideloaded APK for initial users)

## Technical Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| iOS NFC requires foreground session with system sheet (~1s overhead) | Medium | Design UX around explicit "Ready to Scan" action; adjust timing targets to exclude system UI |
| mDNS unreliable on some routers / after phone sleep | Medium | Implement manual IP fallback; cache last-known server address |
| Intake coordination needs new RPCs not in current proto | High | Design scan request/response protocol as a server-side prerequisite before mobile development |
| Flutter NFC plugin (`nfc_manager`) is community-maintained | Medium | Validate NFC UID extraction on target devices early; have `flutter_nfc_kit` as backup |
| gRPC on mobile: connection lifecycle, reconnection after sleep | Medium | Implement connection manager with keepalive and exponential backoff reconnection |
| NFC tag adhesion on curved bottle surface | Low | Use flexible adhesive NFC labels designed for curved surfaces; tags are placed on the bottle side, away from the metal foil capsule — no interference observed in testing |

## Architecture Decision: Server Topology

With the cellar binary retired, the 24/7 RPi server is no longer strictly necessary. Two options remain open for the PRD phase:

**Option A: Keep standalone server on RPi.** Mobile and manager are both clients. Server is always available for consume scans even when the desktop is off. Proven architecture — just add a new client.

**Option B: Embed server into the manager.** No separate process. Manager is the server; mobile connects to it. Simpler deployment, fewer moving parts. But consume-only scans require the desktop to be running.

This decision should be made during architecture design, informed by how often bottles are consumed without the desktop being active.

## Vision

WineTap becomes a two-device system: a desktop for the heavy editorial work (cataloguing, bulk edits, analytics) and a phone for the physical interactions (scan in, scan out). The phone naturally extends to browsing inventory on the go ("what do I have that pairs with lamb?"), drink-before notifications, and sharing a cellar view with dinner guests. The self-hosted, NFC-based, no-cloud, no-subscription model is the identity — technology that respects your wine and your data.
