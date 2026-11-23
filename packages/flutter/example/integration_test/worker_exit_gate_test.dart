// ignore_for_file: depend_on_referenced_packages, invalid_use_of_internal_member
@TestOn('vm')
import 'dart:io';
import 'dart:ui';

import 'package:sentry_flutter/src/native/java/binding.dart' as native;
import 'package:test/test.dart';

void main() {
  // These tests prove that the two JNI bindings resolve and can be called. An
  // unarmed request is granted too, so they can't tell whether arming did
  // anything: the gate's behaviour is covered by WorkerExitGateTest.
  //
  // The plugin and the workers use the engine's id as their token. Engine ids
  // are positive, so negative tokens never collide with a real engine.
  group('worker exit gate over JNI', () {
    test('has an engine id to use as its token', () {
      // Without one, a worker closed before the engine detaches is not held
      // back.
      expect(PlatformDispatcher.instance.engineId, isNotNull);
    });

    test('grants an exit request for a token that was never armed', () {
      expect(native.SentryFlutterPlugin.requestWorkerExit(-1), isTrue);
    });

    test('grants an armed worker that asks before any engine detaches', () {
      native.SentryFlutterPlugin.armWorkerExit(-2);

      expect(native.SentryFlutterPlugin.requestWorkerExit(-2), isTrue);
    });
  }, skip: !Platform.isAndroid);
}
