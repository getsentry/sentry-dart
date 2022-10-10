import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter_example/main.dart';

void main() {

  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('setup sentry and render app', (tester) async {

    await setupSentry(
        () async {
          await tester.pumpWidget(
              DefaultAssetBundle(
                bundle: SentryAssetBundle(enableStructuredDataTracing: true),
                child: MyApp(),
              )
          );
          await tester.pumpAndSettle();
        }
    );

    // Find any UI element and verify it is present.
    expect(find.text('Open another Scaffold'), findsOneWidget);
  });
}
