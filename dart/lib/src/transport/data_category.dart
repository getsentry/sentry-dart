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
