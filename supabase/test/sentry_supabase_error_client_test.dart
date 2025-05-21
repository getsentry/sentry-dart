import 'package:sentry_supabase/src/sentry_supabase_error_client.dart';
import 'package:sentry_supabase/src/sentry_supabase_client_error.dart';
import 'package:test/test.dart';
import 'package:sentry/sentry.dart';
import 'package:http/http.dart';

import 'package:supabase/supabase.dart';
import 'mocks/mock_client.dart';
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

  group('Error', () {
    test('should create error if select request fails', () async {
      fixture.mockClient.statusCode = 404;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('mock-table').select().eq('id', 42);
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
        await supabase.from('mock-table').select().eq('id', 42);
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
        await supabase.from('mock-table').select().eq('id', 42);
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
      expect(supabaseContext['query'], ['select(*)', 'eq(id, 42)']);
    });

    test('should add supabase data to context if insert request fails',
        () async {
      fixture.mockClient.statusCode = 404;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('mock-table').insert({'id': 42});
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
        await supabase.from('mock-table').update({'id': 1337}).eq('id', 42);
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
      expect(supabaseContext['query'], ['eq(id, 42)']);
    });

    test('should add supabase data to context if upsert request fails',
        () async {
      fixture.mockClient.statusCode = 404;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('mock-table').upsert({'id': 42}).select();
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
      expect(supabaseContext['query'], ['select(*)']);
    });

    test('should add supabase data to context if delete request fails',
        () async {
      fixture.mockClient.statusCode = 404;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('mock-table').delete().eq('id', 42);
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
      expect(supabaseContext['query'], ['eq(id, 42)']);
    });
  });

  group('PII', () {
    test('defaultPii disabled does not send body', () async {
      fixture.mockClient.statusCode = 404;
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

      final insertEvent = fixture.mockHub.captureEventCalls[0].$1;
      final insertSupabaseContext =
          insertEvent.contexts['supabase'] as Map<String, dynamic>;
      expect(insertSupabaseContext['body'], isNull);

      final upsertEvent = fixture.mockHub.captureEventCalls[1].$1;
      final upsertSupabaseContext =
          upsertEvent.contexts['supabase'] as Map<String, dynamic>;
      expect(upsertSupabaseContext['body'], isNull);

      final updateEvent = fixture.mockHub.captureEventCalls[2].$1;
      final updateSupabaseContext =
          updateEvent.contexts['supabase'] as Map<String, dynamic>;
      expect(updateSupabaseContext['body'], isNull);
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
    options.sendDefaultPii = true; // Send PII by default in test.
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
