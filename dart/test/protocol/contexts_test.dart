import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith keeps unchanged', () {
    final data = _generate();

    final copy = data.copyWith();

    // MapEquality fails for some reason, it probably check the instances equality too
    expect(data.toJson(), copy.toJson());
  });

  test('copyWith takes new values', () {
    final data = _generate();
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
}

Contexts _generate() => Contexts(
      device: SentryDevice(batteryLevel: 90),
      operatingSystem: SentryOperatingSystem(name: 'name'),
      runtimes: [SentryRuntime(name: 'name')],
      app: SentryApp(name: 'name'),
      browser: SentryBrowser(name: 'name'),
      gpu: SentryGpu(id: 1),
      culture: SentryCulture(locale: 'foo-bar'),
    );
