/// Different category types of data sent to Sentry. Used for rate limiting and client reports.
enum DataCategory {
  all,
  dataCategoryDefault, // default
  error,
  session,
  transaction,
  span,
  attachment,
  security,
  metricBucket,
  unknown;

  static DataCategory fromItemType(String itemType) {
    switch (itemType) {
      case 'event':
        return DataCategory.error;
      case 'session':
        return DataCategory.session;
      case 'attachment':
        return DataCategory.attachment;
      case 'transaction':
        return DataCategory.transaction;
      // The envelope item type used for metrics is statsd,
      // whereas the client report category is metric_bucket
      case 'statsd':
        return DataCategory.metricBucket;
      default:
        return DataCategory.unknown;
    }
  }
}
