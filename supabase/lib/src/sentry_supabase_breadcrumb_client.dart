import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

import 'sentry_supabase_request.dart';

class SentrySupabaseBreadcrumbClient extends BaseClient {
  final Client _innerClient;
  final Hub _hub;

  SentrySupabaseBreadcrumbClient(this._innerClient, this._hub);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final supabaseRequest = SentrySupabaseRequest.fromRequest(request);

    final breadcrumb = Breadcrumb(
      message: 'from(${supabaseRequest.table})',
      category: 'db.${supabaseRequest.operation.value}',
      type: 'supabase',
    );

    breadcrumb.data ??= {};

    breadcrumb.data?['table'] = supabaseRequest.table;
    breadcrumb.data?['operation'] = supabaseRequest.operation.value;

    if (supabaseRequest.query.isNotEmpty) {
      breadcrumb.data?['query'] = supabaseRequest.query;
    }
    if (supabaseRequest.body != null) {
      breadcrumb.data?['body'] = supabaseRequest.body;
    }

    _hub.addBreadcrumb(breadcrumb);

    return _innerClient.send(request);
  }

  @override
  void close() {
    _innerClient.close();
  }
}
