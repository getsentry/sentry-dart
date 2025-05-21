import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

import 'sentry_supabase_breadcrumb_client.dart';
import 'sentry_supabase_tracing_client.dart';
import 'sentry_supabase_error_client.dart';

class SentrySupabaseClient extends BaseClient {
  final bool _breadcrumbs;
  final bool _tracing;
  final bool _errors;

  Client _innerClient;
  final Hub _hub;

  SentrySupabaseClient({
    required bool breadcrumbs,
    required bool tracing,
    required bool errors,
    required Client client,
    Hub? hub,
  })  : _breadcrumbs = breadcrumbs,
        _tracing = tracing,
        _errors = errors,
        _innerClient = client,
        _hub = hub ?? HubAdapter();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (_breadcrumbs) {
      _innerClient = SentrySupabaseBreadcrumbClient(
        _innerClient,
        _hub,
      );
    }
    if (_tracing) {
      _innerClient = SentrySupabaseTracingClient(
        _innerClient,
        _hub,
      );
    }
    if (_errors) {
      _innerClient = SentrySupabaseErrorClient(
        _innerClient,
        _hub,
      );
    }
    return _innerClient.send(request);
  }

  @override
  void close() {
    _innerClient.close();
  }
}
