// ignore_for_file: invalid_use_of_internal_member

import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

import 'constants.dart';
import 'internal_logger.dart';
import 'sentry_supabase_request.dart';

class SentrySupabaseTracingClient extends BaseClient {
  final Client _innerClient;
  final Hub _hub;
  late final InstrumentationSpanFactory _spanFactory;

  SentrySupabaseTracingClient(this._innerClient, this._hub) {
    _spanFactory = _hub.options.spanFactory;
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final supabaseRequest = SentrySupabaseRequest.fromRequest(
      request,
      options: _hub.options,
    );
    if (supabaseRequest == null) {
      return _innerClient.send(request);
    }

    final span = _createSpan(supabaseRequest);

    StreamedResponse? response;

    try {
      response = await _innerClient.send(request);

      span?.setData(
        SemanticAttributesConstants.httpResponseStatusCode,
        response.statusCode,
      );
      span?.setData(
        SemanticAttributesConstants.httpResponseBodySize,
        response.contentLength,
      );
      span?.status = SpanStatus.fromHttpStatusCode(response.statusCode);
    } catch (e) {
      span?.throwable = e;
      span?.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span?.finish();
    }

    return response;
  }

  @override
  void close() {
    _innerClient.close();
  }

  // Helper

  InstrumentationSpan? _createSpan(SentrySupabaseRequest supabaseRequest) {
    final parentSpan = _spanFactory.getSpan(_hub);
    if (parentSpan == null) {
      internalLogger.warning(
        'No active span found. Skipping tracing for Supabase operation: from(${supabaseRequest.table})',
      );
      return null;
    }

    final span = _spanFactory.createSpan(
      parentSpan: parentSpan,
      operation: 'db.${supabaseRequest.operation.value}',
      description: 'from(${supabaseRequest.table})',
    );

    if (span == null) {
      return null;
    }

    final dbSchema = supabaseRequest.request.headers['Accept-Profile'] ??
        supabaseRequest.request.headers['Content-Profile'];
    if (dbSchema != null) {
      span.setData(ProposedSemanticAttributes.dbSchema, dbSchema);
    }
    span.setData(
      SemanticAttributesConstants.dbCollectionName,
      supabaseRequest.table,
    );
    span.setData(
      ProposedSemanticAttributes.dbUrl,
      supabaseRequest.request.url.origin,
    );
    final dbSdk = supabaseRequest.request.headers['X-Client-Info'];
    if (dbSdk != null) {
      span.setData(ProposedSemanticAttributes.dbSdk, dbSdk);
    }
    if (supabaseRequest.body != null && _hub.options.sendDefaultPii) {
      span.setData(ProposedSemanticAttributes.dbBody, supabaseRequest.body);
    }
    span.setData(
      SemanticAttributesConstants.dbOperationName,
      supabaseRequest.operation.value,
    );
    span.setData(
      SemanticAttributesConstants.dbQuerySummary,
      '${supabaseRequest.operation.value} ${supabaseRequest.table}',
    );
    // The generated SQL uses `?` placeholders for all values, so it carries no
    // PII and can be emitted regardless of `sendDefaultPii`.
    span.setData(
      SemanticAttributesConstants.dbQueryText,
      supabaseRequest.generateSqlQuery(),
    );
    span.setData(
      SemanticAttributesConstants.dbSystemName,
      dbSystemNamePostgresql,
    );
    span.origin = SentryTraceOrigins.autoDbSupabase;
    return span;
  }
}
