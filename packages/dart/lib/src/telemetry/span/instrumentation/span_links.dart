import 'package:meta/meta.dart';

import '../../../../sentry.dart';

/// Links each throwable to the streamed span it aborted.
///
/// Integrations that mark their span and rethrow are not the capture site; the
/// error surfaces later in application code or a global handler, after the
/// span has ended, and the throwable is the only handle that travels that far.
/// The hub looks the throwable up here when it captures it.
@internal
final throwableSpanLinks = SpanLinks();

/// Links an object to the streamed span it belongs to, so an error captured
/// somewhere else can be attributed to that span.
///
/// Throwables are linked in [throwableSpanLinks]. An integration whose span is
/// created in one layer and whose failures are captured in another links its
/// own key, such as the request, in its own [SpanLinks]: integrations can wrap
/// each other and see the same request, and each must find its own span.
///
/// Keys are held weakly. Unsupported [Expando] keys are ignored so error
/// capture can fall back to the active span.
@internal
class SpanLinks {
  final _spans = Expando<RecordingSentrySpanV2>('sentry.span_links');

  /// Links [key] to [span], replacing any span it is linked to unless that
  /// span is nested in [span].
  ///
  /// Keeping a nested span makes the innermost span win as a throwable unwinds
  /// through enclosing spans. Any other span replaces the link, since a key
  /// can be reused by an unrelated operation, such as a cached exception
  /// thrown again or a request that is retried.
  void link(Object? key, SentrySpanV2 span) {
    final weakKey = _weakKeyOf(key);
    if (weakKey == null || span is! RecordingSentrySpanV2) {
      return;
    }
    try {
      final linked = _spans[weakKey];
      if (linked == null || !_isNestedIn(linked, span)) {
        _spans[weakKey] = span;
      }
    } on ArgumentError {
      // The VM also rejects FFI pointers, structs, and unions.
    }
  }

  /// Returns the span linked to [key], or `null` if there is none.
  RecordingSentrySpanV2? spanFor(Object? key) {
    final weakKey = _weakKeyOf(key);
    if (weakKey == null) {
      return null;
    }
    try {
      return _spans[weakKey];
    } on ArgumentError {
      return null;
    }
  }

  static bool _isNestedIn(
    RecordingSentrySpanV2 span,
    RecordingSentrySpanV2 ancestor,
  ) {
    for (
      var parent = span.parentSpan;
      parent != null;
      parent = parent.parentSpan
    ) {
      if (identical(parent, ancestor)) {
        return true;
      }
    }
    return false;
  }

  /// A mechanism wraps the throwable after the span linked it, so it is
  /// unwrapped to find the original key.
  static Object? _weakKeyOf(Object? key) {
    if (key is ThrowableMechanism) {
      key = key.throwable;
    }
    return switch (key) {
      null || String() || num() || bool() || Record() => null,
      _ => key,
    };
  }
}
