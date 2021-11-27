@TestOn('vm')

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
    await Sentry.init((options) {
      options.dsn = fakeDsn;
    });

    await Sentry.close();

    await Sentry.init((options) {
      options.dsn = fakeDsn;
    });
  });

  // This is the failure from
  // https://github.com/getsentry/sentry-dart/issues/508
  test('re-initilization', () async {
    await Sentry.init((options) {
      options.dsn = fakeDsn;
    });

    await Sentry.close();

    await Sentry.init((options) {
      options.dsn = fakeDsn;
    });
  });
}
