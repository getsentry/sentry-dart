import 'rate_limit_category.dart';

/// `RateLimit` containing limited `RateLimitCategory` and duration in milliseconds.
class RateLimit {
  RateLimit(this.category, this.duration);

  final RateLimitCategory category;
  final Duration duration;
}
