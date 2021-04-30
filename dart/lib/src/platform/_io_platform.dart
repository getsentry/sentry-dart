import 'dart:io' as io show Platform;

import 'platform.dart';

const Platform instance = IOPlatform();

/// [Platform] implementation that delegates directly to `dart:io`.
class IOPlatform extends Platform {
  /// Creates a new [IOPlatform].
  const IOPlatform();

  @override
  String get operatingSystem => io.Platform.operatingSystem;

  @override
  String get operatingSystemVersion => io.Platform.operatingSystemVersion;

  @override
  String get localHostname => io.Platform.localHostname;
}
