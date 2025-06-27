import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

import 'sentry_supabase_request.dart';

class SentrySupabaseTracingClient extends BaseClient {
  final Client _innerClient;
  final Hub _hub;

  SentrySupabaseTracingClient(this._innerClient, this._hub);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final supabaseRequest = SentrySupabaseRequest.fromRequest(request);

    final span = _createSpan(supabaseRequest);

    StreamedResponse? response;

    try {
      response = await _innerClient.send(request);

      span?.setData('http.response.status_code', response.statusCode);
      span?.setData('http.response_content_length', response.contentLength);
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

  ISentrySpan? _createSpan(SentrySupabaseRequest supabaseRequest) {
    final currentSpan = _hub.getSpan();
    if (currentSpan == null) {
      return null;
    }
    final span = currentSpan.startChild(
      'db.${supabaseRequest.operation.value}',
      description: 'from(${supabaseRequest.table})',
    );

    final dbSchema = supabaseRequest.request.headers['Accept-Profile'] ??
        supabaseRequest.request.headers['Content-Profile'];
    if (dbSchema != null) {
      span.setData('db.schema', dbSchema);
    }
    span.setData('db.table', supabaseRequest.table);
    span.setData('db.url', supabaseRequest.request.url.origin);
    final dbSdk = supabaseRequest.request.headers['X-Client-Info'];
    if (dbSdk != null) {
      span.setData('db.sdk', dbSdk);
    }
    // ignore: invalid_use_of_internal_member
    if (supabaseRequest.query.isNotEmpty && _hub.options.sendDefaultPii) {
      span.setData('db.query', supabaseRequest.query);
    }
    // ignore: invalid_use_of_internal_member
    if (supabaseRequest.body != null && _hub.options.sendDefaultPii) {
      span.setData('db.body', supabaseRequest.body);
    }
    span.setData('op', 'db.${supabaseRequest.operation.value}');
    // ignore: invalid_use_of_internal_member
    span.setData('origin', SentryTraceOrigins.autoDbSupabase);

    return span;
  }
}
