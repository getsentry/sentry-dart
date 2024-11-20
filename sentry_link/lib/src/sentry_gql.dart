import 'package:gql_link/gql_link.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_link/src/sentry_breadcrumb_link.dart';
import 'package:sentry_link/src/sentry_link.dart';
import 'package:sentry_link/src/sentry_tracing_link.dart';

abstract class SentryGql {
  SentryGql._();

  // Provide a single Link, which is combines all the various links and makes
  // them configurable.
  /// If [shouldStartTransaction] is set to true, a [SentryTransaction]
  /// is automatically created for each GraphQL query/mutation.
  /// If a transaction is already bound to scope, no [SentryTransaction]
  /// will be started even if [shouldStartTransaction] is set to true.
  ///
  /// If [graphQlErrorsMarkTransactionAsFailed] is set to true and a
  /// query or mutation have a [GraphQLError] attached, the current
  /// [SentryTransaction] is marked as with [SpanStatus.unknownError].
  static Link link({
    bool enableBreadcrumbs = true,
    required bool shouldStartTransaction,
    required bool graphQlErrorsMarkTransactionAsFailed,
    bool reportExceptions = true,
    bool reportExceptionsAsBreadcrumbs = false,
    bool reportGraphQlErrors = true,
    bool reportGraphQlErrorsAsBreadcrumbs = false,
  }) {
    return Link.from([
      SentryLink.link(
        reportExceptions: reportExceptions,
        reportExceptionsAsBreadcrumbs: reportExceptionsAsBreadcrumbs,
        reportGraphQlErrors: reportGraphQlErrors,
        reportGraphQlErrorsAsBreadcrumbs: reportExceptionsAsBreadcrumbs,
      ),
      if (enableBreadcrumbs) SentryBreadcrumbLink(),
      if (shouldStartTransaction != false &&
          graphQlErrorsMarkTransactionAsFailed != false)
        SentryTracingLink(
          graphQlErrorsMarkTransactionAsFailed:
              graphQlErrorsMarkTransactionAsFailed,
          shouldStartTransaction: shouldStartTransaction,
        ),
    ]);
  }
}
