import 'protocol.dart';

/// A [SentryEventLike] mixin that is extended by [SentryEvent] and [SentryTransaction]
mixin SentryEventLike<T> {
  @Deprecated('Assign values directly to the instance.')
  T copyWith();
}
