import 'package:shared_preferences/shared_preferences.dart';

import '../server/preferences.dart';

/// [KeyValueStore] kept in the app's storage, outside the database (C-01).
class SharedPrefsStore implements KeyValueStore {
  SharedPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? get(String key) => _prefs.getString(key);

  @override
  Future<void> set(String key, String value) => _prefs.setString(key, value);
}
