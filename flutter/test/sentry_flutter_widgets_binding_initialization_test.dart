// Tests the case where no binding exists when SentryWidgetsFlutterBinding is initialized
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// Splitting up theses tests into multiple files as the bindings are not
// reset after each test.
//
// sentry_flutter_widgets_binding_initialization_test.dart: no existing binding
//
void main() {
  group('$SentryWidgetsFlutterBinding', () {
    test('returns existing WidgetsFlutterBinding when one exists', () {
      final originalBinding = WidgetsFlutterBinding.ensureInitialized();
      final binding = SentryWidgetsFlutterBinding.ensureInitialized();

      expect(binding, equals(originalBinding));
      expect(binding, isNot(isA<SentryWidgetsFlutterBinding>()));
    });
  });
}
