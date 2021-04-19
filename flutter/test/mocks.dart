import 'package:mockito/annotations.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/platform/platform.dart';

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

@GenerateMocks([Hub, Transport])
void main() {}

class MockPlatform implements Platform {
  MockPlatform({
    String? os,
    String? osVersion,
    String? hostname,
  })  : operatingSystem = os ?? '',
        operatingSystemVersion = osVersion ?? '',
        localHostname = hostname ?? '';

  factory MockPlatform.android() {
    return MockPlatform(os: 'android');
  }

  factory MockPlatform.iOs() {
    return MockPlatform(os: 'ios');
  }

  factory MockPlatform.macOs() {
    return MockPlatform(os: 'macos');
  }

  factory MockPlatform.windows() {
    return MockPlatform(os: 'windows');
  }

  factory MockPlatform.linux() {
    return MockPlatform(os: 'linux');
  }

  @override
  String operatingSystem;

  @override
  String operatingSystemVersion;

  @override
  String localHostname;

  @override
  bool get isLinux => (operatingSystem == 'linux');

  @override
  bool get isMacOS => (operatingSystem == 'macos');

  @override
  bool get isWindows => (operatingSystem == 'windows');

  @override
  bool get isAndroid => (operatingSystem == 'android');

  @override
  bool get isIOS => (operatingSystem == 'ios');

  @override
  bool get isFuchsia => (operatingSystem == 'fuchsia');
}
