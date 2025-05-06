import 'package:http/http.dart';
import 'operation.dart';
import 'package:sentry/sentry.dart';
import 'dart:convert';

typedef SentrySupabaseRedactRequestBody = String? Function(
  String table,
  String key,
  String value,
);

class SentrySupabaseClient extends BaseClient {
  final bool _breadcrumbs;
  final SentrySupabaseRedactRequestBody? _redactRequestBody;
  final Client _client;
  final Hub _hub;

  static const Map<String, String> filterMappings = {
    "eq": "eq",
    "neq": "neq",
    "gt": "gt",
    "gte": "gte",
    "lt": "lt",
    "lte": "lte",
    "like": "like",
    "like(all)": "likeAllOf",
    "like(any)": "likeAnyOf",
    "ilike": "ilike",
    "ilike(all)": "ilikeAllOf",
    "ilike(any)": "ilikeAnyOf",
    "is": "is",
    "in": "in",
    "cs": "contains",
    "cd": "containedBy",
    "sr": "rangeGt",
    "nxl": "rangeGte",
    "sl": "rangeLt",
    "nxr": "rangeLte",
    "adj": "rangeAdjacent",
    "ov": "overlaps",
    "fts": "",
    "plfts": "plain",
    "phfts": "phrase",
    "wfts": "websearch",
    "not": "not",
  };

  SentrySupabaseClient({
    required bool breadcrumbs,
    SentrySupabaseRedactRequestBody? redactRequestBody,
    Client? client,
    Hub? hub,
  })  : _breadcrumbs = breadcrumbs,
        _redactRequestBody = redactRequestBody,
        _client = client ?? Client(),
        _hub = hub ?? HubAdapter();

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    final method = request.method;
    final headers = request.headers;
    final operation = _extractOperation(method, headers);

    if (operation != null) {
      _instrument(request, operation);
    }

    return _client.send(request);
  }

  void _instrument(BaseRequest request, Operation operation) {
    final url = request.url;
    final table = url.pathSegments.last;
    final description = 'from($table)';
    final query = _readQuery(request);
    final body = _readBody(table, request);

    if (_breadcrumbs) {
      _addBreadcrumb(description, operation, query, body);
    }
  }

  List<String> _readQuery(BaseRequest request) {
    return request.url.queryParameters.entries
        .map(
          (entry) => _translateFiltersIntoMethods(entry.key, entry.value),
        )
        .toList();
  }

  Map<String, dynamic>? _readBody(String table, BaseRequest request) {
    final bodyString =
        request is Request && request.body.isNotEmpty ? request.body : null;
    var body = bodyString != null ? jsonDecode(bodyString) : null;

    if (body != null && _redactRequestBody != null) {
      for (final entry in body.entries) {
        body[entry.key] = _redactRequestBody(table, entry.key, entry.value);
      }
    }
    return body;
  }

  void _addBreadcrumb(
    String description,
    Operation operation,
    List<String> query,
    Map<String, dynamic>? body,
  ) {
    final breadcrumb = Breadcrumb(
      message: description,
      category: 'db.${operation.value}',
      type: 'supabase',
    );

    if (query.isNotEmpty || body != null) {
      breadcrumb.data = {};
    }

    if (query.isNotEmpty) {
      breadcrumb.data?['query'] = query;
    }

    if (body != null) {
      breadcrumb.data?['body'] = body;
    }

    _hub.addBreadcrumb(breadcrumb);
  }

  Operation? _extractOperation(String method, Map<String, String> headers) {
    switch (method) {
      case "GET":
        return Operation.select;
      case "POST":
        if (headers["Prefer"]?.contains("resolution=") ?? false) {
          return Operation.upsert;
        } else {
          return Operation.insert;
        }
      case "PATCH":
        return Operation.update;
      case "DELETE":
        return Operation.delete;
      default:
        return null;
    }
  }

  String _translateFiltersIntoMethods(String key, String query) {
    if (query.isEmpty || query == "*") {
      return "select(*)";
    }

    if (key == "select") {
      return "select($query)";
    }

    if (key == "or" || key.endsWith(".or")) {
      return "$key$query";
    }

    final parts = query.split(".");
    final filter = parts[0];
    final value = parts.sublist(1).join(".");

    String method;
    // Handle optional `configPart` of the filter
    if (filter.startsWith("fts")) {
      method = "textSearch";
    } else if (filter.startsWith("plfts")) {
      method = "textSearch[plain]";
    } else if (filter.startsWith("phfts")) {
      method = "textSearch[phrase]";
    } else if (filter.startsWith("wfts")) {
      method = "textSearch[websearch]";
    } else {
      method = filterMappings[filter] ?? "filter";
    }

    return "$method($key, $value)";
  }
}
