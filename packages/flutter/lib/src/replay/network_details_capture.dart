// ignore_for_file: invalid_use_of_internal_member
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/constants.dart';
// ignore: implementation_imports
import 'package:sentry/src/http_client/network_details_capture.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/tracing_utils.dart';

import '../sentry_flutter_options.dart';
import '../utils/internal_logger.dart';

/// Implementation of [NetworkDetailsCapture] backed by
/// [SentryFlutterOptions.replay], gated by
/// `SentryReplayOptions.networkDetailAllowUrls` being non-empty.
@internal
class FlutterNetworkDetailsCapture implements NetworkDetailsCapture {
  final SentryFlutterOptions _options;

  static const _defaultHeaders = ['content-type', 'content-length', 'accept'];

  /// Matches native's `SentryReplayOptions.MAX_NETWORK_BODY_SIZE`.
  static const maxBodySize = 150 * 1024;

  FlutterNetworkDetailsCapture(this._options);

  @override
  bool shouldCapture(Uri url) {
    if (_options.replay.networkDetailAllowUrls.isEmpty) {
      return false;
    }
    // Checked lazily rather than in the constructor: this is built in
    // `_initDefaultValues`, before the user's `optionsConfiguration` runs, so
    // `networkDetailAllowUrls` wouldn't be populated yet at construction time.
    _options.sdk.addFeature(SentryFeatures.replayNetworkDetailsCapturing);
    final target = url.toString();
    if (containsTargetOrMatchesRegExp(
        _options.replay.networkDetailDenyUrls, target)) {
      return false;
    }
    return containsTargetOrMatchesRegExp(
        _options.replay.networkDetailAllowUrls, target);
  }

  @override
  Map<String, dynamic> captureRequest(BaseRequest request) {
    final data = <String, dynamic>{
      'headers': _filterHeaders(
          request.headers, _options.replay.networkRequestHeaders),
    };
    final body = _captureRequestBody(request);
    if (body != null) {
      data['body'] = body;
    }
    return data;
  }

  @override
  Future<(StreamedResponse, Map<String, dynamic>)> captureResponse(
    StreamedResponse response,
  ) async {
    final data = <String, dynamic>{
      'headers': _filterHeaders(
          response.headers, _options.replay.networkResponseHeaders),
    };

    final contentLength = response.contentLength;
    if (!_options.sendDefaultPii ||
        !_options.replay.networkCaptureBodies ||
        !_isCapturableContentType(response.headers['content-type']) ||
        (contentLength != null && contentLength > maxBodySize)) {
      return (response, data);
    }

    Uint8List bytes;
    try {
      bytes = await response.stream.toBytes();
    } catch (exception) {
      internalLogger.warning(
        () => 'Failed to capture response body for replay: $exception',
      );
      // The stream may be partially consumed at this point, so there's no
      // safe way to forward it to the original caller anymore.
      return (response, data);
    }

    // The body is already fully read at this point, so decoding failures
    // (e.g. malformed encoding info) shouldn't prevent forwarding it as-is.
    final forwarded = _copyWithBytes(response, bytes);
    try {
      data['body'] = _truncateBytes(bytes);
    } catch (exception) {
      internalLogger.warning(
        () => 'Failed to capture response body for replay: $exception',
      );
    }
    return (forwarded, data);
  }

  String? _captureRequestBody(BaseRequest request) {
    if (!_options.sendDefaultPii || !_options.replay.networkCaptureBodies) {
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
    // Consistent with the response path: a body already known to exceed the
    // cap is skipped entirely rather than attaching a truncated fragment.
    if (request.bodyBytes.length > maxBodySize) {
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
