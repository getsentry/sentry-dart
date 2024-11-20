// We would lose compatibility with old dart versions by adding web to pubspec.
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

import 'platform.dart';

const Platform instance = WebPlatform();

/// [Platform] implementation that delegates to `dart:web`.
class WebPlatform extends Platform {
  /// Creates a new [Platform].
  const WebPlatform();

  @override
  String get operatingSystem => _browserPlatform();

  @override
  String get operatingSystemVersion => 'unknown';

  @override
  String get localHostname => web.window.location.hostname;

  String _browserPlatform() {
    final navigatorPlatform = web.window.navigator.platform.toLowerCase();
    if (navigatorPlatform.startsWith('mac')) {
      return 'macos';
    }
    if (navigatorPlatform.startsWith('win')) {
      return 'windows';
    }
    if (navigatorPlatform.contains('iphone') ||
        navigatorPlatform.contains('ipad') ||
        navigatorPlatform.contains('ipod')) {
      return 'ios';
    }
    if (navigatorPlatform.contains('android')) {
      return 'android';
    }
    if (navigatorPlatform.contains('fuchsia')) {
      return 'fuchsia';
    }

    // Since some phones can report a window.navigator.platform as Linux, fall
    // back to use CSS to disambiguate Android vs Linux desktop. If the CSS
    // indicates that a device has a "fine pointer" (mouse) as the primary
    // pointing device, then we'll assume desktop linux, and otherwise we'll
    // assume Android.
    if (web.window.matchMedia('only screen and (pointer: fine)').matches) {
      return 'linux';
    }
    return 'android';
  }
}
