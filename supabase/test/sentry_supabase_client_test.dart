import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:test/test.dart';
import 'package:sentry/sentry.dart';
import 'package:http/http.dart';
import 'dart:convert';

import 'dart:async';

import 'package:supabase/supabase.dart';

void main() {
  const supabaseUrl = 'YOUR_SUPABASE_URL';
  const supabaseKey = 'YOUR_ANON_KEY';
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('Client', () {
    test('calls send on inner client', () async {
      final sentrySupabaseClient = fixture.getSut();

      final request = Request('GET', Uri.parse('https://example.com/123'));

      await sentrySupabaseClient.send(request);

      expect(fixture.mockClient.sendCalls.length, 1);
      expect(fixture.mockClient.sendCalls.first, request);
    });
  });

  group('Breadcrumb', () {
    test('select adds a breadcrumb', () async {
      final sentrySupabaseClient = fixture.getSut();
      final supabase = SupabaseClient(
        supabaseUrl,
        supabaseKey,
        httpClient: sentrySupabaseClient,
      );

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

    test('insert adds a breadcrumb', () async {
      final sentrySupabaseClient = fixture.getSut();
      final supabase = SupabaseClient(
        supabaseUrl,
        supabaseKey,
        httpClient: sentrySupabaseClient,
      );

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
    });

    test('upsert adds a breadcrumb', () async {
      final sentrySupabaseClient = fixture.getSut();
      final supabase = SupabaseClient(
        supabaseUrl,
        supabaseKey,
        httpClient: sentrySupabaseClient,
      );

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
    });

    test('update adds a breadcrumb', () async {
      final sentrySupabaseClient = fixture.getSut();
      final supabase = SupabaseClient(
        supabaseUrl,
        supabaseKey,
        httpClient: sentrySupabaseClient,
      );

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
    });

    test('delete adds a breadcrumb', () async {
      final sentrySupabaseClient = fixture.getSut();
      final supabase = SupabaseClient(
        supabaseUrl,
        supabaseKey,
        httpClient: sentrySupabaseClient,
      );

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

    test('does not add breadcrumb when breadcrumbs are disabled', () async {
      final sentrySupabaseClient = fixture.getSut(breadcrumbs: false);
      final supabase = SupabaseClient(
        supabaseUrl,
        supabaseKey,
        httpClient: sentrySupabaseClient,
      );

      try {
        await supabase.from('countries').select();
      } catch (e) {
        print(e);
      }

      try {
        await supabase.from('countries').insert({});
      } catch (e) {
        print(e);
      }

      try {
        await supabase.from('countries').upsert({});
      } catch (e) {
        print(e);
      }

      try {
        await supabase.from('countries').update({});
      } catch (e) {
        print(e);
      }

      try {
        await supabase.from('countries').delete();
      } catch (e) {
        print(e);
      }

      expect(fixture.mockHub.addBreadcrumbCalls.length, 0);
    });
  });
}

class Fixture {
  final options = SentryOptions(
    dsn: 'https://example.com/123',
  );
  final mockClient = MockClient();
  final mockHub = MockHub();

  SentrySupabaseClient getSut({bool breadcrumbs = true}) {
    return SentrySupabaseClient(
      breadcrumbs: breadcrumbs,
      client: mockClient,
      hub: mockHub,
    );
  }
}

class MockClient extends BaseClient {
  final sendCalls = <BaseRequest>[];
  final closeCalls = <void>[];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    sendCalls.add(request);
    return StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }
}

class MockHub implements Hub {
  final addBreadcrumbCalls = <(Breadcrumb, Hint?)>[];

  @override
  Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) async {
    addBreadcrumbCalls.add((crumb, hint));
  }

  // No such method
  @override
  void noSuchMethod(Invocation invocation) {
    'Method ${invocation.memberName} was called '
        'with arguments ${invocation.positionalArguments}';
  }
}
