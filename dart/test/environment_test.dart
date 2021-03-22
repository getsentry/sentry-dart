import 'package:sentry/sentry.dart';
import 'package:sentry/src/environment_variables.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_environment_variables.dart';

void main() {
  group('Environment Variables', () {
    // See https://docs.sentry.io/platforms/dart/configuration/options/
    // and https://github.com/getsentry/sentry-dart/issues/306
    test('SentryOptions are correctly overriden by environment', () {
      final options = SentryOptions(dsn: fakeDsn);
      options.release = 'release-1.2.3';
      options.dist = 'foo';
      options.environment = 'prod';

      setEnvironmentVariables(
        options,
        MockEnvironmentVariables(
          dsn: 'foo-bar',
          environment: 'staging',
          release: 'release-9.8.7',
          dist: 'bar',
        ),
      );

      expect(options.dsn, fakeDsn);
      expect(options.environment, 'staging');
      expect(options.release, 'release-9.8.7');
      expect(options.dist, 'bar');
    });

    test('No environment variables are set', () {
      final options = SentryOptions(dsn: fakeDsn);
      options.environment = 'prod';
      options.release = 'release-1.2.3';
      options.dist = 'foo';

      setEnvironmentVariables(
        options,
        MockEnvironmentVariables(),
      );

      expect(options.dsn, fakeDsn);
      expect(options.environment, 'prod');
      expect(options.release, 'release-1.2.3');
      expect(options.dist, 'foo');
    });
  });
}
