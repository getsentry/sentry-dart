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
  ignored,
}
