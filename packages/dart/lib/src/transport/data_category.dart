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
  logItem,
  feedback,
  metric,
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
      case 'log':
        return DataCategory.logItem;
      case 'trace_metric':
        return DataCategory.metric;
      case 'feedback':
        return DataCategory.feedback;
      default:
        return DataCategory.unknown;
    }
  }
}
