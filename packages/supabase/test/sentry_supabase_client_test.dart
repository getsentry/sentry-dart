import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:sentry_supabase/src/constants.dart';
import 'package:test/test.dart';
import 'package:sentry/sentry.dart';
import 'package:http/http.dart';

import 'mocks/mock_client.dart';
import 'mocks/mock_hub.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('Inner Client', () {
    test('send called on send', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: true,
        enableTracing: true,
        enableErrors: true,
      );

      final request = Request('GET', Uri.parse('https://example.com/123'));

      await sut.send(request);

      expect(fixture.mockClient.sendCalls.length, 1);
      expect(fixture.mockClient.sendCalls.first, request);
    });

    test('close called on close', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: true,
        enableTracing: true,
        enableErrors: true,
      );

      sut.close();

      expect(fixture.mockClient.closeCalls.length, 1);
    });
  });

  group('Inner Sentry Supabase Clients', () {
    test('breadcrumb client', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: true,
        enableTracing: false,
        enableErrors: false,
      );

      final request =
          Request('GET', Uri.parse('https://example.com/rest/v1/users'));
      await sut.send(request);

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
    });

    test('tracing client', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: false,
        enableTracing: true,
        enableErrors: false,
      );

      final request =
          Request('GET', Uri.parse('https://example.com/rest/v1/users'));
      await sut.send(request);

      expect(fixture.mockHub.getSpanCallCount, 1);
    });

    test('error client captures error with default status codes (500-599)',
        () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: false,
        enableTracing: false,
        enableErrors: true,
      );

      fixture.mockClient.statusCode = 500;

      final request =
          Request('GET', Uri.parse('https://example.com/rest/v1/users'));
      await sut.send(request);

      expect(fixture.mockHub.captureEventCalls.length, 1);
    });

    test('error client captures error with custom status codes', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: false,
        enableTracing: false,
        enableErrors: true,
        failedRequestStatusCodes: [SentryStatusCode(404)],
      );

      fixture.mockClient.statusCode = 404;

      final request =
          Request('GET', Uri.parse('https://example.com/rest/v1/users'));
      await sut.send(request);

      expect(fixture.mockHub.captureEventCalls.length, 1);
    });

    test('error client does not capture error outside configured status codes',
        () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: false,
        enableTracing: false,
        enableErrors: true,
        failedRequestStatusCodes: [SentryStatusCode(500)],
      );

      fixture.mockClient.statusCode = 404;

      final request =
          Request('GET', Uri.parse('https://example.com/rest/v1/users'));
      await sut.send(request);

      expect(fixture.mockHub.captureEventCalls.length, 0);
    });

    test('error client always captures exceptions', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: false,
        enableTracing: false,
        enableErrors: true,
      );

      fixture.mockClient.throwException = Exception('Network error');

      final request =
          Request('GET', Uri.parse('https://example.com/rest/v1/users'));

      await expectLater(() => sut.send(request), throwsException);

      expect(fixture.mockHub.captureEventCalls.length, 1);
    });

    test('error client does not capture non-Supabase requests', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: false,
        enableTracing: false,
        enableErrors: true,
        failedRequestStatusCodes: [SentryStatusCode.range(400, 599)],
      );

      fixture.mockClient.statusCode = 500;

      // Non-Supabase request (doesn't start with /rest/v1)
      final request =
          Request('GET', Uri.parse('https://example.com/auth/v1/token'));

      await sut.send(request);

      // Should not capture since it's not a Supabase REST API request
      expect(fixture.mockHub.captureEventCalls.length, 0);
    });

    test('all clients', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: true,
        enableTracing: true,
        enableErrors: true,
        failedRequestStatusCodes: [SentryStatusCode(404)],
      );

      fixture.mockClient.statusCode = 404;

      final request =
          Request('GET', Uri.parse('https://example.com/rest/v1/users'));
      await sut.send(request);

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      expect(fixture.mockHub.getSpanCallCount, 1);
      expect(fixture.mockHub.captureEventCalls.length, 1);
    });
  });

  group('Integration', () {
    test('adds breadcrumbs integration when breadcrumb client is created', () {
      expect(
        fixture.options.sdk.integrations,
        isNot(contains(integrationNameBreadcrumbs)),
      );

      fixture.getSut(
        enableBreadcrumbs: true,
        enableTracing: false,
        enableErrors: false,
      );

      expect(
        fixture.options.sdk.integrations,
        contains(integrationNameBreadcrumbs),
      );
    });

    test('adds tracing integration when tracing client is created', () {
      expect(
        fixture.options.sdk.integrations,
        isNot(contains(integrationNameTracing)),
      );

      fixture.getSut(
        enableBreadcrumbs: false,
        enableTracing: true,
        enableErrors: false,
      );

      expect(
        fixture.options.sdk.integrations,
        contains(integrationNameTracing),
      );
    });

    test('adds errors integration when error client is created', () {
      expect(
        fixture.options.sdk.integrations,
        isNot(contains(integrationNameErrors)),
      );

      fixture.getSut(
        enableBreadcrumbs: false,
        enableTracing: false,
        enableErrors: true,
      );

      expect(
        fixture.options.sdk.integrations,
        contains(integrationNameErrors),
      );
    });

    test('adds all integrations when all clients are created', () {
      expect(
        fixture.options.sdk.integrations,
        isNot(contains(integrationNameBreadcrumbs)),
      );
      expect(
        fixture.options.sdk.integrations,
        isNot(contains(integrationNameTracing)),
      );
      expect(
        fixture.options.sdk.integrations,
        isNot(contains(integrationNameErrors)),
      );

      fixture.getSut(
        enableBreadcrumbs: true,
        enableTracing: true,
        enableErrors: true,
      );

      expect(
        fixture.options.sdk.integrations,
        contains(integrationNameBreadcrumbs),
      );
      expect(
        fixture.options.sdk.integrations,
        contains(integrationNameTracing),
      );
      expect(
        fixture.options.sdk.integrations,
        contains(integrationNameErrors),
      );
    });

    test('does not duplicate integrations if already added', () {
      fixture.getSut(
        enableBreadcrumbs: true,
        enableTracing: true,
        enableErrors: true,
      );

      final breadcrumbsCount = fixture.options.sdk.integrations
          .where((integration) => integration == integrationNameBreadcrumbs)
          .length;
      final tracingCount = fixture.options.sdk.integrations
          .where((integration) => integration == integrationNameTracing)
          .length;
      final errorsCount = fixture.options.sdk.integrations
          .where((integration) => integration == integrationNameErrors)
          .length;

      fixture.getSut(
        enableBreadcrumbs: true,
        enableTracing: true,
        enableErrors: true,
      );

      final newBreadcrumbsCount = fixture.options.sdk.integrations
          .where((integration) => integration == integrationNameBreadcrumbs)
          .length;
      final newTracingCount = fixture.options.sdk.integrations
          .where((integration) => integration == integrationNameTracing)
          .length;
      final newErrorsCount = fixture.options.sdk.integrations
          .where((integration) => integration == integrationNameErrors)
          .length;

      expect(breadcrumbsCount, equals(1));
      expect(tracingCount, equals(1));
      expect(errorsCount, equals(1));
      expect(newBreadcrumbsCount, equals(1));
      expect(newTracingCount, equals(1));
      expect(newErrorsCount, equals(1));
    });
  });
}

class Fixture {
  final supabaseUrl = 'https://example.com';

  final options = SentryOptions(
    dsn: 'https://example.com/123',
  );
  final mockClient = MockClient();
  late final mockHub = MockHub(options);

  SentrySupabaseClient getSut({
    required bool enableBreadcrumbs,
    required bool enableTracing,
    required bool enableErrors,
    List<SentryStatusCode>? failedRequestStatusCodes,
  }) {
    return SentrySupabaseClient(
      enableBreadcrumbs: enableBreadcrumbs,
      enableTracing: enableTracing,
      enableErrors: enableErrors,
      client: mockClient,
      hub: mockHub,
      failedRequestStatusCodes: failedRequestStatusCodes,
    );
  }
}
