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
  Future<StreamedResponse> send(BaseRequest request) async {
    final method = request.method;
    final headers = request.headers;
    final operation = _extractOperation(method, headers);
    if (operation == null) {
      return _client.send(request);
    }

    final span = _instrument(request, operation);

    final response = await _client.send(request);

    span.setData('http.response.status_code', response.statusCode);
    final status = SpanStatus.fromHttpStatusCode(response.statusCode);
    span.finish(status: status);

    return response;
  }

  ISentrySpan _instrument(BaseRequest request, Operation operation) {
    final url = request.url;
    final table = url.pathSegments.last;
    final description = 'from($table)';
    final query = _readQuery(request);
    final body = _readBody(table, request);

    // Breadcrumb

    if (_breadcrumbs) {
      final breadcrumb = Breadcrumb(
        message: description,
        category: 'db.${operation.value}',
        type: 'supabase',
      );
      if (query.isNotEmpty || body != null) {
        breadcrumb.data = {};
        if (query.isNotEmpty) {
          breadcrumb.data?['query'] = query;
        }
        if (body != null) {
          breadcrumb.data?['body'] = body;
        }
      }
      _hub.addBreadcrumb(breadcrumb);
    }

    // Tracing

    ISentrySpan span = NoOpSentrySpan();
    // ignore: invalid_use_of_internal_member
    if (_hub.options.isTracingEnabled()) {
      span = _hub.startTransaction(description, 'db.${operation.value}');

      final dbSchema = request.headers["Accept-Profile"] ??
          request.headers["Content-Profile"];
      if (dbSchema != null) {
        span.setData('db.schema', dbSchema);
      }
      span.setData('db.table', table);
      span.setData('db.url', url.origin);
      final dbSdk = request.headers["X-Client-Info"];
      if (dbSdk != null) {
        span.setData('db.sdk', dbSdk);
      }
      if (query.isNotEmpty) {
        span.setData('db.query', query);
      }
      if (body != null) {
        span.setData('db.body', body);
      }
      span.setData('op', 'db.${operation.value}');
      span.setData('origin', 'auto.db.supabase');
    }

    return span;
  }

  List<String> _readQuery(BaseRequest request) {
    return request.url.queryParametersAll.entries
        .expand(
          (entry) => entry.value.map(
            (value) => _translateFiltersIntoMethods(entry.key, value),
          ),
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
