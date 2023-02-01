// ignore_for_file: strict_raw_type

import 'dart:typed_data';

import 'package:diox/diox.dart';
import 'package:diox/io.dart';
import 'package:sentry/sentry.dart';
import 'tracing_client_adapter.dart';
import 'breadcrumb_client_adapter.dart';

/// A [Diox](https://pub.dev/packages/diox)-package compatible HTTP client adapter.
///
/// It records requests as breadcrumbs. This is on by default.
///
/// It starts and finishes a Span if there's a transaction bound to the Scope
/// through the [TracingClientAdapter] client, it's on by default.
///
/// Remarks: If this client is used as a wrapper, a call to close also closes
/// the given client.
///
/// Remarks:
/// HTTP traffic can contain PII (personal identifiable information).
/// Read more on data scrubbing [here](https://docs.sentry.io/product/data-management-settings/advanced-datascrubbing/).
class SentryDioxClientAdapter extends IOHttpClientAdapter {
  // ignore: public_member_api_docs
  SentryDioxClientAdapter({
    required HttpClientAdapter client,
    Hub? hub,
    bool recordBreadcrumbs = true,
    bool networkTracing = true,
  }) {
    _hub = hub ?? HubAdapter();

    var innerClient = client;

    if (networkTracing) {
      innerClient = TracingClientAdapter(client: innerClient, hub: _hub);
      // ignore: invalid_use_of_internal_member
      _hub.options.sdk.addIntegration('DioxNetworkTracing');
    }

    // The ordering here matters.
    // We don't want to include the breadcrumbs for the current request
    // when capturing it as a failed request.
    // However it still should be added for following events.
    if (recordBreadcrumbs) {
      innerClient = BreadcrumbClientAdapter(client: innerClient, hub: _hub);
    }

    _client = innerClient;
  }

  late HttpClientAdapter _client;
  late Hub _hub;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) =>
      _client.fetch(options, requestStream, cancelFuture);

  @override
  void close({bool force = false}) => _client.close(force: force);
}
