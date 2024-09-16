@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';

// Tests for the following issue
// https://github.com/getsentry/sentry-dart/issues/508
// There are no asserts, test are succesfull if no exceptions are thrown.
void main() {
  final native = NativeChannelFixture();

  void optionsInitializer(SentryFlutterOptions options) {
    // LoadReleaseIntegration throws because package_info channel is not available
    options.removeIntegration(
        options.integrations.firstWhere((i) => i is LoadReleaseIntegration));
  }

  test('async re-initilization', () async {
    await SentryFlutter.init(optionsInitializer,
        options: defaultTestOptions()..methodChannel = native.channel);

    await Sentry.close();

    await SentryFlutter.init(optionsInitializer,
        options: defaultTestOptions()..methodChannel = native.channel);

    await Sentry.close();
  });
}
