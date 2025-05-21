import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:sentry_supabase/src/sentry_supabase_error_client.dart';
import 'package:test/test.dart';
import 'package:sentry/sentry.dart';
import 'package:http/http.dart';

import 'package:supabase/supabase.dart';
import 'mock_client.dart';
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

  group('Error', () {
    test('should create error if select request fails', () async {
      fixture.mockClient.statusCode = 404;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from("mock-table").select().eq("id", 42);
      } catch (e) {
        // Ignore
      }

      expect(fixture.mockHub.captureEventCalls.length, 1);
      final event = fixture.mockHub.captureEventCalls.first.$1;

      expect(event.throwableMechanism, isA<ThrowableMechanism>());
      final throwableMechanism = event.throwableMechanism as ThrowableMechanism;

      expect(throwableMechanism.mechanism.type, 'SentrySupabaseClient');
      expect(throwableMechanism.throwable, isA<SentrySupabaseClientError>());

      final error = throwableMechanism.throwable as SentrySupabaseClientError;
      expect(error.toString().contains('404'), true);
    });

    test('should capture error if send throws', () async {
      final error = Exception('test');
      fixture.mockClient.throwException = error;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from("mock-table").select().eq("id", 42);
      } catch (e) {
        expect(e, error); // Error is rethrown
      }

      expect(fixture.mockHub.captureEventCalls.length, 1);
      final event = fixture.mockHub.captureEventCalls.first.$1;

      expect(event.throwableMechanism, isA<ThrowableMechanism>());
      final throwableMechanism = event.throwableMechanism as ThrowableMechanism;

      expect(throwableMechanism.mechanism.type, 'SentrySupabaseClient');
      expect(throwableMechanism.throwable, error);
    });
  });

  group('Supabase Context', () {
    test('should add supabase data to context if select request fails',
        () async {
      fixture.mockClient.statusCode = 404;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from("mock-table").select().eq("id", 42);
      } catch (e) {
        // Ignore
      }

      expect(fixture.mockHub.captureEventCalls.length, 1);
      final event = fixture.mockHub.captureEventCalls.first.$1;

      expect(event.contexts['supabase'], isNotNull);
      final supabaseContext =
          event.contexts['supabase'] as Map<String, dynamic>;
      expect(supabaseContext['table'], 'mock-table');
      expect(supabaseContext['operation'], 'select');
      expect(supabaseContext['query'], ['select(*)', "eq(id, 42)"]);
    });

    test('should add supabase data to context if insert request fails',
        () async {
      fixture.mockClient.statusCode = 404;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from("mock-table").insert({'id': 42});
      } catch (e) {
        // Ignore
      }

      expect(fixture.mockHub.captureEventCalls.length, 1);
      final event = fixture.mockHub.captureEventCalls.first.$1;

      expect(event.contexts['supabase'], isNotNull);
      final supabaseContext =
          event.contexts['supabase'] as Map<String, dynamic>;
      expect(supabaseContext['table'], 'mock-table');
      expect(supabaseContext['operation'], 'insert');
      expect(supabaseContext['body'], {'id': 42});
    });

    test('should add supabase data to context if update request fails',
        () async {
      fixture.mockClient.statusCode = 404;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from("mock-table").update({'id': 1337}).eq("id", 42);
      } catch (e) {
        // Ignore
      }

      expect(fixture.mockHub.captureEventCalls.length, 1);
      final event = fixture.mockHub.captureEventCalls.first.$1;

      expect(event.contexts['supabase'], isNotNull);
      final supabaseContext =
          event.contexts['supabase'] as Map<String, dynamic>;
      expect(supabaseContext['table'], 'mock-table');
      expect(supabaseContext['operation'], 'update');
      expect(supabaseContext['body'], {'id': 1337});
      expect(supabaseContext['query'], ["eq(id, 42)"]);
    });

    test('should add supabase data to context if upsert request fails',
        () async {
      fixture.mockClient.statusCode = 404;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from("mock-table").upsert({'id': 42}).select();
      } catch (e) {
        // Ignore
      }

      expect(fixture.mockHub.captureEventCalls.length, 1);
      final event = fixture.mockHub.captureEventCalls.first.$1;

      expect(event.contexts['supabase'], isNotNull);
      final supabaseContext =
          event.contexts['supabase'] as Map<String, dynamic>;
      expect(supabaseContext['table'], 'mock-table');
      expect(supabaseContext['operation'], 'upsert');
      expect(supabaseContext['body'], {'id': 42});
      expect(supabaseContext['query'], ["select(*)"]);
    });

    test('should add supabase data to context if delete request fails',
        () async {
      fixture.mockClient.statusCode = 404;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from("mock-table").delete().eq("id", 42);
      } catch (e) {
        // Ignore
      }

      expect(fixture.mockHub.captureEventCalls.length, 1);
      final event = fixture.mockHub.captureEventCalls.first.$1;

      expect(event.contexts['supabase'], isNotNull);
      final supabaseContext =
          event.contexts['supabase'] as Map<String, dynamic>;
      expect(supabaseContext['table'], 'mock-table');
      expect(supabaseContext['operation'], 'delete');
      expect(supabaseContext['query'], ["eq(id, 42)"]);
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

  Fixture() {
    options.tracesSampleRate = 1.0; // enable tracing
  }

  SentrySupabaseErrorClient getSut() {
    return SentrySupabaseErrorClient(
      mockClient,
      mockHub,
    );
  }

  SupabaseClient getSupabaseClient() {
    return SupabaseClient(
      supabaseUrl,
      'YOUR_ANON_KEY',
      httpClient: getSut(),
    );
  }
}
