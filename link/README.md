# Sentry Link (GraphQL)

[![pub package](https://img.shields.io/pub/v/sentry_link.svg)](https://pub.dev/packages/sentry_link) [![likes](https://img.shields.io/pub/likes/sentry_link)](https://pub.dev/packages/sentry_link/score) [![popularity](https://img.shields.io/pub/popularity/sentry_link)](https://pub.dev/packages/sentry_link/score) [![pub points](https://img.shields.io/pub/points/sentry_link)](https://pub.dev/packages/sentry_link/score)

## Compatibility list

This integration is compatible with the following packages. It's also compatible with other packages which are build on [`gql`](https://pub.dev/publishers/gql-dart.dev/packages) suite of packages.

| package | stats |
|---------|-------|
| [`gql_link`](https://pub.dev/packages/gql_link) | <a href="https://pub.dev/packages/graphql/score"><img src="https://img.shields.io/pub/likes/gql_link" alt="likes"></a> <a href="https://pub.dev/packages/gql_link/score"><img src="https://img.shields.io/pub/popularity/gql_link" alt="popularity"></a> <a href="https://pub.dev/packages/gql_link/score"><img src="https://img.shields.io/pub/points/gql_link" alt="pub points"></a> |
| [`graphql`](https://pub.dev/packages/graphql) | <a href="https://pub.dev/packages/graphql/score"><img src="https://img.shields.io/pub/likes/graphql" alt="likes"></a> <a href="https://pub.dev/packages/graphql/score"><img src="https://img.shields.io/pub/popularity/graphql" alt="popularity"></a> <a href="https://pub.dev/packages/graphql/score"><img src="https://img.shields.io/pub/points/graphql" alt="pub points"></a> |
| [`ferry`](https://pub.dev/packages/ferry) | <a href="https://pub.dev/packages/ferry/score"><img src="https://img.shields.io/pub/likes/ferry" alt="likes"></a> <a href="https://pub.dev/packages/ferry/score"><img src="https://img.shields.io/pub/popularity/ferry" alt="popularity"></a> <a href="https://pub.dev/packages/ferry/score"><img src="https://img.shields.io/pub/points/ferry" alt="pub points"></a> |
| [`artemis`](https://pub.dev/packages/artemis) | <a href="https://pub.dev/packages/artemis/score"><img src="https://img.shields.io/pub/likes/artemis" alt="likes"></a> <a href="https://pub.dev/packages/artemis/score"><img src="https://img.shields.io/pub/popularity/artemis" alt="popularity"></a> <a href="https://pub.dev/packages/artemis/score"><img src="https://img.shields.io/pub/points/artemis" alt="pub points"></a> |

## Usage

Just add `SentryGql.link()` to your links.
It will add error reporting and performance monitoring to your GraphQL operations.

```dart
final link = Link.from([
    AuthLink(getToken: () async => 'Bearer $personalAccessToken'),
    // SentryLink records exceptions
    SentryGql.link(
      shouldStartTransaction: true,
      graphQlErrorsMarkTransactionAsFailed: true,
    ),
    HttpLink('https://api.github.com/graphql'),
]);
```

A GraphQL errors will be reported as seen in the example below: 

Given the following query with an error

```graphql
query LoadPosts($id: ID!) {
  post(id: $id) {
    id
    # This word is intentionally misspelled to trigger a GraphQL error
    titl
    body
  }
}
```

it will be represented in Sentry as seen in the image

<img src="https://raw.githubusercontent.com/getsentry/sentry-dart/main/sentry_link/screenshot.png" />

## Improve exception reports for `LinkException`s

`LinkException`s and it subclasses can be arbitrary deeply nested. By adding an exception extractor for it, Sentry can create significantly improved exception reports.

```dart
Sentry.init((options) {
  options.addGqlExtractors();
});
```

## Performance traces for serialization and parsing

The [`SentryResponseParser`](https://pub.dev/documentation/sentry_link/latest/sentry_link/SentryResponseParser-class.html) and [`SentryRequestSerializer`](https://pub.dev/documentation/sentry_link/latest/sentry_link/SentryRequestSerializer-class.html) classes can be used to trace the de/serialization process. 
Both classes work with the [`HttpLink`](https://pub.dev/packages/gql_http_link) and the [`DioLink`](https://pub.dev/packages/gql_dio_link). 
When using the `HttpLink`, you can additionally use the `sentryResponseDecoder` function as explained further down below.

### Example for `HttpLink`

This example uses the [`http`](https://docs.sentry.io/platforms/dart/configuration/integrations/http-integration/#performance-monitoring-for-http-requests) integration in addition to this gql integration.

```dart
import 'package:sentry/sentry.dart';
import 'package:sentry_link/sentry_link.dart';

final link = Link.from([
    AuthLink(getToken: () async => 'Bearer $personalAccessToken'),
    SentryGql.link(
      shouldStartTransaction: true,
      graphQlErrorsMarkTransactionAsFailed: true,
    ),
    HttpLink(
      'https://api.github.com/graphql',
      httpClient: SentryHttpClient(),
      serializer: SentryRequestSerializer(),
      parser: SentryResponseParser(),
    ),
  ]);
```

### Example for `DioLink`

This example uses the [`sentry_dio`](https://pub.dev/packages/sentry_dio) integration in addition  to this gql integration.

```dart
import 'package:sentry_link/sentry_link.dart';
import 'package:sentry_dio/sentry_dio.dart';

final link = Link.from([
    AuthLink(getToken: () async => 'Bearer $personalAccessToken'),
    SentryGql.link(
      shouldStartTransaction: true,
      graphQlErrorsMarkTransactionAsFailed: true,
    ),
    DioLink(
      'https://api.github.com/graphql',
      client: Dio()..addSentry(),
      serializer: SentryRequestSerializer(),
      parser: SentryResponseParser(),
    ),
  ]);
```

<details>
  <summary>HttpLink</summary>

## Bonus `HttpLink` tracing

```dart
import 'dart:async';
import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:http/http.dart' as http;

import 'package:sentry_link/sentry_link.dart';

final link = Link.from([
  AuthLink(getToken: () async => 'Bearer $personalAccessToken'),
  SentryGql.link(
    shouldStartTransaction: true,
    graphQlErrorsMarkTransactionAsFailed: true,
  ),
  HttpLink(
    'https://api.github.com/graphql',
    httpClient: SentryHttpClient(networkTracing: true),
    serializer: SentryRequestSerializer(),
    parser: SentryResponseParser(),
    httpResponseDecoder: sentryResponseDecoder,
  ),
]);

Map<String, dynamic>? sentryResponseDecoder(
  http.Response response, {
  Hub? hub,
}) {
  final currentHub = hub ?? HubAdapter();
  final span = currentHub.getSpan()?.startChild(
        'serialize.http.client',
        description: 'http response deserialization',
      );
  Map<String, dynamic>? result;
  try {
    result = _defaultHttpResponseDecoder(response);
    span?.status = const SpanStatus.ok();
  } catch (e) {
    span?.status = const SpanStatus.unknownError();
    span?.throwable = e;
    rethrow;
  } finally {
    unawaited(span?.finish());
  }
  return result;
}

Map<String, dynamic>? _defaultHttpResponseDecoder(http.Response httpResponse) {
  return json.decode(utf8.decode(httpResponse.bodyBytes))
      as Map<String, dynamic>?;
}
```

</details>

## Filter redundant HTTP breadcrumbs

If you use the [`sentry_dio`](https://pub.dev/packages/sentry_dio) or [`http`](https://pub.dev/documentation/sentry/latest/sentry_io/SentryHttpClient-class.html) you will have breadcrumbs attached for every HTTP request. In order to not have duplicated breadcrumbs from the HTTP integrations and this GraphQL integration,
you should filter those breadcrumbs.

That can be achieved in two ways:

1. Disable all HTTP breadcrumbs.
2. Use [`beforeBreadcrumb`](https://pub.dev/documentation/sentry/latest/sentry_io/SentryOptions/beforeBreadcrumb.html).
  ```dart
  return Sentry.init(
    (options) {
      options.beforeBreadcrumb = graphQlFilter();
      // or 
      options.beforeBreadcrumb = graphQlFilter((breadcrumb, hint) {
        // custom filter
        return breadcrumb;
      });
    },
  );
  ```

## Additional `graphql` usage hints

<details>
  <summary>

Additional hints for usage with [`graphql`](https://pub.dev/packages/graphql)

  </summary>

```dart
import 'package:sentry/sentry.dart';
import 'package:sentry_link/sentry_link.dart';
import 'package:graphql/graphql.dart';

Sentry.init((options) {
  options.addExceptionCauseExtractor(UnknownExceptionExtractor());
  options.addExceptionCauseExtractor(NetworkExceptionExtractor());
  options.addExceptionCauseExtractor(CacheMissExceptionExtractor());
  options.addExceptionCauseExtractor(OperationExceptionExtractor());
  options.addExceptionCauseExtractor(CacheMisconfigurationExceptionExtractor());
  options.addExceptionCauseExtractor(MismatchedDataStructureExceptionExtractor());
  options.addExceptionCauseExtractor(UnexpectedResponseStructureExceptionExtractor());
});

class UnknownExceptionExtractor
    extends LinkExceptionExtractor<UnknownException> {}

class NetworkExceptionExtractor
    extends LinkExceptionExtractor<NetworkException> {}

class CacheMissExceptionExtractor
    extends LinkExceptionExtractor<CacheMissException> {}

class CacheMisconfigurationExceptionExtractor
    extends LinkExceptionExtractor<CacheMisconfigurationException> {}

class MismatchedDataStructureExceptionExtractor
    extends LinkExceptionExtractor<MismatchedDataStructureException> {}

class UnexpectedResponseStructureExceptionExtractor
    extends LinkExceptionExtractor<UnexpectedResponseStructureException> {}

class OperationExceptionExtractor extends ExceptionCauseExtractor<T> {
  @override
  ExceptionCause? cause(T error) {
    return ExceptionCause(error.linkException, error.originalStackTrace);
  }
}
```

</details>

# 📣 About the original author

- [![Twitter Follow](https://img.shields.io/twitter/follow/ue_man?style=social)](https://twitter.com/ue_man)
- [![GitHub followers](https://img.shields.io/github/followers/ueman?style=social)](https://github.com/ueman)
