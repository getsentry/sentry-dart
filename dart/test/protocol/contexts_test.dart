import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final _traceId = SentryId.fromId('1988bb1b6f0d4c509e232f0cb9aaeaea');
  final _spanId = SpanId.fromId('976e0cd945864f60');
  final _parentSpanId = SpanId.fromId('c9c9fc3f9d4346df');

  final _trace = SentryTraceContext(
    traceId: _traceId,
    spanId: _spanId,
    operation: 'op',
    parentSpanId: _parentSpanId,
    sampled: true,
    description: 'desc',
    status: SpanStatus.ok(),
  );

  final _contexts = Contexts(
    device: SentryDevice(batteryLevel: 90.0),
    operatingSystem: SentryOperatingSystem(name: 'name'),
    runtimes: [SentryRuntime(name: 'name')],
    app: SentryApp(name: 'name'),
    browser: SentryBrowser(name: 'name'),
    gpu: SentryGpu(id: 1),
    culture: SentryCulture(locale: 'foo-bar'),
    trace: _trace,
  );

  final _contextsJson = <String, dynamic>{
    'device': {'battery_level': 90.0},
    'os': {'name': 'name'},
    'runtime': {'name': 'name'},
    'app': {'app_name': 'name'},
    'browser': {'name': 'name'},
    'gpu': {'id': 1},
    'culture': {'locale': 'foo-bar'},
    'trace': {
      'span_id': '976e0cd945864f60',
      'trace_id': '1988bb1b6f0d4c509e232f0cb9aaeaea',
      'op': 'op',
      'parent_span_id': 'c9c9fc3f9d4346df',
      'description': 'desc',
      'status': 'ok'
    },
  };

  final _contextsMutlipleRuntimes = Contexts(
    runtimes: [
      SentryRuntime(name: 'name'),
      SentryRuntime(name: 'name'),
      SentryRuntime(key: 'key')
    ],
  );

  final _contextsMutlipleRuntimesJson = <String, dynamic>{
    'name': {'name': 'name', 'type': 'runtime'},
    'name0': {'name': 'name', 'type': 'runtime'},
  };

  group('json', () {
    test('toJson', () {
      final json = _contexts.toJson();

      expect(
        DeepCollectionEquality().equals(_contextsJson, json),
        true,
      );
    });
    test('toJson multiple runtimes', () {
      final json = _contextsMutlipleRuntimes.toJson();

      expect(
        DeepCollectionEquality().equals(_contextsMutlipleRuntimesJson, json),
        true,
      );
    });
    test('fromJson', () {
      final contexts = Contexts.fromJson(_contextsJson);
      final json = contexts.toJson();

      expect(
        DeepCollectionEquality().equals(_contextsJson, json),
        true,
      );
    });
    test('fromJson multiple runtimes', () {
      final contextsMutlipleRuntimes =
          Contexts.fromJson(_contextsMutlipleRuntimesJson);
      final json = contextsMutlipleRuntimes.toJson();

      expect(
        DeepCollectionEquality().equals(_contextsMutlipleRuntimesJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = _contexts;

      final copy = data.copyWith();

      expect(
        DeepCollectionEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = _contexts.copyWith();
      data['extra'] = 'value';

      final device = SentryDevice(batteryLevel: 100);
      final os = SentryOperatingSystem(name: 'name1');
      final runtimes = [SentryRuntime(name: 'name1')];
      final app = SentryApp(name: 'name1');
      final browser = SentryBrowser(name: 'name1');
      final gpu = SentryGpu(id: 2);
      final culture = SentryCulture(locale: 'foo-bar');
      final trace = SentryTraceContext(
        traceId: _traceId,
        spanId: _spanId,
        operation: 'op',
        parentSpanId: _parentSpanId,
        sampled: true,
        description: 'desc',
        status: SpanStatus.ok(),
      );

      final copy = data.copyWith(
        device: device,
        operatingSystem: os,
        runtimes: runtimes,
        app: app,
        browser: browser,
        gpu: gpu,
        culture: culture,
        trace: _trace,
      );

      expect(device.toJson(), copy.device!.toJson());
      expect(os.toJson(), copy.operatingSystem!.toJson());
      expect(
        ListEquality().equals(runtimes, copy.runtimes),
        true,
      );
      expect(app.toJson(), copy.app!.toJson());
      expect(browser.toJson(), copy.browser!.toJson());
      expect(culture.toJson(), copy.culture!.toJson());
      expect(gpu.toJson(), copy.gpu!.toJson());
      expect(trace.toJson(), copy.trace!.toJson());
      expect('value', copy['extra']);
    });
  });
}
