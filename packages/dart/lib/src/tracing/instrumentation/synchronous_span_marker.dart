import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Data key marking a span as wrapping a synchronous operation.
///
/// This is an internal signal between auto-instrumentation (which knows an
/// operation ran synchronously) and the Flutter `ThreadInfoIntegration` (which
/// knows the isolate). The integration consumes it to derive
/// `blocked_main_thread` and strips it, so it is not sent to Sentry.
const _synchronousAttributeKey = 'sync';

/// Marks a span as wrapping a synchronous operation.
@internal
extension SynchronousInstrumentationSpan on InstrumentationSpan {
  /// Flags this span as a synchronous operation for main-thread detection.
  void markSynchronous() => setData(_synchronousAttributeKey, true);
}

/// Reads and clears the synchronous marker on a v1 span.
@internal
extension SynchronousSentrySpan on SentrySpan {
  /// Whether the synchronous marker is present, regardless of its value.
  ///
  /// Used to decide whether the marker must be stripped, so a stray non-`true`
  /// value is never sent to Sentry.
  bool get hasSynchronousMarker => data.containsKey(_synchronousAttributeKey);

  /// Whether this span was flagged as a synchronous operation.
  bool get isSynchronous => data[_synchronousAttributeKey] == true;

  /// Removes the synchronous marker so it is not sent to Sentry.
  void clearSynchronous() => removeData(_synchronousAttributeKey);
}

/// Reads and clears the synchronous marker on a v2 span.
@internal
extension SynchronousSentrySpanV2 on SentrySpanV2 {
  /// Whether the synchronous marker is present, regardless of its value.
  ///
  /// Used to decide whether the marker must be stripped, so a stray non-`true`
  /// value is never sent to Sentry.
  bool get hasSynchronousMarker =>
      attributes.containsKey(_synchronousAttributeKey);

  /// Whether this span was flagged as a synchronous operation.
  bool get isSynchronous => attributes[_synchronousAttributeKey]?.value == true;

  /// Removes the synchronous marker so it is not sent to Sentry.
  void clearSynchronous() => removeAttribute(_synchronousAttributeKey);
}
