import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import '../constants.dart';
import '../sentry_options.dart';
import '../utils/internal_logger.dart';
import '../utils/stream_utils.dart';
import '../utils/tracing_utils.dart';

/// Captures HTTP request/response headers and bodies for [SentryHttpClient]
/// requests, gated by [SentryOptions.networkDetailAllowUrls] being
/// non-empty, so they can be shown alongside network spans in Session
/// Replay.
@internal
class NetworkDetailsCapture {
  final SentryOptions _options;

  static const _defaultHeaders = ['content-type', 'content-length', 'accept'];

  /// Matches native's `SentryReplayOptions.MAX_NETWORK_BODY_SIZE`.
  static const maxBodySize = 150 * 1024;

  NetworkDetailsCapture(this._options) {
    if (_options.networkDetailAllowUrls.isNotEmpty) {
      _options.sdk.addFeature(SentryFeatures.replayNetworkDetailsCapturing);
    }
  }

  bool shouldCapture(Uri url) {
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

    final contentLength = response.contentLength;
    if (!_options.sendDefaultPii ||
        !_options.networkCaptureBodies ||
        !_isCapturableContentType(response.headers['content-type']) ||
        (contentLength != null && contentLength > maxBodySize)) {
      return (response, data);
    }

    Uint8List prefix;
    Stream<List<int>> forwardedStream;
    try {
      (prefix, forwardedStream) =
          await bufferStreamPrefix(response.stream, maxBytes: maxBodySize);
    } catch (exception) {
      internalLogger.warning(
        () => 'Failed to capture response body for replay: $exception',
      );
      // The stream may be partially consumed at this point, so there's no
      // safe way to forward it to the original caller anymore.
      return (response, data);
    }

    final forwarded = _copyWithStream(response, forwardedStream);
    // The prefix is already buffered at this point, so decoding failures
    // (e.g. malformed encoding info) shouldn't prevent forwarding it as-is.
    try {
      data['body'] = _truncateBytes(prefix);
    } catch (exception) {
      internalLogger.warning(
        () => 'Failed to capture response body for replay: $exception',
      );
    }
    return (forwarded, data);
  }

  String? _captureRequestBody(BaseRequest request) {
    if (!_options.sendDefaultPii || !_options.networkCaptureBodies) {
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
      return _truncateBytes(request.bodyBytes);
    } catch (exception) {
      internalLogger.warning(
        () => 'Failed to capture request body for replay: $exception',
      );
      return null;
    }
  }

  StreamedResponse _copyWithStream(
      StreamedResponse response, Stream<List<int>> stream) {
    return StreamedResponse(
      stream,
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
    // Only the default headers are content-type-like metadata; anything
    // beyond that (e.g. Authorization, Cookie) is opted into by name via
    // [extra] and may contain PII, so it also requires sendDefaultPii.
    final allowed = {
      ..._defaultHeaders,
      if (_options.sendDefaultPii)
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

  String _truncateBytes(Uint8List bytes) {
    final view = bytes.length <= maxBodySize
        ? bytes
        : Uint8List.sublistView(bytes, 0, maxBodySize);
    return utf8.decode(view, allowMalformed: true);
  }
}
