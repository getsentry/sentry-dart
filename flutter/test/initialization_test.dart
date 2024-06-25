@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';

// Tests for the following issue
// https://github.com/getsentry/sentry-dart/issues/508
// There are no asserts, test are succesfull if no exceptions are thrown.
void main() {
  setUp(() async {
    await Sentry.close();
  });

  test('async re-initilization', () async {
    await SentryFlutter.init(
      (options) {
        options.dsn = fakeDsn;
        // ignore: invalid_use_of_internal_member
        options.automatedTestMode = true;
      },
    );

    await Sentry.close();

    await SentryFlutter.init(
      (options) {
        options.dsn = fakeDsn;
        // ignore: invalid_use_of_internal_member
        options.automatedTestMode = true;
      },
    );

    await Sentry.close();
  });

  // This is the failure from
  // https://github.com/getsentry/sentry-dart/issues/508
  test('re-initilization', () async {
    await SentryFlutter.init(
      (options) {
        options.dsn = fakeDsn;
        // ignore: invalid_use_of_internal_member
        options.automatedTestMode = true;
      },
    );

    await Sentry.close();

    await SentryFlutter.init(
      (options) {
        options.dsn = fakeDsn;
        // ignore: invalid_use_of_internal_member
        options.automatedTestMode = true;
      },
    );

    await Sentry.close();
  });
}
