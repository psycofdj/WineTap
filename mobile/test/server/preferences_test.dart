import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/native/app_shell.dart' show themeModeOf;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:wine_tap_mobile/server/preferences.dart';

void main() {
  test('theme of the app: system by default, kept once chosen', () async {
    final store = MemoryStore();
    final settings = Settings(store);
    expect(settings.theme, 'systeme');
    await settings.setTheme('sombre');
    expect(Settings(store).theme, 'sombre', reason: 'kept across restarts');
    await settings.setTheme('n’importe quoi');
    expect(settings.theme, 'systeme');
  });

  test('theme mode of a theme chosen in the site', () {
    expect(themeModeOf('clair'), ThemeMode.light);
    expect(themeModeOf('sombre'), ThemeMode.dark);
    expect(themeModeOf('systeme'), ThemeMode.system);
  });
}
