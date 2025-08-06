import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/renderer/renderer.dart';
import 'package:sentry_flutter/src/screenshot/screenshot_support.dart';

import '../mocks.dart';

void main() {
  group('isScreenshotSupported', () {
    SentryFlutterOptions _buildOptions({
      required bool isWeb,
      FlutterRenderer? renderer,
    }) {
      final options = defaultTestOptions();
      options.platform = MockPlatform(isWeb: isWeb);
      options.rendererWrapper = MockRendererWrapper(renderer);
      return options;
    }

    test('returns true for non-web platforms', () {
      final options = _buildOptions(isWeb: false);
      expect(options.isScreenshotSupported, isTrue);
    });

    test('returns true for web canvasKit renderer', () {
      final options = _buildOptions(
        isWeb: true,
        renderer: FlutterRenderer.canvasKit,
      );
      expect(options.isScreenshotSupported, isTrue);
    });

    test('returns true for web skwasm renderer', () {
      final options = _buildOptions(
        isWeb: true,
        renderer: FlutterRenderer.skwasm,
      );
      expect(options.isScreenshotSupported, isTrue);
    });

    test('returns false for web html renderer', () {
      final options = _buildOptions(
        isWeb: true,
        renderer: FlutterRenderer.html,
      );
      expect(options.isScreenshotSupported, isFalse);
    });

    test('returns false for web unknown renderer', () {
      final options = _buildOptions(
        isWeb: true,
        renderer: FlutterRenderer.unknown,
      );
      expect(options.isScreenshotSupported, isFalse);
    });
  });
}
