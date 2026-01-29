// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:sentry/sentry.dart';

class SentryResponseParser implements ResponseParser {
  SentryResponseParser({ResponseParser? inner, Hub? hub})
      : inner = inner ?? const ResponseParser(),
        _hub = hub ?? HubAdapter() {
    _spanFactory = _hub.options.spanFactory;
  }

  final ResponseParser inner;
  final Hub _hub;
  late final InstrumentationSpanFactory _spanFactory;

  @override
  Response parseResponse(Map<String, dynamic> body) {
    final parentSpan = _spanFactory.getSpan(_hub);
    final span = _spanFactory.createSpan(
      parentSpan,
      'serialize.http.client',
      description: 'Response deserialization '
          'from JSON map to Response object',
    );

    Response result;
    try {
      result = inner.parseResponse(body);
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

  @override
  GraphQLError parseError(Map<String, dynamic> error) =>
      inner.parseError(error);

  @override
  ErrorLocation parseLocation(Map<String, dynamic> location) =>
      inner.parseLocation(location);
}
