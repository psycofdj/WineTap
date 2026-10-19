import 'dart:io';

/// Local IPv4 address of the phone: the Wi-Fi interface first (en* on iOS,
/// wlan* on Android), then any other non-loopback, non-cellular address.
/// Null without a local network.
Future<String?> localAddress() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    String? other;
    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      for (final a in iface.addresses) {
        if (a.isLoopback || a.isLinkLocal) continue;
        if (name.startsWith('en') ||
            name.startsWith('wlan') ||
            name.startsWith('ap')) {
          return a.address;
        }
        // pdp_ip (iOS) et rmnet (Android) : données mobiles, injoignables depuis le Wi-Fi.
        if (!name.startsWith('pdp_ip') && !name.startsWith('rmnet')) {
          other ??= a.address;
        }
      }
    }
    return other;
  } catch (_) {
    return null;
  }
}
