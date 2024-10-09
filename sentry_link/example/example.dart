import 'dart:io';

import 'package:graphql/client.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_link/sentry_link.dart';

Future<void> main() {
  return Sentry.init(
    (options) {
      options.dsn = 'sentry_dsn';
      options.tracesSampleRate = 1;
      options.beforeBreadcrumb = graphQlFilter();
      options.addGqlExtractors();
      options.addSentryLinkInAppExcludes();
    },
    appRunner: example,
  );
}

Future<void> example() async {
  final link = Link.from([
    SentryGql.link(
      shouldStartTransaction: true,
      graphQlErrorsMarkTransactionAsFailed: true,
    ),
    HttpLink(
      'https://graphqlzero.almansi.me/api',
      httpClient: SentryHttpClient(),
      parser: SentryResponseParser(),
      serializer: SentryRequestSerializer(),
    ),
  ]);

  final client = GraphQLClient(
    cache: GraphQLCache(),
    link: link,
  );

  final QueryOptions options = QueryOptions(
    operationName: 'LoadPosts',
    document: gql(
      r'''
        query LoadPosts($id: ID!) {
          post(id: $id) {
            id
            # this one is intentionally wrong, the last char 'e' is missing
            titl
            body
          }
        }
      ''',
    ),
    variables: {
      'id': 50,
    },
  );

  final result = await client.query(options);
  print(result.toString());
  await Future<void>.delayed(Duration(seconds: 2));
  exit(0);
}
