// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:sentry/sentry.dart';

class SentryRequestSerializer implements RequestSerializer {
  SentryRequestSerializer({RequestSerializer? inner, Hub? hub})
      : inner = inner ?? const RequestSerializer(),
        _hub = hub ?? HubAdapter() {
    _spanFactory = _hub.options.spanFactory;
  }

  final RequestSerializer inner;
  final Hub _hub;
  late final InstrumentationSpanFactory _spanFactory;

  @override
  Map<String, dynamic> serializeRequest(Request request) {
    final parentSpan = _spanFactory.getSpan(_hub);
    final span = _spanFactory.createSpan(
      parentSpan,
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
