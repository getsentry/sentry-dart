import 'rate_limit_category.dart';

class RateLimit {
  RateLimit(this.category, this.durationInMillis);

  final RateLimitCategory category;
  final int durationInMillis;
}
