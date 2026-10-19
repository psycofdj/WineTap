import '../database.dart';
import '../db_holder.dart';
import '../events.dart';
import '../preferences.dart';
import '../remote_scan.dart';
import '../sessions.dart';

/// What the phone says about itself in `GET /api/session`.
class PhoneInfo {
  const PhoneInfo({required this.name, required this.localAddress});

  /// « iPhone », « Android »
  final String name;

  /// Local IPv4 address, or null without a local network.
  final Future<String?> Function() localAddress;
}

/// Everything the API handlers need.
class ApiContext {
  ApiContext({
    required this.dbs,
    required this.sessions,
    required this.events,
    required this.scan,
    required this.settings,
    required this.phone,
    this.port = 8080,
    int Function()? currentYear,
  }) : currentYear = currentYear ?? (() => DateTime.now().year);

  final DbHolder dbs;
  final SessionStore sessions;
  final EventHub events;
  final RemoteScan scan;
  final Settings settings;
  final PhoneInfo phone;
  final int port;
  final int Function() currentYear;

  /// Tags freed by a consumption since the server started → bottle id, to
  /// recognize « déjà consommée » (the tag is cleared in the database, C-01).
  /// Forgotten as soon as the tag is associated again.
  final Map<String, int> freedTags = {};

  AppDatabase get db => dbs.db;
}
