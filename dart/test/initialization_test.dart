@TestOn('vm')
library dart_test;

import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';

// Tests for the following issue
// https://github.com/getsentry/sentry-dart/issues/508
// There are no asserts, test are succesfull if no exceptions are thrown.
void main() {
  tearDown(() async {
    await Sentry.close();
  });

  test('async re-initilization', () async {
    final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
    await Sentry.init(
      (options) {
        options.dsn = fakeDsn;
      },
      options: options,
    );

    await Sentry.close();

    await Sentry.init(
      (options) {
        options.dsn = fakeDsn;
      },
      options: options,
    );
  });

  // This is the failure from
  // https://github.com/getsentry/sentry-dart/issues/508
  test('re-initilization', () async {
    final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
    await Sentry.init(
      (options) {
        options.dsn = fakeDsn;
      },
      options: options,
    );

    await Sentry.close();

    await Sentry.init(
      (options) {
        options.dsn = fakeDsn;
      },
      options: options,
    );
  });
}
