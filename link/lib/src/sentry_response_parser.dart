import 'dart:async';

import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:sentry/sentry.dart';

class SentryResponseParser implements ResponseParser {
  SentryResponseParser({ResponseParser? inner, Hub? hub})
      : inner = inner ?? const ResponseParser(),
        _hub = hub ?? HubAdapter();

  final ResponseParser inner;
  final Hub _hub;

  @override
  Response parseResponse(Map<String, dynamic> body) {
    final span = _hub.getSpan()?.startChild(
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
