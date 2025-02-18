import 'package:platform/platform.dart';
import 'package:web/web.dart' as web;

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

  @override
  // TODO: implement environment
  Map<String, String> get environment => throw UnimplementedError();

  @override
  // TODO: implement executable
  String get executable => throw UnimplementedError();

  @override
  // TODO: implement executableArguments
  List<String> get executableArguments => throw UnimplementedError();

  @override
  // TODO: implement localeName
  String get localeName => throw UnimplementedError();

  @override
  // TODO: implement numberOfProcessors
  int get numberOfProcessors => throw UnimplementedError();

  @override
  // TODO: implement packageConfig
  String? get packageConfig => throw UnimplementedError();

  @override
  // TODO: implement pathSeparator
  String get pathSeparator => throw UnimplementedError();

  @override
  // TODO: implement resolvedExecutable
  String get resolvedExecutable => throw UnimplementedError();

  @override
  // TODO: implement script
  Uri get script => throw UnimplementedError();

  @override
  // TODO: implement stdinSupportsAnsi
  bool get stdinSupportsAnsi => throw UnimplementedError();

  @override
  // TODO: implement stdoutSupportsAnsi
  bool get stdoutSupportsAnsi => throw UnimplementedError();

  @override
  // TODO: implement version
  String get version => throw UnimplementedError();
}
