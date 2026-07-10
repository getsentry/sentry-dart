import 'dart:convert';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import '../sentry_options.dart';
import '../utils/internal_logger.dart';
import '../utils/tracing_utils.dart';

/// Captures HTTP request/response headers and bodies for [SentryHttpClient]
/// requests, gated by [SentryOptions.enableReplayNetworkDetailsCapturing] and
/// [SentryOptions.networkDetailAllowUrls], so they can be shown alongside
/// network spans in Session Replay.
@internal
class NetworkDetailsCapture {
  NetworkDetailsCapture(this._options);

  final SentryOptions _options;

  static const _defaultHeaders = ['content-type', 'content-length', 'accept'];

  /// Matches native's `SentryReplayOptions.MAX_NETWORK_BODY_SIZE`.
  static const maxBodySize = 150 * 1024;

  bool shouldCapture(Uri url) {
    if (!_options.enableReplayNetworkDetailsCapturing) {
      return false;
    }
    if (_options.networkDetailAllowUrls.isEmpty) {
      return false;
    }
    final target = url.toString();
    if (containsTargetOrMatchesRegExp(_options.networkDetailDenyUrls, target)) {
      return false;
    }
    return containsTargetOrMatchesRegExp(
        _options.networkDetailAllowUrls, target);
  }

  Map<String, dynamic> captureRequest(BaseRequest request) {
    final data = <String, dynamic>{
      'headers':
          _filterHeaders(request.headers, _options.networkRequestHeaders),
    };
    final body = _captureRequestBody(request);
    if (body != null) {
      data['body'] = body;
    }
    return data;
  }

  String? _captureRequestBody(BaseRequest request) {
    if (!_options.networkCaptureBodies) {
      return null;
    }
    // Only `Request` exposes its body synchronously without finalizing the
    // request stream, which `BaseClient` implementations are only allowed to
    // do once.
    if (request is! Request) {
      return null;
    }
    if (!_isCapturableContentType(request.headers['content-type'])) {
      return null;
    }
    try {
      return _truncate(request.body);
    } catch (exception) {
      internalLogger.warning(
        () => 'Failed to capture request body for replay: $exception',
      );
      return null;
    }
  }

  /// Returns the response to forward to the original caller (its body
  /// stream may need to be replaced after being consumed for capture) and
  /// the captured detail to attach to the replay breadcrumb.
  Future<(StreamedResponse, Map<String, dynamic>)> captureResponse(
    StreamedResponse response,
  ) async {
    final data = <String, dynamic>{
      'headers':
          _filterHeaders(response.headers, _options.networkResponseHeaders),
    };

    if (!_options.networkCaptureBodies ||
        !_isCapturableContentType(response.headers['content-type'])) {
      return (response, data);
    }

    try {
      final bytes = await response.stream.toBytes();
      data['body'] = _truncate(utf8.decode(bytes, allowMalformed: true));
      return (_copyWithBytes(response, bytes), data);
    } catch (exception) {
      internalLogger.warning(
        () => 'Failed to capture response body for replay: $exception',
      );
      // The stream may be partially consumed at this point, so there's no
      // safe way to forward it to the original caller anymore.
      return (response, data);
    }
  }

  StreamedResponse _copyWithBytes(StreamedResponse response, List<int> bytes) {
    return StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Map<String, String> _filterHeaders(
      Map<String, String> headers, List<String> extra) {
    final allowed = {
      ..._defaultHeaders,
      ...extra.map((header) => header.toLowerCase()),
    };
    final result = <String, String>{};
    headers.forEach((key, value) {
      if (allowed.contains(key.toLowerCase())) {
        result[key] = value;
      }
    });
    return result;
  }

  bool _isCapturableContentType(String? contentType) {
    if (contentType == null) {
      return false;
    }
    final normalized = contentType.toLowerCase();
    return normalized.contains('json') ||
        normalized.startsWith('text/') ||
        normalized.contains('x-www-form-urlencoded');
  }

  String _truncate(String body) {
    final bytes = utf8.encode(body);
    if (bytes.length <= maxBodySize) {
      return body;
    }
    return utf8.decode(bytes.sublist(0, maxBodySize), allowMalformed: true);
  }
}
