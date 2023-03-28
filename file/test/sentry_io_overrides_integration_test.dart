import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry_file/sentry_file.dart';
import 'package:sentry_file/src/sentry_io_overrides.dart';
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
}

class Fixture {
  final options = SentryOptions(dsn: fakeDsn);
  late final hub = Hub(options);

  SentryIOOverridesIntegration getSut() {
    return SentryIOOverridesIntegration();
  }
}
