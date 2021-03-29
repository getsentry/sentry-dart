import '../current_date_provider.dart';
import '../sentry_envelope.dart';
import 'rate_limit_category.dart';

/// Controls retry limits on different category types sent to Sentry.
class RateLimiter {
  RateLimiter(this.currentDateTimeProvider);

  final CurrentDateTimeProvider currentDateTimeProvider;
  final rateLimitedUntil = <RateLimitCategory, DateTime>{};

  SentryEnvelope? filter(SentryEnvelope envelope) {
    return null;
  }

  void updateRetryAfterLimits(
      String? sentryRateLimitHeader, String? retryAfterHeader, int errorCode) {

    
  }
}
