// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:gql/language.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/tracing/instrumentation/span_factory_integration.dart';
import 'package:sentry_link/src/sentry_tracing_link.dart';
import 'package:test/test.dart';

void main() {
  group('Link SpanV2 Integration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('GraphQL query creates spanv2', () async {
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      final link = fixture.createSentryTracingLink();
      final request = Request(
        operation: Operation(
          document: parseString('query GetUser { user(id: "1") { name } }'),
          operationName: 'GetUser',
        ),
      );

      await link.request(request).first;

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('http.graphql.query');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value,
          equals('http.graphql.query'));
      expect(span.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
          equals('auto.graphql.sentry_link'));

      expect(span.parentSpan, equals(transactionSpan));
      expect(span.traceId, equals(transactionSpan.traceId));
      expect(span.spanId, isNot(equals(transactionSpan.spanId)));
    });

    test('GraphQL mutation creates spanv2', () async {
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      final link = fixture.createSentryTracingLink();
      final request = Request(
        operation: Operation(
          document: parseString(
              'mutation CreateUser(\$name: String!) { createUser(name: \$name) { id name } }'),
          operationName: 'CreateUser',
        ),
        variables: {'name': 'John Doe'},
      );

      await link.request(request).first;

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span =
          fixture.processor.findSpanByOperation('http.graphql.mutation');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value,
          equals('http.graphql.mutation'));
      expect(span.parentSpan, equals(transactionSpan));
    });

    test('GraphQL error creates spanv2 with error status', () async {
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      final link = fixture.createSentryTracingLink(
        shouldReturnError: true,
        markErrorsAsFailed: true,
      );
      final request = Request(
        operation: Operation(
          document: parseString('query GetUser { user(id: "999") { name } }'),
          operationName: 'GetUser',
        ),
      );

      await link.request(request).first;

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      final span = fixture.processor.findSpanByOperation('http.graphql.query');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);

      expect(span.status, equals(SentrySpanStatusV2.error));

      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value,
          equals('http.graphql.query'));
      expect(span.parentSpan, equals(transactionSpan));
    });

    test('shouldStartTransaction creates root spanv2 when no active span',
        () async {
      final link =
          fixture.createSentryTracingLink(shouldStartTransaction: true);
      final request = Request(
        operation: Operation(
          document: parseString('query GetUser { user(id: "1") { name } }'),
          operationName: 'GetUser',
        ),
      );

      await link.request(request).first;

      await fixture.processor.waitForProcessing();

      final allSpans = fixture.processor.capturedSpans;
      expect(allSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('http.graphql.query');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(span.parentSpan, isNull);

      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value,
          equals('http.graphql.query'));
      expect(span.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
          equals('auto.graphql.sentry_link'));
    });
  });
}

class Fixture {
  late final Hub hub;
  late final SentryOptions options;
  late final FakeTelemetryProcessor processor;

  Fixture() {
    processor = FakeTelemetryProcessor();
    options = SentryOptions(dsn: 'https://abc@def.ingest.sentry.io/1234567')
      ..automatedTestMode = true
      ..tracesSampleRate = 1.0
      ..traceLifecycle = SentryTraceLifecycle.streaming
      ..telemetryProcessor = processor;
    hub = Hub(options);

    options.addIntegration(InstrumentationSpanFactorySetupIntegration());
    options.integrations.last.call(hub, options);
  }

  Link createSentryTracingLink({
    bool shouldReturnError = false,
    bool markErrorsAsFailed = false,
    bool shouldStartTransaction = false,
  }) {
    final sentryLink = SentryTracingLink(
      shouldStartTransaction: shouldStartTransaction,
      graphQlErrorsMarkTransactionAsFailed: markErrorsAsFailed,
      hub: hub,
    );

    final mockLink = _MockLink(shouldReturnError: shouldReturnError);

    return Link.from([sentryLink, mockLink]);
  }

  Future<void> tearDown() async {
    processor.clear();
    await hub.close();
  }
}

class _MockLink extends Link {
  final bool shouldReturnError;

  _MockLink({this.shouldReturnError = false});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    if (shouldReturnError) {
      return Stream.value(
        Response(
          data: null,
          errors: [
            GraphQLError(
              message: 'User not found',
              extensions: {'code': 'NOT_FOUND'},
            ),
          ],
          response: {},
        ),
      );
    }

    return Stream.value(
      Response(
        data: {
          'user': {'name': 'John Doe'}
        },
        errors: null,
        response: {},
      ),
    );
  }
}
