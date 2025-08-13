import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

import 'sentry_supabase_request.dart';

class SentrySupabaseBreadcrumbClient extends BaseClient {
  final Client _innerClient;
  final Hub _hub;

  SentrySupabaseBreadcrumbClient(this._innerClient, this._hub);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final supabaseRequest = SentrySupabaseRequest.fromRequest(
      request,
      // ignore: invalid_use_of_internal_member
      options: _hub.options,
    );

    if (supabaseRequest == null) {
      return _innerClient.send(request);
    }

    final breadcrumb = Breadcrumb(
      message: 'from(${supabaseRequest.table})',
      category: 'db.${supabaseRequest.operation.value}',
      type: 'supabase',
    );

    breadcrumb.data ??= {};

    breadcrumb.data?['table'] = supabaseRequest.table;
    breadcrumb.data?['operation'] = supabaseRequest.operation.value;

    // ignore: invalid_use_of_internal_member
    if (supabaseRequest.query.isNotEmpty && _hub.options.sendDefaultPii) {
      breadcrumb.data?['query'] = supabaseRequest.query;
    }

    // ignore: invalid_use_of_internal_member
    if (supabaseRequest.body != null && _hub.options.sendDefaultPii) {
      breadcrumb.data?['body'] = supabaseRequest.body;
    }

    await _hub.addBreadcrumb(breadcrumb);

    return _innerClient.send(request);
  }

  @override
  void close() {
    _innerClient.close();
  }
}
