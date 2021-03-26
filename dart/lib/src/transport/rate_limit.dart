import 'rate_limit_category.dart';

class RateLimit {
  RateLimit(this.durationInMillis, this.category);

  static const HTTP_RETRY_AFTER_DEFAULT_DELAY_MILLIS = 60000;

  final RateLimitCategory category;
  final int durationInMillis;
}

extension RateLimitParser on RateLimit {

  static List<RateLimit> parseRateLimitHeader(String rateLimitHeader) {
    final rateLimits = <RateLimit>[];

    final rateLimitValues = rateLimitHeader.toLowerCase().split(',');
    for (final rateLimitValue in rateLimitValues) {
      final durationAndCategories = rateLimitValue.trim().split(':');

      if (durationAndCategories.isNotEmpty) {
        final durationInMillis =
            _parseRetryAfterOrDefault(durationAndCategories[0]);

        if (durationAndCategories.length > 1) {
          final categoryValues = durationAndCategories[1].split(';');
          for (final categoryValue in categoryValues) {
            final category =
                RateLimitCategoryExtension.fromStringValue(categoryValue);
            if (category != RateLimitCategory.unknown) {
              rateLimits.add(RateLimit(durationInMillis, category));
            }
          }
        } else {
          rateLimits.add(RateLimit(durationInMillis, RateLimitCategory.all));
        }
      }
    }
    return rateLimits;
  }

  static List<RateLimit> parseRetryAfterHeader(String? retryAfterHeader) {
    return [
      RateLimit(
          _parseRetryAfterOrDefault(retryAfterHeader), RateLimitCategory.all)
    ];
  }

  // Helper

  static int _parseRetryAfterOrDefault(String? value) {
    final durationInSeconds = int.tryParse(value ?? '');
    if (durationInSeconds != null) {
      return durationInSeconds * 1000;
    } else {
      return RateLimit.HTTP_RETRY_AFTER_DEFAULT_DELAY_MILLIS;
    }
  }
}
