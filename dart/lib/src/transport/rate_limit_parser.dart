import 'data_category.dart';
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
    // example: 2700:metric_bucket:organization:quota_exceeded:custom,...
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
          final category = _DataCategoryExtension._fromStringValue(
              categoryValue); // Metric buckets rate limit can have namespaces
          if (category == DataCategory.metricBucket) {
            final namespaces = durationAndCategories.length > 4
                ? durationAndCategories[4]
                : null;
            rateLimits.add(RateLimit(
              category,
              duration,
              namespaces: namespaces?.trim().split(','),
            ));
          } else if (category != DataCategory.unknown) {
            rateLimits.add(RateLimit(category, duration));
          }
        }
      } else {
        rateLimits.add(RateLimit(DataCategory.all, duration));
      }
    }
    return rateLimits;
  }

  List<RateLimit> parseRetryAfterHeader() {
    return [RateLimit(DataCategory.all, _parseRetryAfterOrDefault(_header))];
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

extension _DataCategoryExtension on DataCategory {
  static DataCategory _fromStringValue(String stringValue) {
    switch (stringValue) {
      case '__all__':
        return DataCategory.all;
      case 'default':
        return DataCategory.dataCategoryDefault;
      case 'error':
        return DataCategory.error;
      case 'session':
        return DataCategory.session;
      case 'transaction':
        return DataCategory.transaction;
      case 'attachment':
        return DataCategory.attachment;
      case 'security':
        return DataCategory.security;
      case 'metric_bucket':
        return DataCategory.metricBucket;
    }
    return DataCategory.unknown;
  }
}
