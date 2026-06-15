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
// ignore: implementation_imports
import 'package:jnigen/src/elements/j_elements.dart' as j_ast;

/// Java methods whose generated Dart setter conflicts with a nullable getter.
const _excludedMethods = <String, Set<String>>{
  'io.sentry.android.core.SentryAndroidOptions': {
    'setBeforeScreenshotCaptureCallback',
    'setBeforeViewHierarchyCaptureCallback',
  },
  'io.sentry.SentryOptions': {
    'setGestureTargetLocators',
  },
  'io.sentry.SentryEvent': {
    'setTimestamp',
  },
};

class _ExcludeMismatchedSetters extends j_ast.Visitor {
  String _currentClass = '';

  @override
  void visitClass(j_ast.ClassDecl c) {
    _currentClass = c.binaryName;
  }

  @override
  void visitMethod(j_ast.Method method) {
    if (_excludedMethods[_currentClass]?.contains(method.originalName) ??
        false) {
      method.isExcluded = true;
    }
  }
}

void main() {
  final packageRoot = Platform.script.resolve('../');
  generateJniBindings(
    Config(
      outputConfig: OutputConfig(
        dartConfig: DartCodeOutputConfig(
          path: packageRoot.resolve('lib/src/native/java/binding.dart'),
          structure: OutputStructure.singleFile,
        ),
      ),
      androidSdkConfig: AndroidSdkConfig(
        addGradleDeps: true,
        androidExample: packageRoot.resolve('example/').toFilePath(),
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
      visitors: [_ExcludeMismatchedSetters()],
    ),
  );
}
