import 'package:web/web.dart' as web;

import 'platform.dart';

/// [Platform] implementation that delegates to `dart:web`.
class PlatformBase {
  const PlatformBase();

  bool get isWeb => true;

  OperatingSystem get operatingSystem {
    final navigatorPlatform = web.window.navigator.platform.toLowerCase();
    if (navigatorPlatform.startsWith('mac')) {
      return OperatingSystem.macos;
    }
    if (navigatorPlatform.startsWith('win')) {
      return OperatingSystem.windows;
    }
    if (navigatorPlatform.contains('iphone') ||
        navigatorPlatform.contains('ipad') ||
        navigatorPlatform.contains('ipod')) {
      return OperatingSystem.ios;
    }
    if (navigatorPlatform.contains('android')) {
      return OperatingSystem.android;
    }
    if (navigatorPlatform.contains('fuchsia')) {
      return OperatingSystem.fuchsia;
    }

    // Since some phones can report a window.navigator.platform as Linux, fall
    // back to use CSS to disambiguate Android vs Linux desktop. If the CSS
    // indicates that a device has a "fine pointer" (mouse) as the primary
    // pointing device, then we'll assume desktop linux, and otherwise we'll
    // assume Android.
    if (web.window.matchMedia('only screen and (pointer: fine)').matches) {
      return OperatingSystem.linux;
    }
    return OperatingSystem.android;
  }

  String? get operatingSystemVersion => null;

  String get localHostname => web.window.location.hostname;
}
