import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter_example/home_screen.dart';
import 'package:sentry_flutter_example/theme_provider.dart';

void main() {
  group('$HomeScreen', () {
    testWidgets(
      'lays out startup work below the category cards on the first frame',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(),
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        expect(find.text('Sentry Flutter Example'), findsOneWidget);
        expect(find.text('Errors'), findsOneWidget);
        expect(find.text('Performance'), findsOneWidget);
        expect(find.text('Manual Replay'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('App-start workloads')).dy,
          greaterThan(600),
        );
        expect(
          tester
              .getSize(find.text('Product 1799 — price and availability'))
              .height,
          greaterThan(0),
        );
        expect(find.byType(SwitchListTile), findsNothing);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();
        expect(find.text('App-start workloads').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
