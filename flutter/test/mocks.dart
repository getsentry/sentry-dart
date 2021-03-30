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
  }) : operatingSystem = os ?? '', operatingSystemVersion = osVersion ?? '', localHostname = hostname ?? '';

  String operatingSystem;
  String operatingSystemVersion;
  String localHostname;
  bool get isLinux => (operatingSystem == 'linux');
  bool get isMacOS => (operatingSystem == 'macos');
  bool get isWindows => (operatingSystem == 'windows');
  bool get isAndroid => (operatingSystem == 'android');
  bool get isIOS => (operatingSystem == 'ios');
  bool get isFuchsia => (operatingSystem == 'fuchsia');
}