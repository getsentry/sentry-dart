import 'dart:async';

import 'protocol.dart';
import 'scope.dart';
import 'sentry_client.dart';

class NoOpSentryClient implements SentryClient {
  NoOpSentryClient._();

  static final NoOpSentryClient _instance = NoOpSentryClient._();

  factory NoOpSentryClient() {
    return _instance;
  }

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    Scope scope,
    dynamic hint,
  }) =>
      Future.value(SentryId.empty());

  @override
  Future<SentryId> captureException(
    dynamic exception, {
    dynamic stackTrace,
    Scope scope,
    dynamic hint,
  }) =>
      Future.value(SentryId.empty());

  @override
  Future<SentryId> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    String template,
    List<dynamic> params,
    Scope scope,
    dynamic hint,
  }) =>
      Future.value(SentryId.empty());

  @override
  Future<void> close() async {
    return;
  }
}
