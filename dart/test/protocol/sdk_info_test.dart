import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith keeps unchanged', () {
    final data = _generate();

    final copy = data.copyWith();

    expect(
      MapEquality().equals(data.toJson(), copy.toJson()),
      true,
    );
  });

  test('copyWith takes new values', () {
    final data = _generate();

    final copy = data.copyWith(
      sdkName: 'sdkName1',
      versionMajor: 11,
      versionMinor: 22,
      versionPatchlevel: 33,
    );

    expect('sdkName1', copy.sdkName);
    expect(11, copy.versionMajor);
    expect(22, copy.versionMinor);
    expect(33, copy.versionPatchlevel);
  });
}

SdkInfo _generate() => SdkInfo(
      sdkName: 'sdkName',
      versionMajor: 1,
      versionMinor: 2,
      versionPatchlevel: 3,
    );
