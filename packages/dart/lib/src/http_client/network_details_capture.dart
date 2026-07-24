import 'package:http/http.dart';
import 'package:meta/meta.dart';

/// Captures HTTP request/response headers and bodies for [SentryHttpClient]
/// requests, so they can be shown alongside network spans in Session Replay.
///
/// This is purely a Replay concern, and Replay is currently only
/// implemented by `sentry_flutter`, so there is no default implementation
/// here; [SentryOptions.networkDetailsCapture] is `null` unless a package
/// such as `sentry_flutter` sets one during its own init.
@internal
abstract class NetworkDetailsCapture {
  bool shouldCapture(Uri url);

  Map<String, dynamic> captureRequest(BaseRequest request);

  /// Returns the response to forward to the original caller (its body
  /// stream may need to be replaced after being consumed for capture) and
  /// the captured detail to attach to the replay breadcrumb.
  Future<(StreamedResponse, Map<String, dynamic>)> captureResponse(
    StreamedResponse response,
  );
}
