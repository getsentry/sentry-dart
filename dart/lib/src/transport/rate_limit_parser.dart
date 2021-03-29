import 'rate_limit_category.dart';

class RateLimitParser {
  RateLimitParser(this.header);

  static const HTTP_RETRY_AFTER_DEFAULT_DELAY_MILLIS = 60000;

  String? header;

  Map<RateLimitCategory, int> parseRateLimitHeader() {
    final rateLimitHeader = header;
    if (rateLimitHeader == null) {
      return {};
    }

    final rateLimits = <RateLimitCategory, int>{};

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
              rateLimits[category] = durationInMillis;
            }
          }
        } else {
          rateLimits[RateLimitCategory.all] = durationInMillis;
        }
      }
    }
    return rateLimits;
  }

  Map<RateLimitCategory, int> parseRetryAfterHeader() {
    return {
      RateLimitCategory.all: _parseRetryAfterOrDefault(header)
    };
  }

  // Helper

  static int _parseRetryAfterOrDefault(String? value) {
    final durationInSeconds = int.tryParse(value ?? '');
    if (durationInSeconds != null) {
      return durationInSeconds * 1000;
    } else {
      return RateLimitParser.HTTP_RETRY_AFTER_DEFAULT_DELAY_MILLIS;
    }
  }
}
