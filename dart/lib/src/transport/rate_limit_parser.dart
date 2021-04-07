import 'rate_limit_category.dart';
import 'rate_limit.dart';

class RateLimitParser {
  RateLimitParser(this.header);

  static const httpRetryAfterDefaultDelayMillis = 60000;

  String? header;

  List<RateLimit> parseRateLimitHeader() {
    final rateLimitHeader = header;
    if (rateLimitHeader == null) {
      return [];
    }

    final rateLimits = <RateLimit>[];

    final rateLimitValues = rateLimitHeader.toLowerCase().split(',');
    rateLimitValues.forEach((rateLimitValue) {
      final durationAndCategories = rateLimitValue.trim().split(':');

      if (durationAndCategories.isNotEmpty) {
        final durationInMillis =
            _parseRetryAfterOrDefault(durationAndCategories[0]);

        if (durationAndCategories.length > 1) {
          final allCategories = durationAndCategories[1];
          if (allCategories.isNotEmpty) {
            final categoryValues = allCategories.split(';');
            categoryValues.forEach((categoryValue) {
              final category =
                  RateLimitCategoryExtension.fromStringValue(categoryValue);
              if (category != RateLimitCategory.unknown) {
                rateLimits.add(RateLimit(category, durationInMillis));
              }
            });
          } else {
            rateLimits.add(RateLimit(RateLimitCategory.all, durationInMillis));
          }
        }
      }
    });
    return rateLimits;
  }

  List<RateLimit> parseRetryAfterHeader() {
    return [
      RateLimit(RateLimitCategory.all, _parseRetryAfterOrDefault(header))
    ];
  }

  // Helper

  static int _parseRetryAfterOrDefault(String? value) {
    final durationInSeconds = int.tryParse(value ?? '');
    if (durationInSeconds != null) {
      return durationInSeconds * 1000;
    } else {
      return RateLimitParser.httpRetryAfterDefaultDelayMillis;
    }
  }
}
