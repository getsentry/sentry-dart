enum SentryTransactionNameSource {
  /// User-defined name
  custom,

  /// Raw URL, potentially containing identifiers.
  url,

  /// Parametrized URL / route
  route,

  /// Name of the view handling the request.
  view,

  /// Named after a software component, such as a function or class name.
  component,

  /// Name of a background task
  task,
}
