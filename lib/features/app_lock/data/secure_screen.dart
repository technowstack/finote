import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Toggles Android `FLAG_SECURE`, which blanks the Recent Apps preview and
/// blocks screenshots/screen recording of Finote.
class SecureScreen {
  const SecureScreen([
    this._channel = const MethodChannel('finote/secure_screen'),
  ]);

  final MethodChannel _channel;

  Future<void> setEnabled(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', enabled);
    } on MissingPluginException {
      // No native handler (tests, other embedders): App Lock still gates UI.
    } on PlatformException catch (error) {
      debugPrint('SecureScreen: setSecure failed (${error.code})');
    }
  }
}

final secureScreenProvider = Provider<SecureScreen>(
  (ref) => const SecureScreen(),
);
