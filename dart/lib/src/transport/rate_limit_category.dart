/// Different category types of data sent to Sentry. Used for rate limiting.
enum RateLimitCategory {
  all,
  rate_limit_default, // default
  error,
  session,
  transaction,
  attachment,
  security,
  unknown
}

extension RateLimitCategoryExtension on RateLimitCategory {
  static RateLimitCategory fromStringValue(String stringValue) {
    switch (stringValue) {
      case '__all__':
        return RateLimitCategory.all;
      case 'default':
        return RateLimitCategory.rate_limit_default;
      case 'error':
        return RateLimitCategory.error;
      case 'session':
        return RateLimitCategory.session;
      case 'transaction':
        return RateLimitCategory.transaction;
      case 'attachment':
        return RateLimitCategory.attachment;
      case 'security':
        return RateLimitCategory.security;
    }
    return RateLimitCategory.unknown;
  }

  String toStringValue() {
    switch (this) {
      case RateLimitCategory.all:
        return '__all__';
      case RateLimitCategory.rate_limit_default:
        return 'default';
      case RateLimitCategory.error:
        return 'error';
      case RateLimitCategory.session:
        return 'session';
      case RateLimitCategory.transaction:
        return 'transaction';
      case RateLimitCategory.attachment:
        return 'attachment';
      case RateLimitCategory.security:
        return 'security';
      case RateLimitCategory.unknown:
        return 'unknown';
    }
  }
}
