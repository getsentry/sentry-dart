// ignore_for_file: strict_raw_type

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

/// A [Dio](https://pub.dev/packages/dio)-package compatible HTTP client adapter
/// which records events for failed requests.
///
/// Configured with default values, this captures requests which throw an
/// exception.
/// This can be for example for the following reasons:
/// - In an browser environment this can be requests which fail because of CORS.
/// - In an mobile or desktop application this can be requests which failed
///   because the connection was interrupted.
///
/// Additionally you can configure specific HTTP response codes to be considered
/// as a failed request. In the following example, the status codes 404 and 500
/// are considered a failed request.
///
/// Remarks:
/// If this client is used as a wrapper, a call to close also closes the
/// given client.
@experimental
class FailedRequestClientAdapter extends HttpClientAdapter {
  // ignore: public_member_api_docs
  FailedRequestClientAdapter({
    required HttpClientAdapter client,
    this.maxRequestBodySize = MaxRequestBodySize.never,
    this.failedRequestStatusCodes = const [],
    this.captureFailedRequests = true,
    this.sendDefaultPii = false,
    Hub? hub,
  })  : _hub = hub ?? HubAdapter(),
        _client = client;

  final HttpClientAdapter _client;
  final Hub _hub;

  /// Configures wether to record exceptions for failed requests.
  /// Examples for captures exceptions are:
  /// - In an browser environment this can be requests which fail because of CORS.
  /// - In an mobile or desktop application this can be requests which failed
  ///   because the connection was interrupted.
  final bool captureFailedRequests;

  /// Configures up to which size request bodies should be included in events.
  /// This does not change wether an event is captured.
  final MaxRequestBodySize maxRequestBodySize;

  /// Describes which HTTP status codes should be considered as a failed
  /// requests.
  ///
  /// Per default no status code is considered a failed request.
  final List<SentryStatusCode> failedRequestStatusCodes;

  /// Configures wether default PII is enabled for this client adapter.
  final bool sendDefaultPii;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    int? statusCode;
    Object? exception;
    StackTrace? stackTrace;

    final stopwatch = Stopwatch();
    stopwatch.start();

    try {
      final response =
          await _client.fetch(options, requestStream, cancelFuture);
      statusCode = response.statusCode;
      return response;
    } catch (e, st) {
      exception = e;
      stackTrace = st;
      rethrow;
    } finally {
      stopwatch.stop();

      // If captureFailedRequests is true, there statusCode is null.
      // So just one of these blocks can be called.

      if (captureFailedRequests && exception != null) {
        await _captureEvent(
          exception: exception,
          stackTrace: stackTrace,
          options: options,
          requestDuration: stopwatch.elapsed,
        );
      } else if (failedRequestStatusCodes.containsStatusCode(statusCode)) {
        final message =
            'Event was captured because the request status code was $statusCode';
        final httpException = SentryHttpClientError(message);

        // Capture an exception if the status code is considered bad
        await _captureEvent(
          exception: exception ?? httpException,
          options: options,
          reason: message,
          requestDuration: stopwatch.elapsed,
        );
      }
    }
  }

  @override
  void close({bool force = false}) => _client.close(force: force);

  // See https://develop.sentry.dev/sdk/event-payloads/request/
  Future<void> _captureEvent({
    required Object? exception,
    StackTrace? stackTrace,
    String? reason,
    required Duration requestDuration,
    required RequestOptions options,
  }) async {
    // As far as I can tell there's no way to get the uri without the query part
    // so we replace it with an empty string.
    final urlWithoutQuery = options.uri.replace(query: '').toString();

    final query = options.uri.query.isEmpty ? null : options.uri.query;

    final headers = options.headers
        .map((key, dynamic value) => MapEntry(key, value?.toString() ?? ''));

    final sentryRequest = SentryRequest(
      method: options.method,
      headers: sendDefaultPii ? headers : null,
      url: urlWithoutQuery,
      queryString: query,
      cookies: sendDefaultPii ? options.headers['Cookie']?.toString() : null,
      other: {
        'duration': requestDuration.toString(),
      },
    );

    final mechanism = Mechanism(
      type: 'SentryHttpClient',
      description: reason,
    );
    final throwableMechanism = ThrowableMechanism(mechanism, exception);

    final event = SentryEvent(
      throwable: throwableMechanism,
      request: sentryRequest,
    );
    await _hub.captureEvent(event, stackTrace: stackTrace);
  }
}

extension _ListX on List<SentryStatusCode> {
  bool containsStatusCode(int? statusCode) {
    if (statusCode == null) {
      return false;
    }
    return any((element) => element.isInRange(statusCode));
  }
}
