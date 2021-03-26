import '../sentry_envelope.dart';
import 'rate_limit_category.dart';

/// Controls retry limits on different category types sent to Sentry.
class RateLimiter {
  final rateLimitedUntil = <RateLimitCategory, DateTime>{};

  SentryEnvelope? filter(SentryEnvelope envelope) {
    return null;
  }
}
