import 'package:http/http.dart';
import 'package:sentry/sentry.dart';
import 'sentry_supabase_client_error.dart';

import 'sentry_supabase_request.dart';

class SentrySupabaseErrorClient extends BaseClient {
  final Client _innerClient;
  final Hub _hub;

  SentrySupabaseErrorClient(this._innerClient, this._hub);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    StreamedResponse? response;
    dynamic exception;
    StackTrace? stackTrace;
    int? statusCode;

    try {
      response = await _innerClient.send(request);
      statusCode = response.statusCode;
    } catch (e, st) {
      exception = e;
      stackTrace = st;
      rethrow;
    } finally {
      final hasException = exception != null;
      final hasErrorResponse = statusCode != null && statusCode >= 400;

      if (hasException || hasErrorResponse) {
        _captureException(
          exception,
          stackTrace,
          request,
          response,
        );
      }
    }
    return response;
  }

  @override
  void close() {
    _innerClient.close();
  }

  void _captureException(
    dynamic exception,
    StackTrace? stackTrace,
    BaseRequest request,
    StreamedResponse? response,
  ) {
    exception ??= SentrySupabaseClientError(
      'Supabase HTTP Client Error with Status Code: ${response?.statusCode}',
    );
    final mechanism = Mechanism(type: 'SentrySupabaseClient');
    final throwable = ThrowableMechanism(mechanism, exception);

    final event = SentryEvent(throwable: throwable);
    final hint = Hint.withMap({TypeCheckHint.httpRequest: request});

    final supabaseRequest = SentrySupabaseRequest.fromRequest(request);
    if (supabaseRequest != null) {
      event.contexts['supabase'] = {
        'table': supabaseRequest.table,
        'operation': supabaseRequest.operation.value,
        // ignore: invalid_use_of_internal_member
        if (supabaseRequest.query.isNotEmpty && _hub.options.sendDefaultPii)
          'query': supabaseRequest.query,
        // ignore: invalid_use_of_internal_member
        if (supabaseRequest.body != null && _hub.options.sendDefaultPii)
          'body': supabaseRequest.body,
      };
    }

    _hub.captureEvent(event, stackTrace: stackTrace, hint: hint);
  }
}
