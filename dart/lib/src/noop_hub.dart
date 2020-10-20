import 'dart:async';

import 'client.dart';
import 'hub.dart';
import 'protocol/event.dart';
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
  Future<SentryId> captureEvent(Event event) => Future.value(SentryId.emptyId);

  @override
  Future<SentryId> captureException(throwable, {stackTrace}) =>
      Future.value(SentryId.emptyId);

  @override
  Future<SentryId> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    String template,
    List params,
  }) =>
      Future.value(SentryId.emptyId);

  @override
  Hub clone() => this;

  @override
  void close() {}

  @override
  void configureScope(callback) {}

  @override
  bool get isEnabled => false;

  @override
  SentryId get lastEventId => SentryId.emptyId;
}
