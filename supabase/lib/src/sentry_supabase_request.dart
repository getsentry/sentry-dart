import 'dart:convert';
import 'package:http/http.dart';

import 'operation.dart';

/// Concepts based on https://github.com/supabase-community/sentry-integration-js
class SentrySupabaseRequest {
  final BaseRequest request;

  final String table;
  final Operation operation;
  final List<String> query;
  final Map<String, dynamic>? body;

  SentrySupabaseRequest({
    required this.request,
    required this.table,
    required this.operation,
    required this.query,
    required this.body,
  });

  factory SentrySupabaseRequest.fromRequest(BaseRequest request) {
    final url = request.url;
    final table = url.pathSegments.last;
    final operation = _extractOperation(request.method, request.headers);
    final query = _readQuery(request);
    final body = _readBody(table, request);

    return SentrySupabaseRequest(
      request: request,
      table: table,
      operation: operation,
      query: query,
      body: body,
    );
  }

  static Operation _extractOperation(
    String method,
    Map<String, String> headers,
  ) {
    switch (method) {
      case 'GET':
        return Operation.select;
      case 'POST':
        if (headers['Prefer']?.contains('resolution=') ?? false) {
          return Operation.upsert;
        } else {
          return Operation.insert;
        }
      case 'PATCH':
        return Operation.update;
      case 'DELETE':
        return Operation.delete;
      default:
        return Operation.unknown; // Should never happen.
    }
  }

  static List<String> _readQuery(BaseRequest request) {
    return request.url.queryParametersAll.entries
        .expand(
          (entry) => entry.value.map(
            (value) => _translateFiltersIntoMethods(entry.key, value),
          ),
        )
        .toList();
  }

  static Map<String, dynamic>? _readBody(String table, BaseRequest request) {
    final bodyString =
        request is Request && request.body.isNotEmpty ? request.body : null;
    final body = bodyString != null ? jsonDecode(bodyString) : null;

    if (body is Map<String, dynamic>) {
      return body;
    } else {
      return null;
    }
  }

  static const Map<String, String> _filterMappings = {
    'eq': 'eq',
    'neq': 'neq',
    'gt': 'gt',
    'gte': 'gte',
    'lt': 'lt',
    'lte': 'lte',
    'like': 'like',
    'like(all)': 'likeAllOf',
    'like(any)': 'likeAnyOf',
    'ilike': 'ilike',
    'ilike(all)': 'ilikeAllOf',
    'ilike(any)': 'ilikeAnyOf',
    'is': 'is',
    'in': 'in',
    'cs': 'contains',
    'cd': 'containedBy',
    'sr': 'rangeGt',
    'nxl': 'rangeGte',
    'sl': 'rangeLt',
    'nxr': 'rangeLte',
    'adj': 'rangeAdjacent',
    'ov': 'overlaps',
    'fts': '',
    'plfts': 'plain',
    'phfts': 'phrase',
    'wfts': 'websearch',
    'not': 'not',
  };

  static String _translateFiltersIntoMethods(String key, String query) {
    if (query.isEmpty || query == '*') {
      return 'select(*)';
    }

    if (key == 'select') {
      return 'select($query)';
    }

    if (key == 'or' || key.endsWith('.or')) {
      return '$key$query';
    }

    final parts = query.split('.');
    final filter = parts[0];
    final value = parts.sublist(1).join('.');

    String method;
    // Handle optional `configPart` of the filter
    if (filter.startsWith('fts')) {
      method = 'textSearch';
    } else if (filter.startsWith('plfts')) {
      method = 'textSearch[plain]';
    } else if (filter.startsWith('phfts')) {
      method = 'textSearch[phrase]';
    } else if (filter.startsWith('wfts')) {
      method = 'textSearch[websearch]';
    } else {
      method = _filterMappings[filter] ?? 'filter';
    }
    return '$method($key, $value)';
  }
}
