import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

import 'sentry_supabase_breadcrumb_client.dart';
import 'sentry_supabase_tracing_client.dart';
import 'sentry_supabase_error_client.dart';

/// A [http](https://pub.dev/packages/http)-package compatible HTTP client that
/// instruments requests to Supabase.
///
/// It adds breadcrumbs, tracing and error capturing per default.
///
/// ```dart
/// import 'package:sentry/sentry.dart';
/// import 'package:sentry_supabase/sentry_supabase.dart';
///
/// var supabase = SupabaseClient(
///   'https://example.com',
///   SentrySupabaseClient();
/// );
/// ```
///
/// You can disable any of the features by setting the `breadcrumbs`, `tracing`
/// or `errors` parameters to `false`.
///
/// ```dart
/// var supabase = SupabaseClient(
///   'https://example.com',
///   SentrySupabaseClient(
///     enableBreadcrumbs: false,
///     enableTracing: false,
///     enableErrors: true,
///   ),
/// );
/// ```
///
/// You can also pass a custom [Client] to the constructor, just like you'd
/// pass it to the [SupabaseClient] constructor.
///
/// ```dart
/// var supabase = SupabaseClient(
///   'https://example.com',
///   SentrySupabaseClient(client: CustomClient()),
/// );
/// ```
///
/// Body data will not be sent by default. You can enable it by setting the
/// `sendDefaultPii` option in the [SentryOptions].
class SentrySupabaseClient extends BaseClient {
  final bool _enableBreadcrumbs;
  final bool _enableTracing;
  final bool _enableErrors;

  Client _innerClient;
  final Hub _hub;

  SentrySupabaseClient({
    bool enableBreadcrumbs = true,
    bool enableTracing = true,
    bool enableErrors = true,
    Client? client,
    Hub? hub,
  })  : _enableBreadcrumbs = enableBreadcrumbs,
        _enableTracing = enableTracing,
        _enableErrors = enableErrors,
        _hub = hub ?? HubAdapter(),
        _innerClient = client ?? Client() {
    // Wrap the client with the appropriate layers during construction
    if (_enableBreadcrumbs) {
      _innerClient = SentrySupabaseBreadcrumbClient(_innerClient, _hub);
    }
    if (_enableTracing) {
      _innerClient = SentrySupabaseTracingClient(_innerClient, _hub);
    }
    if (_enableErrors) {
      _innerClient = SentrySupabaseErrorClient(_innerClient, _hub);
    }
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    return _innerClient.send(request);
  }

  @override
  void close() {
    _innerClient.close();
  }
}
