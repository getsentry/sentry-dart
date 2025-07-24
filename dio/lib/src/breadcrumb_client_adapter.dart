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
      // ignore: invalid_use_of_internal_member
      responseBodySize = HttpHeaderUtils.getContentLength(response.headers);

      return response;
    } catch (exception) {
      requestHadException = true;

      // If the exception contains an HTTP response (e.g. non-2xx status
      // code which Dio treats as an error by default), we can still extract
      // useful information such as the status code and reason in order to
      // enrich the resulting breadcrumb.
      if (exception is DioError) {
        statusCode = exception.response?.statusCode;
        reason = exception.response?.statusMessage;

        // Try to obtain the response body size when available.
        final responseHeaders = exception.response?.headers;
        if (responseHeaders != null) {
          // ignore: invalid_use_of_internal_member
          responseBodySize =
              HttpHeaderUtils.getContentLength(responseHeaders.map);
        }
      }

      rethrow;
    } finally {
      stopwatch.stop();

      final urlDetails =
          // ignore: invalid_use_of_internal_member
          HttpSanitizer.sanitizeUrl(options.uri.toString()) ?? UrlDetails();

      SentryLevel? level;
      if (requestHadException) {
        level = SentryLevel.error;
      } else if (statusCode != null) {
        // ignore: invalid_use_of_internal_member
        level = getBreadcrumbLogLevelFromHttpStatusCode(statusCode);
      }

      final breadcrumb = Breadcrumb.http(
        level: level,
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
