import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:test/test.dart';
import 'package:sentry/sentry.dart';
import 'package:http/http.dart';
import 'dart:convert';

import 'dart:async';

import 'package:supabase/supabase.dart';
import 'package:supabase/supabase.dart';

void main() {
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

    test('insert adds a breadcrumb', () async {
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

    test('upsert adds a breadcrumb', () async {
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

    test('update adds a breadcrumb', () async {
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

    test('delete adds a breadcrumb', () async {
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

    test('does not add breadcrumb when breadcrumbs are disabled', () async {
      final supabase = fixture.getSupabaseClient();

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

    test('redact request body', () async {
      final sentrySupabaseClient = fixture.getSut(
        redactRequestBody: (table, key, value) {
          switch (key) {
            case "password":
              return "<redacted>";
            case "token":
              return "<nope>";
            case "secret":
              return "<uwatm8>";
            case "null-me":
              return null;
            default:
              return value;
          }
        },
      );
      final supabase = SupabaseClient(
        fixture.supabaseUrl,
        fixture.supabaseKey,
        httpClient: sentrySupabaseClient,
      );

      try {
        await supabase.from("mock-table").insert(
            {'user': 'picklerick', 'password': 'whoops', 'null-me': 'foo'});
      } catch (e) {
        print(e);
      }

      try {
        await supabase
            .from("mock-table")
            .upsert({'user': 'picklerick', 'token': 'whoops'});
      } catch (e) {
        print(e);
      }

      try {
        await supabase
            .from("mock-table")
            .update({'user': 'picklerick', 'secret': 'whoops'}).eq("id", 42);
      } catch (e) {
        print(e);
      }

      expect(fixture.mockHub.addBreadcrumbCalls.length, 3);
      final inserted = fixture.mockHub.addBreadcrumbCalls[0].$1;
      expect(inserted.data?['body'],
          {'user': 'picklerick', 'password': '<redacted>', 'null-me': null});

      final upserted = fixture.mockHub.addBreadcrumbCalls[1].$1;
      expect(upserted.data?['body'], {'user': 'picklerick', 'token': '<nope>'});

      final updated = fixture.mockHub.addBreadcrumbCalls[2].$1;
      expect(
          updated.data?['body'], {'user': 'picklerick', 'secret': '<uwatm8>'});
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
      final finishCall = span.finishCalls.first;
      expect(finishCall.$1, SpanStatus.ok());
    }

    test('should not create trace if disabled', () async {
      fixture.options.tracesSampleRate = null;

      final supabase = fixture.getSupabaseClient(breadcrumbs: false);

      try {
        await supabase.from('mock-table').select();
      } catch (e) {
        print(e);
      }

      expect(fixture.mockHub.startTransactionCalls.length, 0);
    });

    test('should create trace for select', () async {
      fixture.mockClient.jsonResponse = '{"id": 42}';

      final supabase = fixture.getSupabaseClient(breadcrumbs: false);

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

      final supabase = fixture.getSupabaseClient(breadcrumbs: false);

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
    options.tracesSampleRate = 1.0; // enable tracing
  }

  SentrySupabaseClient getSut({
    bool breadcrumbs = true,
    SentrySupabaseRedactRequestBody? redactRequestBody,
  }) {
    return SentrySupabaseClient(
      breadcrumbs: breadcrumbs,
      client: mockClient,
      hub: mockHub,
      redactRequestBody: redactRequestBody,
    );
  }

  SupabaseClient getSupabaseClient({
    bool breadcrumbs = true,
    SentrySupabaseRedactRequestBody? redactRequestBody,
  }) {
    return SupabaseClient(
      supabaseUrl,
      supabaseKey,
      httpClient: getSut(
        breadcrumbs: breadcrumbs,
        redactRequestBody: redactRequestBody,
      ),
    );
  }
}

class MockClient extends BaseClient {
  final sendCalls = <BaseRequest>[];
  final closeCalls = <void>[];

  var jsonResponse = '{}';

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    sendCalls.add(request);
    return StreamedResponse(Stream.value(utf8.encode(jsonResponse)), 200);
  }
}

class MockHub implements Hub {
  MockHub(this._options);
  final SentryOptions _options;

  @override
  SentryOptions get options => _options;

  final addBreadcrumbCalls = <(Breadcrumb, Hint?)>[];
  final startTransactionCalls = <(String, String)>[];

  @override
  Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) async {
    addBreadcrumbCalls.add((crumb, hint));
  }

  var mockSpan = MockSpan();

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

class MockSpan implements ISentrySpan {
  var data = <String, dynamic>{};
  var finishCalls = <(SpanStatus?, DateTime?, Hint?)>[];

  @override
  void setData(String key, dynamic value) {
    data[key] = value;
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
