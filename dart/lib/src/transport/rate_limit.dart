import 'rate_limit_category.dart';

/// `RateLimit` containing limited `RateLimitCategory` and duration in milliseconds.
class RateLimit {
  RateLimit(this.category, this.durationInMillis);

  final RateLimitCategory category;
  final int durationInMillis;
}
