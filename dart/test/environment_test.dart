import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_environment_variables.dart';

void main() {
  // See https://docs.sentry.io/platforms/dart/configuration/options/
  // and https://github.com/getsentry/sentry-dart/issues/306
  group('Environment Variables', () {
    tearDown(() async {
      await Sentry.close();
    });

    test('SentryOptions are not overriden by environment', () async {
      final options = SentryOptions(dsn: fakeDsn);
      options.release = 'release-1.2.3';
      options.dist = 'foo';
      options.environment = 'prod';
      options.environmentVariables = MockEnvironmentVariables(
        dsn: 'foo-bar',
        environment: 'staging',
        release: 'release-9.8.7',
        dist: 'bar',
      );
      options.automatedTestMode = true;

      await Sentry.init(
        (options) => options,
        options: options,
      );

      expect(options.dsn, fakeDsn);
      expect(options.environment, 'prod');
      expect(options.release, 'release-1.2.3');
      expect(options.dist, 'foo');
    });

    test('SentryOptions are overriden by environment', () async {
      final options = SentryOptions();
      options.environmentVariables = MockEnvironmentVariables(
        dsn: fakeDsn,
        environment: 'staging',
        release: 'release-9.8.7',
        dist: 'bar',
      );
      options.automatedTestMode = true;

      await Sentry.init(
        (options) => options,
        options: options,
      );

      expect(options.dsn, fakeDsn);
      expect(options.environment, 'staging');
      expect(options.release, 'release-9.8.7');
      expect(options.dist, 'bar');
    });
  });
}
