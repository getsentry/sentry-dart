import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:test/test.dart';
import 'package:sentry/sentry.dart';
import 'package:http/http.dart';
import 'dart:convert';

import 'dart:async';

import 'package:supabase/supabase.dart';

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
            .from("mock-table")
            .select()
            .lt("id", 42)
            .gt("id", 20)
            .not("id", "eq", 32);
      } catch (e) {
        print(e);
      }

      verifyStartTransaction('select');
      verifyCommonSpanAttributes(supabase.headers['X-Client-Info'] ?? "");
      verifyFinishSpan();

      final span = fixture.mockHub.mockSpan;
      expect(span.data['db.query'], [
        "select(*)",
        "lt(id, 42)",
        "gt(id, 20)",
        "not(id, eq.32)",
      ]);
      expect(span.data['op'], 'db.select');
    });

    test('should create trace for insert', () async {
      fixture.mockClient.jsonResponse = '{"id": 42}';

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from("mock-table").insert({"id": 42});
      } catch (e) {
        print(e);
      }

      verifyStartTransaction('insert');
      verifyCommonSpanAttributes(supabase.headers['X-Client-Info'] ?? "");
      verifyFinishSpan();

      final span = fixture.mockHub.mockSpan;
      expect(span.data['db.body'], {'id': 42});
      expect(span.data['op'], 'db.insert');
    });

    test('should create trace for upsert', () async {
      fixture.mockClient.jsonResponse = '{"id": 42}';

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from("mock-table").upsert({"id": 42}).select("id,name");
      } catch (e) {
        print(e);
      }

      verifyStartTransaction('upsert');
      verifyCommonSpanAttributes(supabase.headers['X-Client-Info'] ?? "");
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
            .from("mock-table")
            .update({"id": 1337})
            .eq("id", 42)
            .or("id.eq.8");
      } catch (e) {
        print(e);
      }

      verifyStartTransaction('update');
      verifyCommonSpanAttributes(supabase.headers['X-Client-Info'] ?? "");
      verifyFinishSpan();

      final span = fixture.mockHub.mockSpan;
      expect(span.data['db.body'], {'id': 1337});
      expect(span.data['db.query'], ["eq(id, 42)", "or(id.eq.8)"]);
      expect(span.data['op'], 'db.update');
    });

    test('should create trace for delete', () async {
      fixture.mockClient.jsonResponse = '{}';

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from("mock-table").delete().eq("id", 42);
      } catch (e) {
        print(e);
      }

      verifyStartTransaction('delete');
      verifyCommonSpanAttributes(supabase.headers['X-Client-Info'] ?? "");
      verifyFinishSpan();

      final span = fixture.mockHub.mockSpan;
      expect(span.data['db.query'], ["eq(id, 42)"]);
      expect(span.data['op'], 'db.delete');
    });

    test('should finish with error status if request fails', () async {
      fixture.mockClient.statusCode = 404;

      final supabase = fixture.getSupabaseClient();

      try {
        await supabase.from("mock-table").delete().eq("id", 42);
      } catch (e) {
        print(e);
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
        await supabase.from("mock-table").delete().eq("id", 42);
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
}

class Fixture {
  final supabaseUrl = 'https://example.com';
  final supabaseKey = 'YOUR_ANON_KEY';

  final options = SentryOptions(
    dsn: 'https://example.com/123',
  );
  final mockClient = _MockClient();
  late final mockHub = _MockHub(options);

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

class _MockClient extends BaseClient {
  final sendCalls = <BaseRequest>[];
  final closeCalls = <void>[];

  var jsonResponse = '{}';
  var statusCode = 200;
  dynamic throwException;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    sendCalls.add(request);
    if (throwException != null) {
      throw throwException;
    }
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

class _MockHub implements Hub {
  _MockHub(this._options);

  final SentryOptions _options;

  @override
  SentryOptions get options => _options;

  final startTransactionCalls = <(String, String)>[];

  var mockSpan = _MockSpan();

  @override
  ISentrySpan startTransaction(
    String name,
    String operation, {
    String? description,
    DateTime? startTimestamp,
    bool? bindToScope,
    bool? waitForChildren,
    Duration? autoFinishAfter,
    bool? trimEnd,
    OnTransactionFinish? onFinish,
    Map<String, dynamic>? customSamplingContext,
  }) {
    startTransactionCalls.add((name, operation));
    return mockSpan;
  }

  // No such method
  @override
  void noSuchMethod(Invocation invocation) {
    'Method ${invocation.memberName} was called '
        'with arguments ${invocation.positionalArguments}';
  }
}

class _MockSpan implements ISentrySpan {
  var data = <String, dynamic>{};
  var finishCalls = <(SpanStatus?, DateTime?, Hint?)>[];

  var setThrowableCalls = <dynamic>[];
  var setStatusCalls = <SpanStatus?>[];

  @override
  void setData(String key, dynamic value) {
    data[key] = value;
  }

  @override
  set throwable(dynamic value) {
    setThrowableCalls.add(value);
  }

  @override
  set status(SpanStatus? value) {
    setStatusCalls.add(value);
  }

  @override
  Future<void> finish(
      {SpanStatus? status, DateTime? endTimestamp, Hint? hint}) {
    finishCalls.add((status, endTimestamp, hint));
    return Future.value();
  }

  // No such method
  @override
  void noSuchMethod(Invocation invocation) {
    'Method ${invocation.memberName} was called '
        'with arguments ${invocation.positionalArguments}';
  }
}
