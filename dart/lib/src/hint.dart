import 'sentry_attachment/sentry_attachment.dart';
import 'sentry_options.dart';

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
/// options.beforeSend = (event, hint) {
///     final syntheticException = hint.get(TypeCheckHint.syntheticException);
///     if (syntheticException is FlutterErrorDetails) {
///       // Do something with hint data
///     }
///     return event;
///   };
/// }
/// ```
///
/// The [Hint] can also be used to add attachments to events.
///
/// Example:
///
/// ```dart
/// import 'dart:convert';
///
/// options.beforeSend = (event, hint) {
///   final text = 'This event should not be sent happen in prod. Investigate.';
///   final textAttachment = SentryAttachment.fromIntList(
///     utf8.encode(text),
///     'event_info.txt',
///     contentType: 'text/plain',
///   );
///   hint.attachments.add(textAttachment);
///   return event;
/// };
/// ```
class Hint {
  final Map<String, dynamic> _internalStorage = {};

  final List<SentryAttachment> attachments = [];

  SentryAttachment? screenshot;

  SentryAttachment? viewHierarchy;

  Hint();

  factory Hint.withAttachment(SentryAttachment attachment) {
    final hint = Hint();
    hint.attachments.add(attachment);
    return hint;
  }

  factory Hint.withAttachments(List<SentryAttachment> attachments) {
    final hint = Hint();
    hint.attachments.addAll(attachments);
    return hint;
  }

  factory Hint.withMap(Map<String, dynamic> map) {
    final hint = Hint();
    hint.addAll(map);
    return hint;
  }

  factory Hint.withScreenshot(SentryAttachment screenshot) {
    final hint = Hint();
    hint.screenshot = screenshot;
    return hint;
  }

  factory Hint.withViewHierarchy(SentryAttachment viewHierarchy) {
    final hint = Hint();
    hint.viewHierarchy = viewHierarchy;
    return hint;
  }

  // Key/Value Storage

  void addAll(Map<String, dynamic> keysAndValues) {
    final withoutNullValues =
        keysAndValues.map((key, value) => MapEntry(key, value ?? "null"));
    _internalStorage.addAll(withoutNullValues);
  }

  void set(String key, dynamic value) {
    _internalStorage[key] = value ?? "null";
  }

  dynamic get(String key) {
    return _internalStorage[key];
  }

  void remove(String key) {
    _internalStorage.remove(key);
  }

  void clear() {
    _internalStorage.clear();
  }
}
