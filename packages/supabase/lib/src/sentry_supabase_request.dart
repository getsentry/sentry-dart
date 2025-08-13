import 'dart:convert';
import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

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

  static SentrySupabaseRequest? fromRequest(
    BaseRequest request, {
    required SentryOptions options,
  }) {
    final url = request.url;
    // Ignoring URLS like https://example.com/auth/v1/token?grant_type=password
    // Only consider requests to the REST API.
    if (!url.path.startsWith('/rest/v1')) {
      return null;
    }

    // Validate that the URL contains at least three path segments (rest, v1, table)
    // to ensure we have a valid table name
    if (url.pathSegments.length < 3) {
      return null;
    }

    // The table name is the third segment (index 2) after 'rest' and 'v1'
    // For URLs like /rest/v1/users/123, the table name is 'users', not '123'
    final table = url.pathSegments[2];

    // Ensure the table name is not empty (e.g., /rest/v1/ would have empty third segment)
    if (table.isEmpty) {
      return null;
    }
    final operation = _extractOperation(request.method, request.headers);
    final query = _readQuery(request);
    try {
      final body = _readBody(table, request, options: options);
      return SentrySupabaseRequest(
        request: request,
        table: table,
        operation: operation,
        query: query,
        body: body,
      );
    } catch (e) {
      return null;
    }
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

  static Map<String, dynamic>? _readBody(
    String table,
    BaseRequest request, {
    required SentryOptions options,
  }) {
    final bodyString =
        request is Request && request.body.isNotEmpty ? request.body : null;

    if (bodyString == null) {
      return null;
    }

    // Check if we should include the body based on PII settings and size limits
    if (!options.sendDefaultPii ||
        !options.maxRequestBodySize.shouldAddBody(bodyString.length)) {
      return null;
    }

    final body = jsonDecode(bodyString);
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

  /// Generates a SQL query representation for debugging and tracing purposes
  String generateSqlQuery() {
    final body = this.body;
    switch (operation) {
      case Operation.select:
        return 'SELECT * FROM "$table"';
      case Operation.insert:
      case Operation.upsert:
        if (body != null && body.isNotEmpty) {
          final columns = body.keys.map((k) => '"$k"').join(', ');
          final placeholders = body.keys.map((_) => '?').join(', ');
          return 'INSERT INTO "$table" ($columns) VALUES ($placeholders)';
        } else {
          return 'INSERT INTO "$table" VALUES (?)';
        }
      case Operation.update:
        final setClause = body != null && body.isNotEmpty
            ? body.keys.map((k) => '"$k" = ?').join(', ')
            : '?';
        final whereClause = _buildWhereClause();
        return 'UPDATE "$table" SET $setClause${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}';
      case Operation.delete:
        final whereClause = _buildWhereClause();
        return 'DELETE FROM "$table"${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}';
      case Operation.unknown:
        return 'UNKNOWN OPERATION ON "$table"';
    }
  }

  /// Builds WHERE clause from query parameters for SQL representation
  String _buildWhereClause() {
    final conditions = <String>[];

    // Get original query parameters to help with NOT conditions
    final originalParams = request.url.queryParameters;

    for (final queryItem in query) {
      // Skip select queries
      if (queryItem.startsWith('select(')) continue;

      // Handle OR conditions - e.g., orstatus.eq.inactive or or(id.eq.8)
      if (queryItem.startsWith('or')) {
        String orCondition;
        if (queryItem.startsWith('or(') && queryItem.endsWith(')')) {
          // Format: or(id.eq.8)
          orCondition = queryItem.substring(3, queryItem.length - 1);
        } else if (queryItem.contains('.')) {
          // Format: orstatus.eq.inactive
          orCondition = queryItem.substring(2);
        } else {
          continue;
        }

        final orParts = orCondition.split('.');
        if (orParts.length >= 3) {
          final column = orParts[0];
          final operator = orParts[1];
          final operatorSql = _getOperatorSql(operator);
          conditions.add('OR $column $operatorSql ?');
        } else {
          conditions.add('OR $orCondition = ?');
        }
        continue;
      }

      // Handle NOT conditions via filter - e.g., filter(not, eq.deleted)
      if (queryItem.startsWith('filter(not,')) {
        // Find the NOT parameter in original query
        final notParam = originalParams.entries.firstWhere(
          (entry) => entry.key == 'not',
          orElse: () => const MapEntry('not', 'unknown.eq.value'),
        );

        if (notParam.value.contains('.eq.')) {
          final parts = notParam.value.split('.eq.');
          if (parts.isNotEmpty) {
            final column = parts[0];
            conditions.add('$column != ?');
          }
        }
        continue;
      }

      // Handle regular conditions - e.g., eq(id, 42), gt(age, 18), in(status, (active,pending))
      if (queryItem.contains('(') && queryItem.contains(')')) {
        final match =
            RegExp(r'^(\w+)\(([^,]+),\s*(.+)\)$').firstMatch(queryItem);
        if (match != null) {
          final operation = match.group(1);
          final column = match.group(2);
          if (operation != null && column != null) {
            final operatorSql = _getOperatorSql(operation);
            conditions.add('$column $operatorSql ?');
          }
        }
      }
    }

    return conditions.join(' AND ').replaceAll(' AND OR ', ' OR ');
  }

  /// Maps filter operations to SQL operators
  /// This is a subset of the operations supported by Supabase.
  /// See https://supabase.com/docs/reference/dart/select#filter-operators
  String _getOperatorSql(String operation) {
    switch (operation) {
      case 'eq':
        return '=';
      case 'neq':
        return '!=';
      case 'gt':
        return '>';
      case 'gte':
        return '>=';
      case 'lt':
        return '<';
      case 'lte':
        return '<=';
      case 'like':
        return 'LIKE';
      case 'ilike':
        return 'ILIKE';
      case 'in':
        return 'IN';
      default:
        return '=';
    }
  }
}
