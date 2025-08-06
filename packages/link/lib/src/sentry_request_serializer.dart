import 'dart:async';

import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:sentry/sentry.dart';

class SentryRequestSerializer implements RequestSerializer {
  SentryRequestSerializer({RequestSerializer? inner, Hub? hub})
      : inner = inner ?? const RequestSerializer(),
        _hub = hub ?? HubAdapter();

  final RequestSerializer inner;
  final Hub _hub;

  @override
  Map<String, dynamic> serializeRequest(Request request) {
    final span = _hub.getSpan()?.startChild(
          'serialize.http.client',
          description: 'GraphGL request serialization',
        );
    Map<String, dynamic> result;
    try {
      result = inner.serializeRequest(request);
      span?.status = const SpanStatus.ok();
    } catch (e) {
      span?.status = const SpanStatus.unknownError();
      span?.throwable = e;
      rethrow;
    } finally {
      unawaited(span?.finish());
    }
    return result;
  }
}
