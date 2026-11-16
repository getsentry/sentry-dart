// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:http/http.dart';
import 'package:sentry/sentry.dart';
// ignore: implementation_imports
import 'package:sentry/src/telemetry/span/instrumentation/span_links.dart';
import 'sentry_supabase_client_error.dart';

import 'sentry_supabase_request.dart';

class SentrySupabaseErrorClient extends BaseClient {
  final Client _innerClient;
  final Hub _hub;
  final List<SentryStatusCode> failedRequestStatusCodes;

  SentrySupabaseErrorClient(
    this._innerClient,
    this._hub, {
    List<SentryStatusCode>? failedRequestStatusCodes,
  }) : failedRequestStatusCodes =
           failedRequestStatusCodes ??
           SentryHttpClient.defaultFailedRequestStatusCodes;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final supabaseRequest = SentrySupabaseRequest.fromRequest(
      request,
      options: _hub.options,
    );

    if (supabaseRequest == null) {
      return _innerClient.send(request);
    }

    try {
      final response = await _innerClient.send(request);
      if (_shouldCaptureError(response.statusCode)) {
        unawaited(
          _captureException(null, null, request, response, supabaseRequest),
        );
      }
      return response;
    } catch (e, st) {
      unawaited(_captureException(e, st, request, null, supabaseRequest));
      rethrow;
    }
  }

  @override
  void close() {
    _innerClient.close();
  }

  bool _shouldCaptureError(int statusCode) {
    return failedRequestStatusCodes._containsStatusCode(statusCode);
  }

  Future<SentryId> _captureException(
    dynamic exception,
    StackTrace? stackTrace,
    BaseRequest request,
    StreamedResponse? response,
    SentrySupabaseRequest supabaseRequest,
  ) {
    exception ??= SentrySupabaseClientError(
      'Supabase HTTP Client Error with Status Code: ${response?.statusCode}',
    );
    final mechanism = Mechanism(type: 'SentrySupabaseClient', handled: true);
    final throwable = ThrowableMechanism(mechanism, exception);

    final event = SentryEvent(throwable: throwable);
    final hint = Hint.withMap({TypeCheckHint.httpRequest: request});

    event.contexts['supabase'] = {
      'table': supabaseRequest.table,
      'operation': supabaseRequest.operation.value,
      if (supabaseRequest.query.isNotEmpty && _hub.options.sendDefaultPii)
        'query': supabaseRequest.query,
      if (supabaseRequest.body != null && _hub.options.sendDefaultPii)
        'body': supabaseRequest.body,
    };

    final span = spanLinks.spanFor(request);
    return _hub.captureEvent(
      event,
      stackTrace: stackTrace,
      hint: hint,
      withScope: span == null ? null : (scope) => scope.setActiveSpan(span),
    );
  }
}

extension _ListX on List<SentryStatusCode> {
  bool _containsStatusCode(int? statusCode) {
    if (statusCode == null) {
      return false;
    } else {
      return any((element) => element.isInRange(statusCode));
    }
  }
}
