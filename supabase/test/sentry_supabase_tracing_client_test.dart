import 'package:sentry_supabase/src/sentry_supabase_tracing_client.dart';
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

  group('Tracing', () {
    void verifyStartTransaction(String operation) {
      expect(fixture.mockHub.startTransactionCalls.length, 1);
      final startTransactionCalls = fixture.mockHub.startTransactionCalls.first;
      expect(startTransactionCalls.$1, 'from(mock-table)'); // name
      expect(startTransactionCalls.$2, 'db.$operation');
    }

    void verifyCommonSpanAttributes(String version) {
      final span = fixture.mockHub.mockSpan;
      expect(span.data['db.schema'], 'public');
      expect(span.data['db.table'], 'mock-table');
      expect(span.data['db.url'], 'https://example.com');
      expect(span.data['db.sdk'], version);
      expect(span.data['origin'], 'auto.db.supabase');
    }

    void verifyFinishSpan() {
      final span = fixture.mockHub.mockSpan;
      expect(span.finishCalls.length, 1);
      final setStatusCall = span.setStatusCalls.first;
      expect(setStatusCall, SpanStatus.ok());
    }

    test('should create trace for select', () async {
      fixture.mockClient.jsonResponse = '{"id": 42}';

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase
            .from('mock-table')
            .select()
            .lt('id', 42)
            .gt('id', 20)
            .not('id', 'eq', 32);
      } catch (e) {
        // Ignore
      }

      verifyStartTransaction('select');
      verifyCommonSpanAttributes(supabase.headers['X-Client-Info'] ?? '');
      verifyFinishSpan();

      final span = fixture.mockHub.mockSpan;
      expect(span.data['db.query'], [
        'select(*)',
        'lt(id, 42)',
        'gt(id, 20)',
        'not(id, eq.32)',
      ]);
      expect(span.data['op'], 'db.select');
    });

    test('should create trace for insert', () async {
      fixture.mockClient.jsonResponse = '{"id": 42}';

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('mock-table').insert({'id': 42});
      } catch (e) {
        // Ignore
      }

      verifyStartTransaction('insert');
      verifyCommonSpanAttributes(supabase.headers['X-Client-Info'] ?? '');
      verifyFinishSpan();

      final span = fixture.mockHub.mockSpan;
      expect(span.data['db.body'], {'id': 42});
      expect(span.data['op'], 'db.insert');
    });

    test('should create trace for upsert', () async {
      fixture.mockClient.jsonResponse = '{"id": 42}';

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('mock-table').upsert({'id': 42}).select('id,name');
      } catch (e) {
        // Ignore
      }

      verifyStartTransaction('upsert');
      verifyCommonSpanAttributes(supabase.headers['X-Client-Info'] ?? '');
      verifyFinishSpan();

      final span = fixture.mockHub.mockSpan;
      expect(span.data['db.body'], {'id': 42});
      expect(span.data['db.query'], ['select(id,name)']);
      expect(span.data['op'], 'db.upsert');
    });

    test('should create trace for update', () async {
      fixture.mockClient.jsonResponse = '{"id": 1337}';

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase
            .from('mock-table')
            .update({'id': 1337})
            .eq('id', 42)
            .or('id.eq.8');
      } catch (e) {
        // Ignore
      }

      verifyStartTransaction('update');
      verifyCommonSpanAttributes(supabase.headers['X-Client-Info'] ?? '');
      verifyFinishSpan();

      final span = fixture.mockHub.mockSpan;
      expect(span.data['db.body'], {'id': 1337});
      expect(span.data['db.query'], ['eq(id, 42)', 'or(id.eq.8)']);
      expect(span.data['op'], 'db.update');
    });

    test('should create trace for delete', () async {
      fixture.mockClient.jsonResponse = '{}';

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('mock-table').delete().eq('id', 42);
      } catch (e) {
        // Ignore
      }

      verifyStartTransaction('delete');
      verifyCommonSpanAttributes(supabase.headers['X-Client-Info'] ?? '');
      verifyFinishSpan();

      final span = fixture.mockHub.mockSpan;
      expect(span.data['db.query'], ['eq(id, 42)']);
      expect(span.data['op'], 'db.delete');
    });

    test('should finish with error status if request fails', () async {
      fixture.mockClient.statusCode = 404;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('mock-table').delete().eq('id', 42);
      } catch (e) {
        // Ignore
      }

      final span = fixture.mockHub.mockSpan;
      expect(span.finishCalls.length, 1);
      final setStatusCall = span.setStatusCalls.first;
      expect(setStatusCall, SpanStatus.fromHttpStatusCode(404));
    });

    test(
        'should finish with exception and internal error status if request throws',
        () async {
      final exception = Exception('test');
      fixture.mockClient.throwException = exception;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from('mock-table').delete().eq('id', 42);
      } catch (e) {
        expect(e, exception); // Rethrows
      }

      final span = fixture.mockHub.mockSpan;
      expect(span.finishCalls.length, 1);

      final setThrowableCall = span.setThrowableCalls.first;
      expect(setThrowableCall, exception);

      final setStatusCall = span.setStatusCalls.first;
      expect(setStatusCall, SpanStatus.internalError());
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
      final insertSpan = fixture.mockHub.mockSpan;
      expect(insertSpan.data['db.body'], isNull);

      try {
        await supabase.from('countries').upsert({'id': 42}).select();
      } catch (e) {
        // Ignore
      }
      final upsertSpan = fixture.mockHub.mockSpan;
      expect(upsertSpan.data['db.body'], isNull);

      try {
        await supabase.from('countries').update({'id': 1337}).eq('id', 42);
      } catch (e) {
        // Ignore
      }
      final updateSpan = fixture.mockHub.mockSpan;
      expect(updateSpan.data['db.body'], isNull);
    });
  });
}

class Fixture {
  final supabaseUrl = 'https://example.com';
  final supabaseKey = 'YOUR_ANON_KEY';

  final options = SentryOptions(
    dsn: 'https://example.com/123',
  );
  final mockClient = MockClient();
  late final mockHub = MockHub(options);

  Fixture() {
    options.sendDefaultPii = true; // Send PII by default in test.
  }

  SentrySupabaseTracingClient getSut() {
    return SentrySupabaseTracingClient(mockClient, mockHub);
  }

  SupabaseClient getSupabaseClient() {
    return SupabaseClient(
      supabaseUrl,
      supabaseKey,
      httpClient: getSut(),
    );
  }
}
