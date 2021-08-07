@TestOn('vm')

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';

// Tests for the following issue
// https://github.com/getsentry/sentry-dart/issues/508
// There are no asserts, test are succesfull if no exceptions are thrown.
void main() {
  tearDown(() async {
    await Sentry.close();
  });

  test('async re-initilization', () async {
    await SentryFlutter.init((options) {
      options.dsn = fakeDsn;
    });

    await Sentry.close();

    await SentryFlutter.init((options) {
      options.dsn = fakeDsn;
    });
  });

  // This is the failure from
  // https://github.com/getsentry/sentry-dart/issues/508
  test('re-initilization', () {
    SentryFlutter.init((options) {
      options.dsn = fakeDsn;
    });

    Sentry.close();

    SentryFlutter.init((options) {
      options.dsn = fakeDsn;
    });
  });
}
