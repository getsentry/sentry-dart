// ignore_for_file: invalid_use_of_internal_member

import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

import 'constants.dart';
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
/// pass it to the SupabaseClient constructor.
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
  final Client _innerClient;

  SentrySupabaseClient({
    bool enableBreadcrumbs = true,
    bool enableTracing = true,
    bool enableErrors = true,
    Client? client,
    Hub? hub,
  }) : _innerClient = _buildWrappedClient(
          client ?? Client(),
          enableBreadcrumbs,
          enableTracing,
          enableErrors,
          hub ?? HubAdapter(),
        );

  static Client _buildWrappedClient(
    Client baseClient,
    bool enableBreadcrumbs,
    bool enableTracing,
    bool enableErrors,
    Hub hub,
  ) {
    Client wrappedClient = baseClient;

    if (enableBreadcrumbs) {
      wrappedClient = SentrySupabaseBreadcrumbClient(wrappedClient, hub);
      hub.options.sdk.addIntegration(integrationNameBreadcrumbs);
    }
    if (enableTracing) {
      wrappedClient = SentrySupabaseTracingClient(wrappedClient, hub);
      hub.options.sdk.addIntegration(integrationNameTracing);
    }
    if (enableErrors) {
      wrappedClient = SentrySupabaseErrorClient(wrappedClient, hub);
      hub.options.sdk.addIntegration(integrationNameErrors);
    }

    return wrappedClient;
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
