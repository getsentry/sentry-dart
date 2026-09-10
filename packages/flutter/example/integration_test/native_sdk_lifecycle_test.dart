// ignore_for_file: invalid_use_of_internal_member, depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jni/jni.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/java/binding.dart' as native;

import 'utils.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SentryFlutter native lifecycle', () {
    tearDown(Sentry.close);

    testWidgets('keeps native reporting enabled across detach and reattach',
        (tester) async {
      await restoreFlutterOnErrorAfter(() async {
        await SentryFlutter.init((options) {
          options.dsn = fakeDsn;
          options.debug = true;
        }, appRunner: () async {});
      });
      expect(native.Sentry.isEnabled(), isTrue);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(native.Sentry.isEnabled(), isTrue);
      final eventId = using((arena) {
        final message = 'Native capture after reattach'.toJString()
          ..releasedBy(arena);
        final id = native.Sentry.captureMessage(message)..releasedBy(arena);
        return id.toString$1().use((value) => value?.toDartString());
      });
      expect(eventId, isNotNull);
      expect(eventId, isNot(const SentryId.empty().toString()));
    }, skip: !Platform.isAndroid);
  });
}
