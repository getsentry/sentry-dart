// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/binding_wrapper.dart';

import 'binding.dart';

void main() {
  // Make sure whatever error happens during the frame processing we catch it
  // Otherwise it would disrupt the frame processing and freeze the UI
  group('$SentryWidgetsBindingMixin', () {
    late SentryAutomatedTestWidgetsFlutterBinding binding;
    late SentryOptions options;

    setUp(() {
      options = SentryOptions();
      binding = SentryAutomatedTestWidgetsFlutterBinding.ensureInitialized();
      // reset state
      binding.removeFramesTracking();
    });

    test('frame processing continues execution when clock throws', () {
      options.clock = () => throw Exception('Clock error');
      binding.initializeFramesTracking(
        (_, __) {},
        options,
        Duration(milliseconds: 16),
      );

      expect(
        () {
          binding.handleBeginFrame(null);
          binding.handleDrawFrame();
        },
        returnsNormally,
      );
    });

    test('frame processing continues execution when callback throws', () {
      options.clock = () => DateTime.now();
      binding.initializeFramesTracking(
        (_, __) {
          throw Exception('Callback error');
        },
        options,
        Duration(milliseconds: 16),
      );

      expect(
        () {
          binding.handleBeginFrame(null);
          binding.handleDrawFrame();
        },
        returnsNormally,
      );
    });
  });
}
