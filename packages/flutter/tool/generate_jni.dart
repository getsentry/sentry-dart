// Generates JNI bindings using jnigen with a custom visitor that excludes
// methods causing getter/setter nullability mismatches (jnigen 0.16.0 bug).
//
// Usage: dart run tool/generate_jni.dart --config ffi-jni.yaml
import 'package:jnigen/jnigen.dart';
import 'package:jnigen/src/elements/j_elements.dart' as j;
import 'package:jnigen/src/logging/logging.dart';

/// Excludes specific Java getter methods whose generated Dart getter returns
/// a nullable type while the corresponding setter accepts non-nullable.
/// This mismatch is a compile error in Dart.
class _NullabilityFixVisitor extends j.Visitor {
  // Java getter method names to exclude, keyed by class binary name.
  static const _excludes = {
    'io.sentry.android.core.SentryAndroidOptions': {
      'getBeforeScreenshotCaptureCallback',
      'setBeforeScreenshotCaptureCallback',
      'getBeforeViewHierarchyCaptureCallback',
      'setBeforeViewHierarchyCaptureCallback',
    },
    'io.sentry.SentryOptions': {
      'getGestureTargetLocators',
      'setGestureTargetLocators',
    },
    'io.sentry.SentryEvent': {
      'getTimestamp',
      'setTimestamp',
    },
  };

  String? _currentClass;

  @override
  void visitClass(j.ClassDecl c) {
    _currentClass = c.binaryName;
  }

  @override
  void visitMethod(j.Method method) {
    final classExcludes = _excludes[_currentClass];
    if (classExcludes != null && classExcludes.contains(method.originalName)) {
      method.isExcluded = true;
    }
  }
}

void main(List<String> args) async {
  enableLoggingToFile();
  Config config;
  try {
    config = Config.parseArgs(args);
  } on ConfigException catch (e) {
    log.fatal(e);
  } on FormatException catch (e) {
    log.fatal(e);
  }

  config.visitors = [_NullabilityFixVisitor()];

  await generateJniBindings(config);
}
