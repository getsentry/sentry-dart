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

extension SentryTransactionNameSourceExtension on SentryTransactionNameSource {
  String toStringValue() {
    switch (this) {
      case SentryTransactionNameSource.custom:
        return 'custom';
      case SentryTransactionNameSource.url:
        return 'url';
      case SentryTransactionNameSource.route:
        return 'route';
      case SentryTransactionNameSource.view:
        return 'view';
      case SentryTransactionNameSource.component:
        return 'component';
      case SentryTransactionNameSource.task:
        return 'task';
    }
  }
}
