import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final _traceId = SentryId.fromId('1988bb1b6f0d4c509e232f0cb9aaeaea');
  final _spanId = SpanId.fromId('976e0cd945864f60');
  final _parentSpanId = SpanId.fromId('c9c9fc3f9d4346df');
  final _associatedEventId =
      SentryId.fromId('8a32c0f9be1d34a5efb2c4a10d80de9a');

  final _trace = SentryTraceContext(
    traceId: _traceId,
    spanId: _spanId,
    operation: 'op',
    parentSpanId: _parentSpanId,
    sampled: true,
    description: 'desc',
    status: SpanStatus.ok(),
  );

  final _feedback = SentryFeedback(
    message: 'fixture-message',
    contactEmail: 'fixture-contactEmail',
    name: 'fixture-name',
    replayId: 'fixture-replayId',
    url: "https://fixture-url.com",
    associatedEventId: _associatedEventId,
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
    feedback: _feedback,
    flags: SentryFeatureFlags(values: [
      SentryFeatureFlag(flag: 'name', result: true),
    ]),
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
    'feedback': {
      'message': 'fixture-message',
      'contact_email': 'fixture-contactEmail',
      'name': 'fixture-name',
      'replay_id': 'fixture-replayId',
      'url': 'https://fixture-url.com',
      'associated_event_id': '8a32c0f9be1d34a5efb2c4a10d80de9a',
    },
    'flags': {
      'values': [
        {'flag': 'name', 'result': true}
      ],
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

  group('toAttributes', () {
    test('returns empty map when operating system and device are null', () {
      expect(Contexts().toAttributes(), isEmpty);
    });

    test('aggregates attributes from operating system and device', () {
      final contexts = Contexts(
        operatingSystem: SentryOperatingSystem(name: 'iOS', version: '17.4'),
        device: SentryDevice(brand: 'Apple', model: 'iPhone14,2'),
      );

      final attributes = contexts.toAttributes();

      expect(attributes[SemanticAttributesConstants.osName]?.value, 'iOS');
      expect(attributes[SemanticAttributesConstants.osVersion]?.value, '17.4');
      expect(
          attributes[SemanticAttributesConstants.deviceBrand]?.value, 'Apple');
      expect(attributes[SemanticAttributesConstants.deviceModel]?.value,
          'iPhone14,2');
    });

    test('omits sub-contexts that are null', () {
      final contexts = Contexts(
        operatingSystem: SentryOperatingSystem(name: 'iOS'),
      );

      final attributes = contexts.toAttributes();

      expect(attributes[SemanticAttributesConstants.osName]?.value, 'iOS');
      expect(attributes.containsKey(SemanticAttributesConstants.deviceBrand),
          false);
    });

    test('includes culture attributes when culture is present', () {
      final contexts = Contexts(
        culture: SentryCulture(locale: 'en-US', timezone: 'Europe/Vienna'),
      );

      final attributes = contexts.toAttributes();

      expect(attributes[SemanticAttributesConstants.cultureLocale]?.value,
          'en-US');
      expect(attributes[SemanticAttributesConstants.cultureTimezone]?.value,
          'Europe/Vienna');
    });

    test('emits process.runtime.* from the Dart runtime regardless of order',
        () {
      final contexts = Contexts(
        runtimes: [
          SentryRuntime(name: 'Flutter', version: '3.24.0'),
          SentryRuntime(name: 'Dart', version: '3.5.0'),
        ],
      );

      final attributes = contexts.toAttributes();

      expect(attributes[SemanticAttributesConstants.processRuntimeName]?.value,
          'Dart');
      expect(
          attributes[SemanticAttributesConstants.processRuntimeVersion]?.value,
          '3.5.0');
    });

    test('does not emit process.runtime.* when no Dart runtime is present', () {
      final contexts = Contexts(
        runtimes: [SentryRuntime(name: 'Flutter', version: '3.24.0')],
      );

      final attributes = contexts.toAttributes();

      expect(
          attributes
              .containsKey(SemanticAttributesConstants.processRuntimeName),
          false);
    });

    test('does not emit process.runtime.* when runtimes list is empty', () {
      final contexts = Contexts();

      final attributes = contexts.toAttributes();

      expect(
          attributes
              .containsKey(SemanticAttributesConstants.processRuntimeName),
          false);
    });
  });
}
