// ignore_for_file: invalid_use_of_internal_member

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/cocoa/cocoa_ffi.dart';
import 'package:sentry_flutter/src/native/sentry_safe_method_channel.dart';

import 'utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final isCocoa = Platform.isIOS || Platform.isMacOS;

  group('$CocoaFfi', () {
    late SentryFlutterOptions options;

    setUp(() async {
      await restoreFlutterOnErrorAfter(() async {
        await SentryFlutter.init((o) {
          options = o
            ..dsn = fakeDsn
            ..automatedTestMode = true;
        }, appRunner: () async {});
      });
    });

    tearDown(() async {
      await Sentry.close();
    });

    test('loads native entry points', () async {
      final ffi = await CocoaFfi.load(SentrySafeMethodChannel(options));

      expect(ffi, isNotNull);
    }, skip: !isCocoa);

    test('syncs breadcrumb to native scope', () async {
      await Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'ffi-breadcrumb',
          category: 'ffi-category',
          data: {
            'customObject': CustomObject(),
            'nullEntry': null,
            'sparseList': ['a', null, 'c'],
            'nested': {'value': 1.5, 'enabled': true},
          },
        ),
      );

      final nativeContexts = await SentryFlutter.native?.loadContexts();
      final breadcrumbs = (nativeContexts?['breadcrumbs'] as List?)
          ?.cast<Map<dynamic, dynamic>>();
      final nativeBreadcrumb = breadcrumbs?.firstWhere(
        (breadcrumb) => breadcrumb['message'] == 'ffi-breadcrumb',
      );

      expect(nativeBreadcrumb?['category'], 'ffi-category');
      // sentry-cocoa stringifies NSNull to '<null>'; the method-channel path
      // behaves the same, so this pins parity rather than a regression.
      expect(nativeBreadcrumb?['data'], {
        'customObject': "Instance of 'CustomObject'",
        'nullEntry': '<null>',
        'sparseList': ['a', '<null>', 'c'],
        'nested': {'value': 1.5, 'enabled': true},
      });
    }, skip: !isCocoa);
  });
}
