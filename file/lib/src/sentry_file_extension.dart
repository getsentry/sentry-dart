// ignore_for_file: invalid_use_of_internal_member

import 'dart:io' if (dart.library.html) 'dart:html';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import '../sentry_file.dart';

extension SentryFileExtension on File {
  /// The Sentry wrapper for the File IO implementation that creates a span
  /// out of the active transaction in the scope.
  /// The span is started before the operation is executed and finished after.
  /// The File tracing isn't available for Web.
  ///
  /// Example:
  ///
  /// ```dart
  /// import 'dart:io';
  ///
  /// final file = File('test.txt');
  /// final sentryFile = SentryFile(file);
  /// // span starts
  /// await sentryFile.writeAsString('Hello World');
  /// // span finishes
  /// ```
  ///
  /// All the copy, create, delete, open, rename, read, and write operations are
  /// supported.
  File sentryTrace({
    @internal Hub? hub,
  }) {
    final _hub = hub ?? HubAdapter();

    if (_hub.options.platformChecker.isWeb ||
        !_hub.options.isTracingEnabled()) {
      return this;
    }

    return SentryFile(this, hub: _hub);
  }
}
