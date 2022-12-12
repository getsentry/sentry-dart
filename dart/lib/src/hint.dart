import 'sentry_attachment/sentry_attachment.dart';

/// Hints are used in [BeforeSendCallback], [BeforeBreadcrumbCallback] and
/// event processors.
///
/// Event and breadcrumb hints are objects containing various information used
/// to put together an event or a breadcrumb. Typically hints hold the original
/// exception so that additional data can be extracted or grouping can be
/// affected.
///
/// Example:
///
/// ```dart
/// options.beforeSend = (event, {hint}) {
///     final syntheticException = hint?.get(TypeCheckHint.syntheticException);
///     if (syntheticException is FlutterErrorDetails) {
///       // Do something with hint data
///     }
///     return event;
///   };
/// }
/// ```
class Hint {
  final Map<String, Object> _internalStorage = {};

  SentryAttachment? screenshot;

  Hint();

  factory Hint.withMap(Map<String, Object> map) {
    final hint = Hint();
    hint.addAll(map);
    return hint;
  }

  factory Hint.withScreenshot(SentryAttachment screenshot) {
    final hint = Hint();
    hint.screenshot = screenshot;
    return hint;
  }

  // Objects

  void addAll(Map<String, Object> keysAndValues) {
    _internalStorage.addAll(keysAndValues);
  }

  void set(String key, Object value) {
    _internalStorage[key] = value;
  }

  Object? get(String key) {
    return _internalStorage[key];
  }

  void remove(String key) {
    _internalStorage.remove(key);
  }

  void clear() {
    _internalStorage.clear();
  }
}
