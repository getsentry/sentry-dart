import 'dart:io';

import '../sentry_file.dart';

extension SentryFileExtension on File {
  /// The Sentry wrapper for the File implementation that starts a span
  /// out of the active transaction in the scope.
  /// The span is started before the operation is executed and finished after.
  /// Example:
  ///
  /// ```dart
  /// final file = File('test.txt');
  /// final sentryFile = file.sentryTrace();
  /// // span starts
  /// await sentryFile.writeAsString('Hello World');
  /// // span finishes
  /// ```
  ///
  /// All the copy, create, delete, open, rename, read, and write operations are
  /// supported.
  SentryFile sentryTrace() {
    return SentryFile(this);
  }
}
