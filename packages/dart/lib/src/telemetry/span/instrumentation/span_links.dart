import 'package:meta/meta.dart';

import '../../../../sentry.dart';

/// The process-wide [SpanLinks] used by the hub and the integrations.
@internal
final spanLinks = SpanLinks();

/// Links an object to the streamed span it belongs to, so an error captured
/// somewhere else can be attributed to that span.
///
/// Two kinds of keys are used:
/// - a throwable, linked by the span it aborted. Integrations that mark their
///   span and rethrow are not the capture site; the error surfaces later in
///   application code or a global handler, after the span has ended, and the
///   throwable is the only handle that travels that far.
/// - a request, linked by the span created for it. The span is created in one
///   layer of an HTTP integration and the failure is captured in another, and
///   requests run concurrently, so the request itself is the key.
///
/// Keys are held weakly. Unsupported [Expando] keys are ignored so error
/// capture can fall back to the active span.
@internal
class SpanLinks {
  final _spans = Expando<RecordingSentrySpanV2>('sentry.span_links');

  /// Links [key] to [span] unless [key] is already linked.
  ///
  /// Keeping the first link makes the innermost span win as a throwable
  /// unwinds through nested spans. Pass [replace] for keys that are reused
  /// across spans, such as a request that is retried.
  void link(Object? key, SentrySpanV2 span, {bool replace = false}) {
    final weakKey = _weakKeyOf(key);
    if (weakKey == null || span is! RecordingSentrySpanV2) {
      return;
    }
    try {
      if (replace) {
        _spans[weakKey] = span;
      } else {
        _spans[weakKey] ??= span;
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
