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
///     breadcrumbs: false,
///     tracing: false,
///     errors: true,
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
class SentrySupabaseClient extends BaseClient {
  final bool _breadcrumbs;
  final bool _tracing;
  final bool _errors;

  Client _innerClient;
  final Hub _hub;

  SentrySupabaseClient({
    bool breadcrumbs = true,
    bool tracing = true,
    bool errors = true,
    Client? client,
    Hub? hub,
  })  : _breadcrumbs = breadcrumbs,
        _tracing = tracing,
        _errors = errors,
        _innerClient = client ?? Client(),
        _hub = hub ?? HubAdapter();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (_breadcrumbs) {
      _innerClient = SentrySupabaseBreadcrumbClient(_innerClient, _hub);
    }
    if (_tracing) {
      _innerClient = SentrySupabaseTracingClient(_innerClient, _hub);
    }
    if (_errors) {
      _innerClient = SentrySupabaseErrorClient(_innerClient, _hub);
    }
    return _innerClient.send(request);
  }

  @override
  void close() {
    _innerClient.close();
  }
}
