import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/event_processor/screenshot_event_processor.dart';
import 'package:sentry_flutter/src/integrations/screenshot_integration.dart';

import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('screenshotIntegration creates screenshot processor', () {
    final integration = fixture.getSut();

    integration(fixture.hub, fixture.options);

    final processors = fixture.options.eventProcessors
        .where((e) => e.runtimeType == ScreenshotEventProcessor);

    expect(processors.isNotEmpty, true);
  });

  test(
      'screenshotIntegration does not add screenshot processor if opt out in options',
      () {
    final integration = fixture.getSut(attachScreenshot: false);

    integration(fixture.hub, fixture.options);

    final processors = fixture.options.eventProcessors
        .where((e) => e.runtimeType == ScreenshotEventProcessor);

    expect(processors.isEmpty, true);
  });

  test('screenshotIntegration adds integration to the sdk list', () {
    final integration = fixture.getSut();

    integration(fixture.hub, fixture.options);

    expect(fixture.options.sdk.integrations.contains('screenshotIntegration'),
        true);
  });

  test('screenshotIntegration does not add integration to the sdk list', () {
    final integration = fixture.getSut(attachScreenshot: false);

    integration(fixture.hub, fixture.options);

    expect(fixture.options.sdk.integrations.contains('screenshotIntegration'),
        false);
  });

  test('screenshotIntegration close resets processor', () {
    final integration = fixture.getSut();

    integration(fixture.hub, fixture.options);
    integration.close();

    final processors = fixture.options.eventProcessors
        .where((e) => e.runtimeType == ScreenshotEventProcessor);

    expect(processors.isEmpty, true);
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions();

  ScreenshotIntegration getSut({bool attachScreenshot = true}) {
    options.attachScreenshot = attachScreenshot;
    return ScreenshotIntegration();
  }
}
