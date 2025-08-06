import 'dart:async';

import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_link/src/sentry_link.dart';
import 'package:sentry_link/src/extension.dart';

/// Only handles success cases. Error cases are handled by [SentryLink].
class SentryBreadcrumbLink extends Link {
  /// Adds breadcrumbs for GraphQL operations
  SentryBreadcrumbLink({Hub? hub}) : _hub = hub ?? HubAdapter();

  final Hub _hub;

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    assert(
      forward != null,
      'This is not a terminating link and needs a NextLink',
    );

    final operationType = request.operation.getOperationType()?.sentryType;
    final description =
        'GraphQL: "${request.operation.operationName ?? 'unnamed'}" $operationType';

    final stopwatch = Stopwatch()..start();

    return forward!(request).transform(StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        stopwatch.stop();
        // Errors are handled by SentryLink, so opt-out if there are errors.
        if (data.errors == null) {
          _addBreadcrumb(description, stopwatch.elapsed, data);
        }
        sink.add(data);
      },
      handleError: (error, stackTrace, sink) {
        // Error handling can be significantly improved after
        // https://github.com/gql-dart/gql/issues/361
        // is done.
        stopwatch.stop();
        sink.addError(error, stackTrace);
      },
    ));
  }

  void _addBreadcrumb(
    String description,
    Duration duration,
    Response response,
  ) {
    _hub.addBreadcrumb(Breadcrumb(
      category: 'GraphQL',
      message: description,
      type: 'query',
      data: {'duration': duration.toString()},
    ));
  }
}
