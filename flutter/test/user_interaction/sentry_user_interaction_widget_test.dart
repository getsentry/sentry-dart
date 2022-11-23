import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group('$SentryUserInteractionWidget crumbs', () {
    late Fixture fixture;
    setUp(() async {
      fixture = Fixture();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('Add crumb for MaterialButton', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut();

        await tapMe(tester, sut, 'Button 1');

        fixture.hub.configureScope((scope) {
          final crumb = scope.breadcrumbs.last;
          expect(crumb.category, 'ui.click');
          expect(crumb.data?['view.id'], 'btn_1');
          expect(crumb.data?['view.class'], 'MaterialButton');
        });
      });
    });

    testWidgets('Add crumb for MaterialButton with label', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(sendDefaultPii: true);

        await tapMe(tester, sut, 'Button 1');

        fixture.hub.configureScope((scope) {
          final crumb = scope.breadcrumbs.last;
          expect(crumb.data?['label'], 'Button 1');
        });
      });
    });

    testWidgets('Do not add crumb', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(enableUserInteractionBreadcrumbs: false);

        await tapMe(tester, sut, 'Button 1');

        fixture.hub.configureScope((scope) {
          expect(scope.breadcrumbs.isEmpty, true);
        });
      });
    });
  });
}

Future<void> tapMe(WidgetTester tester, Widget widget, String text) async {
  await tester.pumpWidget(widget);

  await tester.tap(find.text(text));
}

class Fixture {
  final _options = SentryFlutterOptions(dsn: fakeDsn);
  final _transport = MockTransport();
  late Hub hub;

  SentryUserInteractionWidget getSut({
    bool enableUserInteractionTracing = false,
    bool enableUserInteractionBreadcrumbs = true,
    double? tracesSampleRate = 1.0,
    bool sendDefaultPii = false,
  }) {
    _options.transport = _transport;
    _options.tracesSampleRate = tracesSampleRate;
    _options.enableUserInteractionTracing = enableUserInteractionTracing;
    _options.enableUserInteractionBreadcrumbs =
        enableUserInteractionBreadcrumbs;
    _options.sendDefaultPii = sendDefaultPii;

    hub = Hub(_options);

    return SentryUserInteractionWidget(
      hub: hub,
      child: MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welcome to Flutter',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Welcome to Flutter'),
        ),
        body: Center(
          child: Column(
            children: [
              MaterialButton(
                key: Key('btn_1'),
                onPressed: () {
                  // print('button pressed');
                },
                child: const Text('Button 1'),
              ),
              MaterialButton(
                key: Key('btn_2'),
                onPressed: () {
                  // print('button pressed 2');
                },
                child: const Text('Button 2'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
