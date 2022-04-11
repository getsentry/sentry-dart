import 'package:meta/meta.dart';

/// A reason that defines why events were lost, see
/// https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload.
@internal
enum DiscardReason {
  beforeSend,
  eventProcessor,
  sampleRate,
  networkError,
  queueOverflow,
  cacheOverflow,
  rateLimitBackoff,
}

extension OutcomeExtension on DiscardReason {
  String toStringValue() {
    switch (this) {
      case DiscardReason.beforeSend:
        return 'before_send';
      case DiscardReason.eventProcessor:
        return 'event_processor';
      case DiscardReason.sampleRate:
        return 'sample_rate';
      case DiscardReason.networkError:
        return 'network_error';
      case DiscardReason.queueOverflow:
        return 'queue_overflow';
      case DiscardReason.cacheOverflow:
        return 'cache_overflow';
      case DiscardReason.rateLimitBackoff:
        return 'ratelimit_backoff';
    }
  }
}
