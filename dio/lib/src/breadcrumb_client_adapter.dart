// ignore_for_file: strict_raw_type

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// A [Dio](https://pub.dev/packages/dio)-package compatible HTTP client adapter
/// which records requests as breadcrumbs.
///
/// Remarks:
/// If this client is used as a wrapper, a call to close also closes the
/// given client.
class BreadcrumbClientAdapter implements HttpClientAdapter {
  // ignore: public_member_api_docs
  BreadcrumbClientAdapter({required HttpClientAdapter client, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _client = client;

  final HttpClientAdapter _client;
  final Hub _hub;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    // See https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/

    var requestHadException = false;
    int? statusCode;
    String? reason;
    int? responseBodySize;

    final stopwatch = Stopwatch();
    stopwatch.start();

    try {
      final response =
          await _client.fetch(options, requestStream, cancelFuture);

      statusCode = response.statusCode;
      reason = response.statusMessage;
      final contentLengthHeader = response.headers['content-length'];
      if (contentLengthHeader != null && contentLengthHeader.isNotEmpty) {
        final headerValue = contentLengthHeader.first;
        responseBodySize = int.tryParse(headerValue);
      }

      return response;
    } catch (_) {
      requestHadException = true;
      rethrow;
    } finally {
      stopwatch.stop();

      final urlDetails =
          HttpSanitizer.sanitizeUrl(options.uri.toString()) ?? UrlDetails();

      final breadcrumb = Breadcrumb.http(
        level: requestHadException ? SentryLevel.error : SentryLevel.info,
        url: Uri.parse(urlDetails.urlOrFallback),
        method: options.method,
        statusCode: statusCode,
        reason: reason,
        requestDuration: stopwatch.elapsed,
        responseBodySize: responseBodySize,
        httpQuery: urlDetails.query,
        httpFragment: urlDetails.fragment,
      );

      await _hub.addBreadcrumb(breadcrumb);
    }
  }

  @override
  void close({bool force = false}) => _client.close(force: force);
}
