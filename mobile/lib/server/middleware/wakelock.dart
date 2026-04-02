import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Shelf middleware that keeps the screen awake while the manager is active.
///
/// Each HTTP request resets a 5-minute idle timer. While the timer is running,
/// the phone stays awake. When the timer expires, wakelock is released.
Middleware wakelockMiddleware() {
  Timer? idleTimer;

  void resetTimer() {
    idleTimer?.cancel();
    // Ignore errors — wakelock may be unsupported on some platforms/configs.
    WakelockPlus.enable().catchError((_) {});
    idleTimer = Timer(const Duration(minutes: 5), () {
      WakelockPlus.disable().catchError((_) {});
    });
  }

  return (Handler innerHandler) {
    return (Request request) async {
      resetTimer();
      return innerHandler(request);
    };
  };
}
