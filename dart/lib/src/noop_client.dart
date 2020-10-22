import 'dart:async';

import 'client.dart';
import 'protocol.dart';
import 'scope.dart';
import 'sentry_options.dart';
import 'stack_trace.dart';

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
  String origin;

  @override
  List<int> bodyEncoder(
    Map<String, dynamic> data,
    Map<String, String> headers,
  ) =>
      [];

  @override
  Map<String, String> buildHeaders(String authHeader) => {};

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    StackFrameFilter stackFrameFilter,
    Scope scope,
    dynamic hint,
  }) =>
      Future.value(SentryId.empty());

  @override
  Future<SentryId> captureException(
    dynamic throwable, {
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
  String get clientId => 'No-op';

  @override
  Future<void> close() async {
    return;
  }

  @override
  Uri get dsnUri => null;

  @override
  String get postUri => null;

  @override
  String get projectId => null;

  @override
  String get publicKey => null;

  @override
  Sdk get sdk => null;

  @override
  String get secretKey => null;
}
