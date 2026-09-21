import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/src/native/sentry_native_channel.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$LoadReleaseIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('uses native package info before the platform channel', () async {
      final native = FakeNative(fixture.options);
      await fixture
          .getIntegration(native: native)
          .call(MockHub(), fixture.options);
      expect(fixture.options.release, 'native.app@2.3.4+987');
      expect(fixture.options.dist, '987');
      expect(native.loadCalls, 1);
    });

    test('falls back when native package info is unavailable', () async {
      final native = FakeNative(fixture.options)..packageInfo = null;
      await fixture
          .getIntegration(native: native)
          .call(MockHub(), fixture.options);
      expect(fixture.options.release, 'foo.bar@1.2.3+789');
      expect(fixture.options.dist, '789');
    });

    test('skips native lookup when release and dist are provided', () async {
      final native = FakeNative(fixture.options);
      fixture.options.release = 'custom';
      fixture.options.dist = '42';
      await fixture
          .getIntegration(native: native)
          .call(MockHub(), fixture.options);
      expect(native.loadCalls, 0);
      expect(fixture.options.release, 'custom');
      expect(fixture.options.dist, '42');
    });

    test('preserves custom release while loading native dist', () async {
      fixture.options.release = 'custom';
      await fixture
          .getIntegration(native: FakeNative(fixture.options))
          .call(MockHub(), fixture.options);
      expect(fixture.options.release, 'custom');
      expect(fixture.options.dist, '987');
    });

    test('preserves custom dist while loading native release', () async {
      fixture.options.dist = '42';
      await fixture
          .getIntegration(native: FakeNative(fixture.options))
          .call(MockHub(), fixture.options);
      expect(fixture.options.release, 'native.app@2.3.4+987');
      expect(fixture.options.dist, '42');
    });

    test('does not overwrite options', () async {
      fixture.options.release = '1.0.0';
      fixture.options.dist = 'dist';

      await fixture.getIntegration().call(MockHub(), fixture.options);

      expect(fixture.options.release, '1.0.0');
      expect(fixture.options.dist, 'dist');
    });

    test('sets release and dist if not set on options', () async {
      await fixture.getIntegration().call(MockHub(), fixture.options);

      expect(fixture.options.release, 'foo.bar@1.2.3+789');
      expect(fixture.options.dist, '789');
    });

    test('sets app name as in release if packagename is empty', () async {
      final loader = () {
        PackageInfo.setMockInitialValues(
          appName: 'sentry_flutter',
          packageName: '',
          version: '1.2.3',
          buildNumber: '789',
          buildSignature: '',
          installerStore: null,
        );
      };
      await fixture
          .getIntegration(loader: loader)
          .call(MockHub(), fixture.options);

      expect(fixture.options.release, 'sentry_flutter@1.2.3+789');
      expect(fixture.options.dist, '789');
    });

    test(
      'release name does not contain invalid chars defined by Sentry',
      () async {
        final loader = () {
          PackageInfo.setMockInitialValues(
            appName: '\\/sentry\tflutter \r\nfoo\nbar\r',
            packageName: '',
            version: '1.2.3',
            buildNumber: '789',
            buildSignature: '',
            installerStore: null,
          );
        };
        await fixture
            .getIntegration(loader: loader)
            .call(MockHub(), fixture.options);

        expect(fixture.options.release, '__sentry_flutter _foo_bar_@1.2.3+789');
        expect(fixture.options.dist, '789');
      },
    );

    /// See the following issues:
    /// - https://github.com/getsentry/sentry-dart/issues/410
    /// - https://github.com/fluttercommunity/plus_plugins/issues/182
    test(
      'does not send Unicode NULL \\u0000 character in app name or version',
      () async {
        final loader = () {
          PackageInfo.setMockInitialValues(
            // As per
            // https://api.dart.dev/stable/2.12.4/dart-core/String-class.html
            // this is how \u0000 is added to a string in dart
            appName: 'sentry_flutter_example\u{0000}',
            packageName: '',
            version: '1.0.0\u{0000}',
            buildNumber: '',
            buildSignature: '',
            installerStore: null,
          );
        };
        await fixture
            .getIntegration(loader: loader)
            .call(MockHub(), fixture.options);

        expect(fixture.options.release, 'sentry_flutter_example@1.0.0');
      },
    );

    /// See the following issues:
    /// - https://github.com/getsentry/sentry-dart/issues/410
    /// - https://github.com/fluttercommunity/plus_plugins/issues/182
    test(
      'does not send Unicode NULL \\u0000 character in package name or build number',
      () async {
        final loader = () {
          PackageInfo.setMockInitialValues(
            // As per
            // https://api.dart.dev/stable/2.12.4/dart-core/String-class.html
            // this is how \u0000 is added to a string in dart
            appName: '',
            packageName: 'sentry_flutter_example\u{0000}',
            version: '',
            buildNumber: '123\u{0000}',
            buildSignature: '',
            installerStore: null,
          );
        };
        await fixture
            .getIntegration(loader: loader)
            .call(MockHub(), fixture.options);

        expect(fixture.options.release, 'sentry_flutter_example+123');
      },
    );

    test('dist is null if build number is an empty string', () async {
      final loader = () {
        PackageInfo.setMockInitialValues(
          appName: 'sentry_flutter_example',
          packageName: 'a.b.c',
          version: '1.0.0',
          buildNumber: '',
          buildSignature: '',
          installerStore: null,
        );
      };
      await fixture
          .getIntegration(loader: loader)
          .call(MockHub(), fixture.options);

      expect(fixture.options.dist, isNull);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  LoadReleaseIntegration getIntegration({
    Function? loader,
    FakeNative? native,
  }) {
    if (loader != null) {
      loader();
    } else {
      loadRelease();
    }
    return LoadReleaseIntegration(native: native);
  }

  void loadRelease() {
    PackageInfo.setMockInitialValues(
      appName: 'sentry_flutter',
      packageName: 'foo.bar',
      version: '1.2.3',
      buildNumber: '789',
      buildSignature: '',
      installerStore: null,
    );
  }
}

class FakeNative extends SentryNativeChannel {
  FakeNative(super.options);
  int loadCalls = 0;
  PackageInfo? packageInfo = PackageInfo(
    appName: 'Native',
    packageName: 'native.app',
    version: '2.3.4',
    buildNumber: '987',
  );
  @override
  PackageInfo? loadPackageInfo() {
    loadCalls++;
    return packageInfo;
  }
}
