// ignore_for_file: invalid_use_of_internal_member

import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

import 'constants.dart';
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
        SentrySpanData.httpResponseStatusCodeKey,
        response.statusCode,
      );
      span?.setData(
        SentrySpanData.httpResponseContentLengthKey,
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
      _hub.options.log(
        SentryLevel.warning,
        'Active Sentry transaction does not exist, could not start span for the Supabase operation: from(${supabaseRequest.table})',
        logger: loggerName,
      );
      return null;
    }

    final span = _spanFactory.createSpan(
      parentSpan,
      'db.${supabaseRequest.operation.value}',
      description: 'from(${supabaseRequest.table})',
    );

    if (span == null) {
      return null;
    }

    final dbSchema = supabaseRequest.request.headers['Accept-Profile'] ??
        supabaseRequest.request.headers['Content-Profile'];
    if (dbSchema != null) {
      span.setData(SentrySpanData.dbSchemaKey, dbSchema);
    }
    span.setData(SentrySpanData.dbTableKey, supabaseRequest.table);
    span.setData(SentrySpanData.dbUrlKey, supabaseRequest.request.url.origin);
    final dbSdk = supabaseRequest.request.headers['X-Client-Info'];
    if (dbSdk != null) {
      span.setData(SentrySpanData.dbSdkKey, dbSdk);
    }
    if (supabaseRequest.query.isNotEmpty && _hub.options.sendDefaultPii) {
      span.setData(SentrySpanData.dbQueryKey, supabaseRequest.query);
    }
    if (supabaseRequest.body != null && _hub.options.sendDefaultPii) {
      span.setData(SentrySpanData.dbBodyKey, supabaseRequest.body);
    }
    span.setData(
      SentrySpanData.dbOperationKey,
      supabaseRequest.operation.value,
    );
    span.setData(
      SentrySpanOperations.dbSqlQuery,
      supabaseRequest.generateSqlQuery(),
    );
    span.setData(SentrySpanData.dbSystemKey, SentrySpanData.dbSystemPostgresql);
    span.origin = SentryTraceOrigins.autoDbSupabase;
    return span;
  }
}
