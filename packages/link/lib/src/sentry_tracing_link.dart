import 'dart:async';

import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_link/src/extension.dart';

class SentryTracingLink extends Link {
  /// If [shouldStartTransaction] is set to true, a [SentryTransaction]
  /// is automatically created for each GraphQL query/mutation.
  /// If a transaction is already bound to scope, no [SentryTransaction]
  /// will be started even if [shouldStartTransaction] is set to true.
  ///
  /// If [graphQlErrorsMarkTransactionAsFailed] is set to true and a
  /// query or mutation have a [GraphQLError] attached, the current
  /// [SentryTransaction] is marked as with [SpanStatus.unknownError].
  SentryTracingLink({
    required this.shouldStartTransaction,
    required this.graphQlErrorsMarkTransactionAsFailed,
    Hub? hub,
  }) : _hub = hub ?? HubAdapter();

  final Hub _hub;

  /// If [shouldStartTransaction] is set to true, a [SentryTransaction]
  /// is automatically created for each GraphQL query/mutation.
  /// If a transaction is already bound to scope, no [SentryTransaction]
  /// will be started even if [shouldStartTransaction] is set to true.
  final bool shouldStartTransaction;

  /// If [graphQlErrorsMarkTransactionAsFailed] is set to true and a
  /// query or mutation have a [GraphQLError] attached, the current
  /// [SentryTransaction] is marked as with [SpanStatus.unknownError].
  final bool graphQlErrorsMarkTransactionAsFailed;

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    assert(
      forward != null,
      'This is not a terminating link and needs a NextLink',
    );

    final operationType = request.operation.getOperationType();
    final sentryOperation = operationType?.sentryOperation ?? 'unknown';
    final sentryType = operationType?.sentryType;

    final transaction = _startSpan(
      'GraphQL: "${request.operation.operationName ?? 'unnamed'}" $sentryType',
      sentryOperation,
      shouldStartTransaction,
    );
    return forward!(request).transform(StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        final hasGraphQlError = data.errors?.isNotEmpty ?? false;
        if (graphQlErrorsMarkTransactionAsFailed && hasGraphQlError) {
          transaction?.finish(status: const SpanStatus.unknownError());
        } else {
          transaction?.finish(status: const SpanStatus.ok());
        }

        sink.add(data);
      },
      handleError: (error, stackTrace, sink) {
        // Error handling can be significantly improved after
        // https://github.com/gql-dart/gql/issues/361
        // is done.
        // The correct `SpanStatus` can be set on
        // `HttpLinkResponseContext.statusCode` or
        // `DioLinkResponseContext.statusCode`
        transaction?.throwable = error;
        unawaited(transaction?.finish(status: const SpanStatus.unknownError()));

        sink.addError(error, stackTrace);
      },
    ));
  }

  ISentrySpan? _startSpan(
    String op,
    String description,
    bool shouldStartTransaction,
  ) {
    final span = _hub.getSpan();
    if (span == null && shouldStartTransaction) {
      return _hub.startTransaction(description, op, bindToScope: true);
    } else if (span != null) {
      return span.startChild(op, description: description);
    }
    return null;
  }
}
