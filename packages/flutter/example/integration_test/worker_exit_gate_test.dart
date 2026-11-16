// ignore_for_file: depend_on_referenced_packages, invalid_use_of_internal_member
@TestOn('vm')
import 'dart:io';

import 'package:sentry_flutter/src/native/java/binding.dart' as native;
import 'package:test/test.dart';

void main() {
  // These tests prove that the two JNI bindings resolve and can be called. An
  // unarmed request is granted too, so they can't tell whether arming did
  // anything: the gate's behaviour is covered by WorkerExitGateTest.
  //
  // Tokens issued by the plugin are positive, so negative ones never collide
  // with a real engine detach.
  group('worker exit gate over JNI', () {
    test('grants an exit request for a token that was never armed', () {
      expect(native.SentryFlutterPlugin.requestWorkerExit(-1), isTrue);
    });

    test('grants an armed worker that asks before any engine detaches', () {
      native.SentryFlutterPlugin.armWorkerExit(-2);

      expect(native.SentryFlutterPlugin.requestWorkerExit(-2), isTrue);
    });
  }, skip: !Platform.isAndroid);
}
