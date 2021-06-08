import 'rate_limit_category.dart';
import 'rate_limit.dart';

/// Parse rate limit categories and times from response header payloads.
class RateLimitParser {
  RateLimitParser(this._header);

  static const httpRetryAfterDefaultDelay = Duration(milliseconds: 60000);

  final String? _header;

  List<RateLimit> parseRateLimitHeader() {
    final rateLimitHeader = _header;
    if (rateLimitHeader == null) {
      return [];
    }
    final rateLimits = <RateLimit>[];
    final rateLimitValues = rateLimitHeader.toLowerCase().split(',');
    for (final rateLimitValue in rateLimitValues) {
      final durationAndCategories = rateLimitValue.trim().split(':');
      if (durationAndCategories.isEmpty) {
        continue;
      }
      final duration = _parseRetryAfterOrDefault(durationAndCategories[0]);
      if (durationAndCategories.length <= 1) {
        continue;
      }
      final allCategories = durationAndCategories[1];
      if (allCategories.isNotEmpty) {
        final categoryValues = allCategories.split(';');
        for (final categoryValue in categoryValues) {
          final category =
              RateLimitCategoryExtension.fromStringValue(categoryValue);
          if (category != RateLimitCategory.unknown) {
            rateLimits.add(RateLimit(category, duration));
          }
        }
      } else {
        rateLimits.add(RateLimit(RateLimitCategory.all, duration));
      }
    }
    return rateLimits;
  }

  List<RateLimit> parseRetryAfterHeader() {
    return [
      RateLimit(RateLimitCategory.all, _parseRetryAfterOrDefault(_header))
    ];
  }

  // Helper

  static Duration _parseRetryAfterOrDefault(String? value) {
    final durationInSeconds = int.tryParse(value ?? '');
    if (durationInSeconds != null) {
      return Duration(seconds: durationInSeconds);
    } else {
      return RateLimitParser.httpRetryAfterDefaultDelay;
    }
  }
}
