// Programmatic JNIgen runner for the Android bindings.
//
// We use a Dart entry point instead of a plain `ffi-jni.yaml` so we can attach
// a custom visitor that drops a handful of generated setters. JNIgen faithfully
// mirrors the Java API where a `@Nullable` getter is paired with a non-null
// setter, which Dart rejects with `getter_not_subtype_setter_types`. None of
// these setters are used by the SDK, so excluding them keeps the (nullable)
// getter and removes the invalid getter/setter pair.
//
// Run via `scripts/generate-jni-bindings.sh` (or `dart run tool/jnigen.dart`).
import 'dart:io';

import 'package:jnigen/jnigen.dart';

/// Java methods whose generated Dart setter conflicts with a nullable getter.
const _excludedMethods = <String, Set<String>>{
  'io.sentry.android.core.SentryAndroidOptions': {
    'setBeforeScreenshotCaptureCallback',
    'setBeforeViewHierarchyCaptureCallback',
  },
  'io.sentry.SentryOptions': {'setGestureTargetLocators'},
  'io.sentry.SentryEvent': {'setTimestamp'},
};

final class _ExcludeMismatchedSetters extends Visitor {
  _ExcludeMismatchedSetters() : super.base();

  String _currentClass = '';

  @override
  void visitClass(ClassDecl c) {
    _currentClass = c.binaryName;
  }

  @override
  void visitMethod(Method method) {
    if (_excludedMethods[_currentClass]?.contains(method.originalName) ??
        false) {
      method.isIncluded = false;
    }
  }
}

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');
  await JniGenerator(
    input: Input(
      androidSdk: AndroidSdk(
        addGradleDeps: true,
        androidExample: packageRoot.resolve('example/'),
      ),
      classes: const [
        'io.sentry.android.core.SentryAndroid',
        'io.sentry.android.core.SentryAndroidOptions',
        'io.sentry.android.core.InternalSentrySdk',
        'io.sentry.android.core.BuildConfig',
        'io.sentry.android.replay.ReplayIntegration',
        'io.sentry.android.replay.ScreenshotRecorderConfig',
        'io.sentry.flutter.SentryFlutterPlugin',
        'io.sentry.flutter.ReplayRecorderCallbacks',
        'io.sentry.flutter.ReplayFlushListener',
        'io.sentry.Sentry',
        'io.sentry.SentryOptions',
        'io.sentry.SentryReplayOptions',
        'io.sentry.SentryReplayEvent',
        'io.sentry.SentryEvent',
        'io.sentry.SentryBaseEvent',
        'io.sentry.SentryLevel',
        'io.sentry.Hint',
        'io.sentry.ReplayRecording',
        'io.sentry.Breadcrumb',
        'io.sentry.ScopesAdapter',
        'io.sentry.Scope',
        'io.sentry.ScopeCallback',
        'io.sentry.protocol.User',
        'io.sentry.protocol.SentryId',
        'io.sentry.protocol.SdkVersion',
        'io.sentry.protocol.SentryPackage',
        'io.sentry.rrweb.RRWebOptionsEvent',
        'io.sentry.rrweb.RRWebEvent',
        'io.sentry.SentryTraceHeader',
        'java.net.Proxy',
        'android.graphics.Bitmap',
        'android.content.Context',
      ],
    ),
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/src/native/java/binding.dart'),
        structure: OutputStructure.singleFile,
      ),
    ),
    visitors: [_ExcludeMismatchedSetters()],
  ).generate();
}
