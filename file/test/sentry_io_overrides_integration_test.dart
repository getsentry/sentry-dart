import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry_file/sentry_file.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'mock_sentry_client.dart';

void main() {
  late IOOverrides? current;
  late Fixture fixture;

  setUp(() {
    current = IOOverrides.current;
    fixture = Fixture();
  });

  tearDown(() {
    IOOverrides.global = current;
  });

  test('adding integration installs io overrides', () {
    fixture.options.tracesSampleRate = 1.0;

    final sut = fixture.getSut();
    sut.call(fixture.hub, fixture.options);

    expect(
      fixture.options.sdk.integrations.contains('sentryIOOverridesIntegration'),
      isTrue,
    );
    expect(IOOverrides.current is SentryIOOverrides, isTrue);
  });

  test('not installed when tracing disabled', () {
    final sut = fixture.getSut();
    sut.call(fixture.hub, fixture.options);

    expect(
      fixture.options.sdk.integrations.contains('sentryIOOverridesIntegration'),
      isFalse,
    );
    expect(IOOverrides.current is SentryIOOverrides, isFalse);
  });

  test('global overrides restored', () {
    final previous = IOOverrides.current;

    fixture.options.tracesSampleRate = 1.0;

    final sut = fixture.getSut();
    sut.call(fixture.hub, fixture.options);
    sut.close();

    expect(IOOverrides.current, previous);
  });

  test('files created are sentry file after adding integration', () {
    fixture.options.tracesSampleRate = 1.0;

    final sut = fixture.getSut();
    sut.call(fixture.hub, fixture.options);

    final file = File("/home");
    expect(file is SentryFile, true);
  });
}

class Fixture {
  final options = defaultTestOptions();
  late final hub = Hub(options);

  SentryIOOverridesIntegration getSut() {
    return SentryIOOverridesIntegration();
  }
}
