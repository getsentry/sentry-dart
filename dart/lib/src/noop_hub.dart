import 'dart:async';

import 'client.dart';
import 'hub.dart';
import 'protocol/sentry_event.dart';
import 'protocol/sentry_level.dart';
import 'protocol/sentry_id.dart';

class NoOpHub implements Hub {
  NoOpHub._();

  static final NoOpHub _instance = NoOpHub._();

  factory NoOpHub() {
    return _instance;
  }

  @override
  void bindClient(SentryClient client) {}

  @override
  Future<SentryId> captureEvent(SentryEvent event, {dynamic hint}) =>
      Future.value(SentryId.empty());

  @override
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    dynamic hint,
  }) =>
      Future.value(SentryId.empty());

  @override
  Future<SentryId> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    String template,
    List params,
    dynamic hint,
  }) =>
      Future.value(SentryId.empty());

  @override
  Hub clone() => this;

  @override
  void close() {}

  @override
  void configureScope(callback) {}

  @override
  bool get isEnabled => false;

  @override
  SentryId get lastEventId => SentryId.empty();
}
