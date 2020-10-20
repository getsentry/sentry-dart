import 'dart:async';

import 'package:sentry/src/client.dart';
import 'package:sentry/src/hub.dart';
import 'package:sentry/src/protocol/sentry_id.dart';
import 'package:sentry/src/protocol/level.dart';
import 'package:sentry/src/protocol/event.dart';

import 'hub.dart';

class NoOpHub implements Hub {
  NoOpHub._();

  static final NoOpHub _instance = NoOpHub._();

  factory NoOpHub() {
    return _instance;
  }

  @override
  void bindClient(SentryClient client) {}

  @override
  Future<SentryId> captureEvent(Event event) => Future.value(SentryId.empty());

  @override
  Future<SentryId> captureException(throwable, {stackTrace}) =>
      Future.value(SentryId.empty());

  @override
  Future<SentryId> captureMessage(
    String message,
    {SeverityLevel level = SeverityLevel.info,
    String template,
    List params,
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
