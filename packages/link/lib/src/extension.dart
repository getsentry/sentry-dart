import 'dart:convert';

import 'package:gql/ast.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:sentry/sentry.dart';
import 'package:gql/language.dart' show printNode;

/// Extension for [GraphQLError]
extension SentryGraphQLErrorExtension on GraphQLError {
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'locations':
          locations?.map((e) => {'line': e.line, 'column': e.column}).toList(),
      'paths': path?.map((e) => e.toString()).toList(),
      'extensions': extensions,
    };
  }
}

/// Extension for [Request]
extension SentryRequestExtension on Request {
  Map<String, dynamic> toJson() {
    return {
      'operation': operation.toJson(),
      'variables': variables,
    };
  }

  SentryRequest toSentryRequest() {
    return SentryRequest(
      apiTarget: 'graphql',
      data: {
        'query': printNode(operation.document),
        'variables': variables,
        'operationName': operation.operationName
      },
    );
  }
}

/// Extension for [Response]
extension SentryResponseExtension on Response {
  Map<String, dynamic> toJson() {
    return {
      'errors': errors?.map((e) => e.toJson()).toList(),
      'data': data,
    };
  }

  SentryResponse toSentryResponse(int? statusCode) {
    return SentryResponse(
      statusCode: statusCode,
      data: {
        'errors': errors?.map((e) => e.toJson()).toList(),
        'data': data,
      },
    );
  }
}

/// Extension for [Operation]
extension SentryOperationExtension on Operation {
  Map<String, dynamic> toJson() {
    return {
      'name': operationName,
      'document': json.encode(printNode(document)),
    };
  }
}

/// Extension for [OperationType]
extension SentryOperationTypeExtension on OperationType {
  /// See https://develop.sentry.dev/sdk/performance/span-operations/
  String get sentryOperation {
    return switch (this) {
      OperationType.query => 'http.graphql.query',
      OperationType.mutation => 'http.graphql.mutation',
      OperationType.subscription => 'http.graphql.subscription',
    };
  }

  String get sentryType {
    return switch (this) {
      OperationType.query => 'query',
      OperationType.mutation => 'mutation',
      OperationType.subscription => 'subscription',
    };
  }

  String get name {
    return switch (this) {
      OperationType.query => 'query',
      OperationType.mutation => 'mutation',
      OperationType.subscription => 'subscription',
    };
  }
}

/// Extension for [SentryOptions]
extension InAppExclueds on SentryOptions {
  /// Sets this library as not in-app frames, to improve stack trace
  /// presentation in Sentry.
  void addSentryLinkInAppExcludes() {
    addInAppExclude('sentry_link');
  }
}
