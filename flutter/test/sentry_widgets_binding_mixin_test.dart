import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/binding_wrapper.dart';

import 'binding.dart';

void main() {
  // Make sure whatever error happens during the frame processing we catch it
  // Otherwise it would disrupt the frame processing and freeze the UI
  group('$SentryWidgetsBindingMixin', () {
    late SentryAutomatedTestWidgetsFlutterBinding binding;

    setUp(() {
      binding = SentryAutomatedTestWidgetsFlutterBinding.ensureInitialized();
      // reset state
      binding.removeFramesTracking();
    });

    test('frame processing continues execution when clock throws', () {
      binding.initializeFramesTracking(
        (_, __) {},
        () => throw Exception('Clock error'),
      );

      expect(
        () {
          binding.handleBeginFrame(null);
          binding.handleDrawFrame();
        },
        returnsNormally,
      );
    });

    test('frame processing execution when callback throws', () {
      binding.initializeFramesTracking(
        (_, __) {
          throw Exception('Callback error');
        },
        () => DateTime.now(),
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
