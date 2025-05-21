import 'dart:convert';
import 'dart:async';

import 'package:sentry_supabase/src/sentry_supabase_breadcrumb_client.dart';
import 'package:test/test.dart';
import 'package:sentry/sentry.dart';
import 'package:http/http.dart';

import 'package:supabase/supabase.dart';
import 'mock_hub.dart';

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
        print(e);
      }

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.mockHub.addBreadcrumbCalls.first.$1;
      expect(breadcrumb.message, 'from(countries)');
      expect(breadcrumb.category, 'db.select');
      expect(breadcrumb.type, 'supabase');
      expect(breadcrumb.data?['query'], ['select(*)', 'eq(id, 42)']);
    });

    test('added on insert', () async {
      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('countries').insert({'id': 42});
      } catch (e) {
        print(e);
      }

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.mockHub.addBreadcrumbCalls.first.$1;
      expect(breadcrumb.message, 'from(countries)');
      expect(breadcrumb.category, 'db.insert');
      expect(breadcrumb.type, 'supabase');
      expect(breadcrumb.data?['body'], {'id': 42});
    });

    test('added on upsert', () async {
      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('countries').upsert({'id': 42}).select();
      } catch (e) {
        print(e);
      }

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.mockHub.addBreadcrumbCalls.first.$1;
      expect(breadcrumb.message, 'from(countries)');
      expect(breadcrumb.category, 'db.upsert');
      expect(breadcrumb.type, 'supabase');
      expect(breadcrumb.data?['query'], ['select(*)']);
      expect(breadcrumb.data?['body'], {'id': 42});
    });

    test('added on update', () async {
      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('countries').update({'id': 1337}).eq('id', 42);
      } catch (e) {
        print(e);
      }

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.mockHub.addBreadcrumbCalls.first.$1;
      expect(breadcrumb.message, 'from(countries)');
      expect(breadcrumb.category, 'db.update');
      expect(breadcrumb.type, 'supabase');
      expect(breadcrumb.data?['query'], ['eq(id, 42)']);
      expect(breadcrumb.data?['body'], {'id': 1337});
    });

    test('added on delete', () async {
      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('countries').delete().eq('id', 42);
      } catch (e) {
        print(e);
      }

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.mockHub.addBreadcrumbCalls.first.$1;
      expect(breadcrumb.message, 'from(countries)');
      expect(breadcrumb.category, 'db.delete');
      expect(breadcrumb.type, 'supabase');
      expect(breadcrumb.data?['query'], ['eq(id, 42)']);
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
    options.tracesSampleRate = 1.0; // enable tracing
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
