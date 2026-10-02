import 'package:meta/meta.dart';

import 'instrumentation_span.dart';

/// Associates an HTTP request with the `http.client` span created for it, so
/// that a failed request captured elsewhere can be linked to that span.
///
/// The two halves of an HTTP integration do not share per-request state: the
/// span is created by the tracing client while the error is captured by the
/// failed request client (`http`) or by an error interceptor running in another
/// async context (Dio). Requests also run concurrently, so the association has
/// to be keyed by the request itself.
///
/// Keys are held weakly: an entry is registered for every request but only read
/// back for the ones that fail, and there is no hook that runs late enough to
/// remove the others.
@internal
class RequestSpanRegistry {
  RequestSpanRegistry._();

  static final _spans = Expando<InstrumentationSpan>('sentry.request.span');

  /// [request] must be an object `Expando` accepts as a key, which excludes
  /// strings, numbers, booleans, records and `null`.
  static void register(Object request, InstrumentationSpan span) {
    _spans[request] = span;
  }

  static InstrumentationSpan? lookup(Object request) => _spans[request];
}
