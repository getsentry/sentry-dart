import 'package:http/http.dart';
import 'operation.dart';
import 'package:sentry/sentry.dart';

class SentrySupabaseClient extends BaseClient {
  final Client _client;
  final Hub _hub;
  
  SentrySupabaseClient({Client? client, Hub? hub}) : 
    _client = client ?? Client(),
    _hub = hub ?? HubAdapter();
  
  @override
  Future<StreamedResponse> send(BaseRequest request) {
    final url = request.url;
    final method = request.method;
    final headers = request.headers;

    final table = url.pathSegments.last;
    final description = 'from($table)';
    final operation = extractOperation(method, headers);

    if (operation != null) {
      _addBreadcrumb(description, operation: operation);
    }

    return _client.send(request);
  }

  void _addBreadcrumb(String description, {required Operation operation}) {
    final breadcrumb = Breadcrumb(
      message: description,
      category: 'db.${operation.value}',
      type: 'supabase',
    );
    _hub.addBreadcrumb(breadcrumb);
  }

  Operation? extractOperation(String method, Map<String, String> headers) {
    switch (method) {
      case "GET":
        {
          return Operation.select;
        }
      case "POST":
        {
          if (headers["Prefer"]?.contains("resolution=") ?? false) {
            return Operation.upsert;
          } else {
            return Operation.insert;
          }
        }
      case "PATCH":
        {
          return Operation.update;
        }
      case "DELETE":
        {
          return Operation.delete;
        }
      default:
        {
          return null;
        }
    }
  }
}
