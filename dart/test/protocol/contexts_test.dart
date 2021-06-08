import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final contexts = Contexts(
    device: SentryDevice(batteryLevel: 90),
    operatingSystem: SentryOperatingSystem(name: 'name'),
    runtimes: [SentryRuntime(name: 'name')],
    app: SentryApp(name: 'name'),
    browser: SentryBrowser(name: 'name'),
    gpu: SentryGpu(id: 1),
    culture: SentryCulture(locale: 'foo-bar'),
  );

  final contextsJson = <String, dynamic>{
    'device': {'battery_level': 90.0},
    'os': {'name': 'name'},
    'runtime': {'name': 'name'},
    'app': {'app_name': 'name'},
    'browser': {'name': 'name'},
    'gpu': {'id': 1},
    'culture': {'locale': 'foo-bar'}
  };

  final contextsMutlipleRuntimes = Contexts(
    runtimes: [
      SentryRuntime(name: 'name'),
      SentryRuntime(name: 'name'),
      SentryRuntime(key: 'key')
    ],
  );

  final contextsMutlipleRuntimesJson = <String, dynamic>{
    'name': {'name': 'name', 'type': 'runtime'},
    'name0': {'name': 'name', 'type': 'runtime'},
  };

  group('json', () {
    test('toJson', () {
      final json = contexts.toJson();

      expect(
        DeepCollectionEquality().equals(contextsJson, json),
        true,
      );
    });
    test('toJson multiple runtimes', () {
      final json = contextsMutlipleRuntimes.toJson();

      expect(
        DeepCollectionEquality().equals(contextsMutlipleRuntimesJson, json),
        true,
      );
    });
    test('fromJson', () {
      final contexts = Contexts.fromJson(contextsJson);
      final json = contexts.toJson();

      expect(
        DeepCollectionEquality().equals(contextsJson, json),
        true,
      );
    });
    test('fromJson multiple runtimes', () {
      final contextsMutlipleRuntimes =
          Contexts.fromJson(contextsMutlipleRuntimesJson);
      final json = contextsMutlipleRuntimes.toJson();

      expect(
        DeepCollectionEquality().equals(contextsMutlipleRuntimesJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = contexts;

      final copy = data.copyWith();

      expect(
        DeepCollectionEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = contexts;
      data['extra'] = 'value';

      final device = SentryDevice(batteryLevel: 100);
      final os = SentryOperatingSystem(name: 'name1');
      final runtimes = [SentryRuntime(name: 'name1')];
      final app = SentryApp(name: 'name1');
      final browser = SentryBrowser(name: 'name1');
      final gpu = SentryGpu(id: 2);
      final culture = SentryCulture(locale: 'foo-bar');

      final copy = data.copyWith(
        device: device,
        operatingSystem: os,
        runtimes: runtimes,
        app: app,
        browser: browser,
        gpu: gpu,
        culture: culture,
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
      expect('value', copy['extra']);
    });
  });
}
