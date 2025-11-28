import 'dart:convert';
import 'dart:async';

import 'package:sentry_supabase/src/sentry_supabase_breadcrumb_client.dart';
import 'package:test/test.dart';
import 'package:sentry/sentry.dart';
import 'package:http/http.dart';

import 'package:supabase/supabase.dart';
import 'mocks/mock_hub.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('Inner Client', () {
    test('send called on send', () async {
      final sut = fixture.getSut();

      final request = Request('GET', Uri.parse('https://example.com/123'));

      await sut.send(request);

      expect(fixture.mockClient.sendCalls.length, 1);
      expect(fixture.mockClient.sendCalls.first, request);
    });

    test('close called on close', () async {
      final sut = fixture.getSut();

      sut.close();

      expect(fixture.mockClient.closeCalls.length, 1);
    });
  });

  group('Breadcrumb', () {
    test('added on select', () async {
      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('countries').select().eq('id', 42);
      } catch (e) {
        // Ignore
      }

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.mockHub.addBreadcrumbCalls.first.$1;
      expect(breadcrumb.message, 'from(countries)');
      expect(breadcrumb.category, 'db.select');
      expect(breadcrumb.type, 'supabase');

      expect(breadcrumb.data?['table'], 'countries');
      expect(breadcrumb.data?['operation'], 'select');
      expect(breadcrumb.data?['query'], ['select(*)', 'eq(id, 42)']);
    });

    test('added on insert', () async {
      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('countries').insert({'id': 42});
      } catch (e) {
        // Ignore
      }

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.mockHub.addBreadcrumbCalls.first.$1;
      expect(breadcrumb.message, 'from(countries)');
      expect(breadcrumb.category, 'db.insert');
      expect(breadcrumb.type, 'supabase');

      expect(breadcrumb.data?['table'], 'countries');
      expect(breadcrumb.data?['operation'], 'insert');
      expect(breadcrumb.data?['body'], {'id': 42});
    });

    test('added on upsert', () async {
      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('countries').upsert({'id': 42}).select();
      } catch (e) {
        // Ignore
      }

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.mockHub.addBreadcrumbCalls.first.$1;
      expect(breadcrumb.message, 'from(countries)');
      expect(breadcrumb.category, 'db.upsert');
      expect(breadcrumb.type, 'supabase');

      expect(breadcrumb.data?['table'], 'countries');
      expect(breadcrumb.data?['operation'], 'upsert');
      expect(breadcrumb.data?['query'], ['select(*)']);
      expect(breadcrumb.data?['body'], {'id': 42});
    });

    test('added on update', () async {
      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('countries').update({'id': 1337}).eq('id', 42);
      } catch (e) {
        // Ignore
      }

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.mockHub.addBreadcrumbCalls.first.$1;
      expect(breadcrumb.message, 'from(countries)');
      expect(breadcrumb.category, 'db.update');
      expect(breadcrumb.type, 'supabase');

      expect(breadcrumb.data?['table'], 'countries');
      expect(breadcrumb.data?['operation'], 'update');
      expect(breadcrumb.data?['query'], ['eq(id, 42)']);
      expect(breadcrumb.data?['body'], {'id': 1337});
    });

    test('added on delete', () async {
      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('countries').delete().eq('id', 42);
      } catch (e) {
        // Ignore
      }

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.mockHub.addBreadcrumbCalls.first.$1;
      expect(breadcrumb.message, 'from(countries)');
      expect(breadcrumb.category, 'db.delete');
      expect(breadcrumb.type, 'supabase');

      expect(breadcrumb.data?['table'], 'countries');
      expect(breadcrumb.data?['operation'], 'delete');
      expect(breadcrumb.data?['query'], ['eq(id, 42)']);
    });
  });

  group('PII', () {
    test('defaultPii disabled does not send body', () async {
      fixture.options.sendDefaultPii = false;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('countries').insert({'id': 42});
      } catch (e) {
        // Ignore
      }
      try {
        await supabase.from('countries').upsert({'id': 42}).select();
      } catch (e) {
        // Ignore
      }
      try {
        await supabase.from('countries').update({'id': 1337}).eq('id', 42);
      } catch (e) {
        // Ignore
      }

      final insertBreadcrumb = fixture.mockHub.addBreadcrumbCalls.first.$1;
      expect(insertBreadcrumb.data?['query'], isNull);
      expect(insertBreadcrumb.data?['body'], isNull);

      final upsertBreadcrumb = fixture.mockHub.addBreadcrumbCalls[1].$1;
      expect(upsertBreadcrumb.data?['query'], isNull);
      expect(upsertBreadcrumb.data?['body'], isNull);

      final updateBreadcrumb = fixture.mockHub.addBreadcrumbCalls[2].$1;
      expect(updateBreadcrumb.data?['query'], isNull);
      expect(updateBreadcrumb.data?['body'], isNull);
    });
  });
}

class Fixture {
  final supabaseUrl = 'https://example.com';
  final supabaseKey = 'YOUR_ANON_KEY';

  final options = SentryOptions(
    dsn: 'https://example.com/123',
  );
  final mockClient = _MockClient();
  late final mockHub = MockHub(options);

  Fixture() {
    options.sendDefaultPii = true; // Send PII by default in test.
    options.maxRequestBodySize =
        MaxRequestBodySize.always; // Always include body in test.
  }

  SentrySupabaseBreadcrumbClient getSut() {
    return SentrySupabaseBreadcrumbClient(
      mockClient,
      mockHub,
    );
  }

  SupabaseClient getSupabaseClient() {
    return SupabaseClient(
      supabaseUrl,
      supabaseKey,
      httpClient: getSut(),
    );
  }
}

class _MockClient extends BaseClient {
  final sendCalls = <BaseRequest>[];
  final closeCalls = <void>[];

  var jsonResponse = '{}';
  var statusCode = 200;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    sendCalls.add(request);
    return StreamedResponse(
      Stream.value(utf8.encode(jsonResponse)),
      statusCode,
    );
  }

  @override
  void close() {
    closeCalls.add(null);
  }
}
