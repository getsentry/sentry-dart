import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Associates a throwable with the span that was aborted by it, so that an
/// error captured elsewhere can be linked to that span.
///
/// Integrations that only mark their span and rethrow — the database ones, for
/// example — are not the capture site. The error surfaces later through a
/// global handler or through application code, by which time the span has
/// ended and is reachable from nothing. The throwable is the only handle that
/// travels that far, which makes it the key.
///
/// Keys are held weakly, and the innermost span wins: as a throwable unwinds
/// through nested spans, each marks it, and the first one to do so is the most
/// specific.
@internal
class ThrowableSpanRegistry {
  ThrowableSpanRegistry._();

  static final _spans = Expando<RecordingSentrySpanV2>('sentry.throwable.span');

  static void register(Object? throwable, RecordingSentrySpanV2 span) {
    final key = _keyOf(throwable);
    if (key == null) {
      return;
    }
    _spans[key] ??= span;
  }

  static RecordingSentrySpanV2? lookup(Object? throwable) {
    final key = _keyOf(throwable);
    return key == null ? null : _spans[key];
  }

  /// Returns the throwable to key on, or null when it cannot be tracked.
  ///
  /// A mechanism decorates the throwable after the span marked it, so it is
  /// unwrapped. `Expando` rejects strings, numbers, booleans and records.
  static Object? _keyOf(Object? throwable) {
    if (throwable is ThrowableMechanism) {
      throwable = throwable.throwable;
    }
    if (throwable == null ||
        throwable is String ||
        throwable is num ||
        throwable is bool ||
        throwable is Record) {
      return null;
    }
    return throwable;
  }
}
