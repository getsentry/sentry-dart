import 'dart:async';

import 'package:http/src/client.dart';

import 'client.dart';
import 'protocol.dart';
import 'scope.dart';

class NoOpSentryClient implements SentryClient {
  NoOpSentryClient._();

  static final NoOpSentryClient _instance = NoOpSentryClient._();

  factory NoOpSentryClient() {
    return _instance;
  }

  @override
  User userContext;

  @override
  List<int> bodyEncoder(
    Map<String, dynamic> data,
    Map<String, String> headers,
  ) =>
      [];

  @override
  Map<String, String> buildHeaders(String authHeader) => {};

  @override
  Future<SentryId> captureEvent(Event event, {stackFrameFilter, scope}) =>
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
  String get clientId => 'No-op';

  @override
  Future<void> close() async {
    return;
  }

  @override
  Uri get dsnUri => null;

  @override
  Event get environmentAttributes => null;

  @override
  Client get httpClient => null;

  @override
  String get origin => null;

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
