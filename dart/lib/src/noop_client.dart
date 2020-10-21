import 'dart:async';

import 'client.dart';
import 'protocol.dart';
import 'scope.dart';
import 'sentry_options.dart';
import 'transport/transport.dart';

class NoOpSentryClient implements SentryClient {
  NoOpSentryClient._();

  static final NoOpSentryClient _instance = NoOpSentryClient._();

  factory NoOpSentryClient() {
    return _instance;
  }

  @override
  User userContext;

  @override
  SentryOptions options;

  @override
  Transport transport;

  @override
  Future<SentryId> captureEvent(SentryEvent event, {stackFrameFilter, scope}) =>
      Future.value(SentryId.empty());

  @override
  Future<SentryId> captureException(throwable, {stackTrace, scope}) =>
      Future.value(SentryId.empty());

  @override
  Future<SentryId> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    String template,
    List<dynamic> params,
    Scope scope,
  }) =>
      Future.value(SentryId.empty());

  @override
  Future<void> close() async {
    return;
  }
}
