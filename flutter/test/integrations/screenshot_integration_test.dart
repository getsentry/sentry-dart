import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/screenshot_integration.dart';
import 'package:sentry_flutter/src/integrations/widgets_binding_integration.dart';
import 'package:sentry_flutter/src/screenshot/screenshot_attachment_processor.dart';

import '../mocks.mocks.dart';

/// Tests that require `WidgetsFlutterBinding.ensureInitialized();` not
/// being called at all.
void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('screenshotIntegration creates screenshot processor', () async {
    final integration = ScreenshotIntegration();

    await integration(fixture.hub, fixture.options);

    expect(
        // ignore: invalid_use_of_internal_member
        fixture.options.clientAttachmentProcessor
            is ScreenshotAttachmentProcessor,
        true);
  });

  test('screenshotIntegration close resets processor', () async {
    final integration = ScreenshotIntegration();

    await integration(fixture.hub, fixture.options);
    await integration.close();

    expect(
        // ignore: invalid_use_of_internal_member
        fixture.options.clientAttachmentProcessor
            is ScreenshotAttachmentProcessor,
        false);
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions();
}
