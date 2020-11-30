import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('SdkInfo is built from SdkVersion without prereleases', () {
    final version = SdkVersion(
      name: 'abc',
      version: '1.0.2',
    );

    final info = SdkInfo.fromSdkVersion(version);

    expect('abc', info.sdkName);
    expect(1, info.versionMajor);
    expect(0, info.versionMinor);
    expect(2, info.versionPatchlevel);
  });

  test('SdkInfo is built from SdkVersion with prereleases', () {
    final version = SdkVersion(
      name: 'abc',
      version: '1.0.2-alpha02',
    );

    final info = SdkInfo.fromSdkVersion(version);

    expect('abc', info.sdkName);
    expect(1, info.versionMajor);
    expect(0, info.versionMinor);
    expect(2, info.versionPatchlevel);
  });

  test('SdkInfo is built from SdkVersion nas invalid patch version', () {
    final version = SdkVersion(
      name: 'abc',
      version: '1.0.2alpha02',
    );

    final info = SdkInfo.fromSdkVersion(version);

    expect('abc', info.sdkName);
    expect(1, info.versionMajor);
    expect(0, info.versionMinor);
    expect(info.versionPatchlevel, isNull);
  });
}
