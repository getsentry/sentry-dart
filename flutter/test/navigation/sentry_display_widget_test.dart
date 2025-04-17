import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/navigation/sentry_display_widget.dart';

import '../mocks.mocks.dart';

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

void main() {
  late Fixture fixture;

  PageRoute<dynamic> route(RouteSettings? settings) => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => Container(),
        settings: settings,
      );

  setUp(() async {
    fixture = Fixture();
    await SentryFlutter.init(
      (options) async {
        options.dsn = fakeDsn;
        options.timeToDisplayTracker = fixture.mockTimeToDisplayTracker;
      },
    );
  });

  tearDown(() async {
    await Sentry.close();
  });

  testWidgets(
      '$SentryDisplayWidget reports display with current route name when child calls reportFullDisplay',
      (WidgetTester tester) async {
    const testRouteName = 'test-route';
    final testRoute = route(RouteSettings(name: testRouteName));
    fixture.navigatorObserver.didPush(testRoute, null);

    await tester.pumpWidget(
      MaterialApp(
        home: SentryDisplayWidget(
          child: Builder(
            builder: (context) {
              SentryDisplayWidget.of(context).reportFullyDisplayed();
              return const Text('Test');
            },
          ),
        ),
      ),
    );

    verify(fixture.mockTimeToDisplayTracker
            .reportFullyDisplayed(routeName: testRouteName))
        .called(1);
  });
}

class Fixture {
  late MockTimeToDisplayTracker mockTimeToDisplayTracker;
  late SentryNavigatorObserver navigatorObserver;

  Fixture() {
    mockTimeToDisplayTracker = MockTimeToDisplayTracker();
    when(mockTimeToDisplayTracker.reportFullyDisplayed(
            routeName: anyNamed('routeName')))
        .thenAnswer((_) => Future<void>.value());
    navigatorObserver = SentryNavigatorObserver(
      hub: HubAdapter(),
      autoFinishAfter: const Duration(seconds: 1),
    );
  }
}
