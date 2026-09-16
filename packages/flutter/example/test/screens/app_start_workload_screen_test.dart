import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter_example/screens/app_start_workload_screen.dart';

void main() {
  group('$AppStartWorkloadSection', () {
    testWidgets('lays out offscreen products when build work is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppStartWorkloadSection(
            prolongBuild: true,
            prolongRaster: false,
          ),
        ),
      );
      expect(
        find.text('Product 1799 — price and availability'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('omits catalog work when only raster work is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppStartWorkloadSection(
            prolongBuild: false,
            prolongRaster: true,
          ),
        ),
      );
      expect(find.text('Product 1799 — price and availability'), findsNothing);
      expect(find.text('Product 0 — price and availability'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
