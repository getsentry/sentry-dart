/// Different category types of data sent to Sentry. Used for rate limiting and client reports.
enum DataCategory {
  all,
  dataCategoryDefault, // default
  error,
  session,
  transaction,
  attachment,
  security,
  metricBucket,
  unknown
}

extension DataCategoryExtension on DataCategory {
  static DataCategory fromStringValue(String stringValue) {
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

  String toStringValue() {
    switch (this) {
      case DataCategory.all:
        return '__all__';
      case DataCategory.dataCategoryDefault:
        return 'default';
      case DataCategory.error:
        return 'error';
      case DataCategory.session:
        return 'session';
      case DataCategory.transaction:
        return 'transaction';
      case DataCategory.attachment:
        return 'attachment';
      case DataCategory.security:
        return 'security';
      case DataCategory.metricBucket:
        return 'metric_bucket';
      case DataCategory.unknown:
        return 'unknown';
    }
  }
}
