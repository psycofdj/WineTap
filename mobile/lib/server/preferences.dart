/// Key-value storage for v3 state kept outside the database file (C-01):
/// authorized browser sessions and shared settings.
abstract class KeyValueStore {
  String? get(String key);
  Future<void> set(String key, String value);
}

/// In-memory store, for tests.
class MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? get(String key) => values[key];

  @override
  Future<void> set(String key, String value) async => values[key] = value;
}

/// Settings shared by every browser (D-09).
class Settings {
  Settings(this._store);

  final KeyValueStore _store;
  static const _assistantKey = 'v3.assistant';

  /// 'claude' or 'chatgpt'.
  String get assistant =>
      _store.get(_assistantKey) == 'chatgpt' ? 'chatgpt' : 'claude';

  Future<void> setAssistant(String value) =>
      _store.set(_assistantKey, value == 'chatgpt' ? 'chatgpt' : 'claude');
}
