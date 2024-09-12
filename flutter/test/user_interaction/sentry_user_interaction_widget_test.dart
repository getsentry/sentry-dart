@TestOn('vm')
library flutter_test;
// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry/src/sentry_tracer.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;
  setUp(() async {
    fixture = Fixture();
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets(
    '$SentryUserInteractionWidget does not throw cast exception when Sentry is disabled',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          SentryUserInteractionWidget(
            child: MaterialApp(),
          ),
        );
      });
    },
  );

  testWidgets(
    '$SentryUserInteractionWidget does not apply when enableUserInteractionTracing and enableUserInteractionBreadcrumbs is false',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          fixture.getSut(
            enableUserInteractionTracing: false,
            enableUserInteractionBreadcrumbs: false,
          ),
        );
        final specificChildFinder = find.byType(MyApp);

        expect(
          find.ancestor(
            of: specificChildFinder,
            matching: find.byType(Listener),
          ),
          findsNothing,
        );
      });
    },
  );

  testWidgets(
    '$SentryUserInteractionWidget does apply when enableUserInteractionTracing is true',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          fixture.getSut(
            enableUserInteractionTracing: true,
            enableUserInteractionBreadcrumbs: false,
          ),
        );
        final specificChildFinder = find.byType(MyApp);

        expect(
          find.ancestor(
            of: specificChildFinder,
            matching: find.byType(Listener),
          ),
          findsOne,
        );
      });
    },
  );

  testWidgets(
    '$SentryUserInteractionWidget does apply when enableUserInteractionBreadcrumbs is true',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          fixture.getSut(
            enableUserInteractionTracing: false,
            enableUserInteractionBreadcrumbs: true,
          ),
        );
        final specificChildFinder = find.byType(MyApp);

        expect(
          find.ancestor(
            of: specificChildFinder,
            matching: find.byType(Listener),
          ),
          findsOne,
        );
      });
    },
  );

  group('$SentryUserInteractionWidget crumbs', () {
    testWidgets('Add crumb for MaterialButton', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut();

        await tapMe(tester, sut, 'btn_1');

        expect(
            fixture.getBreadcrumb().data?.replaceHashCodes(),
            equals({
              'path': [
                {'name': 'btn_1', 'element': 'MaterialButton'},
                {'element': 'Column'},
                {'element': 'Center'},
                {'name': '[GlobalKey#00000]', 'element': 'KeyedSubtree'},
                {'element': 'MediaQuery'},
                {'name': '_ScaffoldSlot.body', 'element': 'LayoutId'},
                {'element': 'CustomMultiChildLayout'},
                {'element': 'Actions'},
                {'element': 'AnimatedBuilder'},
                {'element': 'DefaultTextStyle'}
              ],
              'view.id': 'btn_1',
              'view.class': 'MaterialButton',
            }));
      });
    });

    testWidgets('Add crumb for MaterialButton with label', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(sendDefaultPii: true);

        await tapMe(tester, sut, 'btn_1');

        expect(
            fixture.getBreadcrumb().data?.replaceHashCodes(),
            equals({
              'path': [
                {'name': 'btn_1', 'element': 'MaterialButton'},
                {'element': 'Column'},
                {'element': 'Center'},
                {'name': '[GlobalKey#00000]', 'element': 'KeyedSubtree'},
                {'element': 'MediaQuery'},
                {'name': '_ScaffoldSlot.body', 'element': 'LayoutId'},
                {'element': 'CustomMultiChildLayout'},
                {'element': 'Actions'},
                {'element': 'AnimatedBuilder'},
                {'element': 'DefaultTextStyle'}
              ],
              'label': 'Button 1',
              'view.id': 'btn_1',
              'view.class': 'MaterialButton'
            }));
      });
    });

    testWidgets('Add crumb for Icon with label', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(sendDefaultPii: true);

        await tapMe(tester, sut, 'btn_3');

        expect(
            fixture.getBreadcrumb().data?.replaceHashCodes(),
            equals({
              'path': [
                {'name': 'btn_3', 'element': 'IconButton'},
                {'element': 'Column'},
                {'element': 'Center'},
                {'name': '[GlobalKey#00000]', 'element': 'KeyedSubtree'},
                {'element': 'MediaQuery'},
                {'name': '_ScaffoldSlot.body', 'element': 'LayoutId'},
                {'element': 'CustomMultiChildLayout'},
                {'element': 'Actions'},
                {'element': 'AnimatedBuilder'},
                {'element': 'DefaultTextStyle'}
              ],
              'label': 'My Icon',
              'view.id': 'btn_3',
              'view.class': 'IconButton'
            }));
      });
    });

    testWidgets('Add crumb for CupertinoButton with label', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(sendDefaultPii: true);

        await tapMe(tester, sut, 'btn_2');

        expect(
            fixture.getBreadcrumb().data?.replaceHashCodes(),
            equals({
              'path': [
                {'name': 'btn_2', 'element': 'CupertinoButton'},
                {'element': 'Column'},
                {'element': 'Center'},
                {'name': '[GlobalKey#00000]', 'element': 'KeyedSubtree'},
                {'element': 'MediaQuery'},
                {'name': '_ScaffoldSlot.body', 'element': 'LayoutId'},
                {'element': 'CustomMultiChildLayout'},
                {'element': 'Actions'},
                {'element': 'AnimatedBuilder'},
                {'element': 'DefaultTextStyle'}
              ],
              'label': 'Button 2',
              'view.id': 'btn_2',
              'view.class': 'CupertinoButton'
            }));
      });
    });

    testWidgets('Do not add crumb if disabled', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(enableUserInteractionBreadcrumbs: false);

        await tapMe(tester, sut, 'btn_1');

        List<Breadcrumb>? crumbs;
        fixture.hub.configureScope((scope) {
          crumbs = scope.breadcrumbs;
        });
        expect(crumbs?.isEmpty, true);
      });
    });

    testWidgets(
        'Add crumb for ElevatedButton within a GestureDetector with label',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(sendDefaultPii: true);

        await tapMe(tester, sut, 'btn_5');

        expect(
            fixture.getBreadcrumb().data?.replaceHashCodes(),
            equals({
              'path': [
                {'name': 'btn_5', 'element': 'ButtonStyleButton'},
                {'element': 'Stack'},
                {'element': 'Listener'},
                {'element': 'RawGestureDetector'},
                {'name': 'btn_4', 'element': 'GestureDetector'},
                {'element': 'Semantics'},
                {'element': 'DefaultTextStyle'},
                {'element': 'AnimatedDefaultTextStyle'},
                {'element': 'NotificationListener<LayoutChangedNotification>'},
                {'element': 'CustomPaint'}
              ],
              'label': 'Button 5',
              'view.id': 'btn_5',
              'view.class': 'ButtonStyleButton'
            }));
      });
    });

    testWidgets('Add crumb for PopupMenuButton', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut();

        await tapMe(tester, sut, 'popup_menu_button');

        expect(
            fixture.getBreadcrumb().data?.replaceHashCodes(),
            equals({
              'path': [
                {'name': 'popup_menu_button', 'element': 'PopupMenuButton'},
                {'element': 'Column'},
                {'element': 'Center'},
                {'name': '[GlobalKey#00000]', 'element': 'KeyedSubtree'},
                {'element': 'MediaQuery'},
                {'name': '_ScaffoldSlot.body', 'element': 'LayoutId'},
                {'element': 'CustomMultiChildLayout'},
                {'element': 'Actions'},
                {'element': 'AnimatedBuilder'},
                {'element': 'DefaultTextStyle'}
              ],
              'view.id': 'popup_menu_button',
              'view.class': 'PopupMenuButton'
            }));
      });
    });

    testWidgets('Add crumb for PopupMenuItem', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut();

        // open the popup menu and wait for the animation to complete
        await tapMe(tester, sut, 'popup_menu_button');
        await tester.pumpAndSettle();

        await tapMe(tester, sut, 'popup_menu_item_1');

        expect(
            fixture.getBreadcrumb().data?.replaceHashCodes(),
            equals({
              'path': [
                {'name': 'popup_menu_item_1', 'element': 'PopupMenuItem'},
                {'name': '[GlobalKey#00000]', 'element': 'FadeTransition'},
                {'element': 'ListBody'},
                {'element': 'Padding'},
                {'name': '[GlobalKey#00000]', 'element': 'IgnorePointer'},
                {'element': 'Semantics'},
                {'element': 'Listener'},
                {
                  'name': '[LabeledGlobalKey<RawGestureDetectorState>#00000]',
                  'element': 'RawGestureDetector'
                },
                {'element': 'Listener'},
                {'element': 'NotificationListener<ScrollMetricsNotification>'}
              ],
              'view.id': 'popup_menu_item_1',
              'view.class': 'PopupMenuItem'
            }));
      });
    });

    testWidgets('Add crumb for button with tooltip', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(sendDefaultPii: true);

        // open the popup menu and wait for the animation to complete
        await tapMe(tester, sut, 'tooltip_button');

        expect(
            fixture.getBreadcrumb().data?.replaceHashCodes(),
            equals({
              'path': [
                {'name': 'tooltip_button', 'element': 'ButtonStyleButton'},
                {'element': 'Semantics'},
                {'element': 'Listener'},
                {'element': 'OverlayPortal'},
                {'element': 'Tooltip', 'label': 'Tooltip message.'},
                {'element': 'Column'},
                {'element': 'Center'},
                {'name': '[GlobalKey#00000]', 'element': 'KeyedSubtree'},
                {'element': 'MediaQuery'},
                {'name': '_ScaffoldSlot.body', 'element': 'LayoutId'}
              ],
              'label': 'Button text',
              'view.id': 'tooltip_button',
              'view.class': 'ButtonStyleButton'
            }));
      });
    });

    testWidgets('Add crumb for button without key', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(sendDefaultPii: true);

        await tester.pumpWidget(sut);
        await tester.tap(find.byElementPredicate((element) {
          final widget = element.widget;
          if (widget is MaterialButton) {
            return (widget.child as Text).data == 'Button 5';
          }
          return false;
        }));

        expect(
            fixture.getBreadcrumb().data?.replaceHashCodes(),
            equals({
              'path': [
                {'element': 'MaterialButton'},
                {'element': 'Column'},
                {'element': 'Center'},
                {'name': '[GlobalKey#00000]', 'element': 'KeyedSubtree'},
                {'element': 'MediaQuery'},
                {'name': '_ScaffoldSlot.body', 'element': 'LayoutId'},
                {'element': 'CustomMultiChildLayout'},
                {'element': 'Actions'},
                {'element': 'AnimatedBuilder'},
                {'element': 'DefaultTextStyle'}
              ],
              'label': 'Button 5',
              'view.class': 'MaterialButton'
            }));
      });
    });
  });

  group('$SentryUserInteractionWidget performance', () {
    late Fixture fixture;
    setUp(() async {
      fixture = Fixture();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('Adds integration if enabled', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(
            enableUserInteractionTracing: true,
            enableUserInteractionBreadcrumbs: false);

        await tester.pumpWidget(sut);

        expect(
            fixture._options.sdk.integrations
                .contains('UserInteractionTracing'),
            true);
      });
    });

    testWidgets('Do not add integration if disabled', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(enableUserInteractionBreadcrumbs: false);

        await tester.pumpWidget(sut);

        expect(
            fixture._options.sdk.integrations
                .contains('UserInteractionTracing'),
            false);
      });
    });

    testWidgets('Start transaction and set in the scope', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(
            enableUserInteractionTracing: true,
            enableUserInteractionBreadcrumbs: false);

        await tapMe(tester, sut, 'btn_1');

        SentryTracer? tracer;
        fixture.hub.configureScope((scope) {
          tracer = (scope.span as SentryTracer);
        });
        expect(tracer?.name, 'btn_1');
        expect(tracer?.context.operation, 'ui.action.click');
        expect(tracer?.transactionNameSource,
            SentryTransactionNameSource.component);
        expect(tracer?.autoFinishAfterTimer, isNotNull);
      });
    });

    testWidgets('Start transaction and do not set in the scope if any',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(
            enableUserInteractionTracing: true,
            enableUserInteractionBreadcrumbs: false);

        fixture.hub.configureScope((scope) {
          scope.span = NoOpSentrySpan();
        });

        await tapMe(tester, sut, 'btn_1');

        ISentrySpan? span;
        fixture.hub.configureScope((scope) {
          span = scope.span;
        });
        expect(span, NoOpSentrySpan());
      });
    });

    testWidgets('Extend timer if transaction already started for same widget',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(
            enableUserInteractionTracing: true,
            enableUserInteractionBreadcrumbs: false);

        await tapMe(tester, sut, 'btn_1');
        Timer? currentTimer;

        fixture.hub.configureScope((scope) {
          final tracer = (scope.span as SentryTracer);
          currentTimer = tracer.autoFinishAfterTimer;
        });

        await tapMe(tester, sut, 'btn_1', pumpWidget: false);

        Timer? autoFinishAfterTimer;
        fixture.hub.configureScope((scope) {
          final tracer = (scope.span as SentryTracer);
          autoFinishAfterTimer = tracer.autoFinishAfterTimer;
        });
        expect(currentTimer, isNot(equals(autoFinishAfterTimer)));
      });
    });

    testWidgets('Finish transaction and start new one if new tap',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(
            enableUserInteractionTracing: true,
            enableUserInteractionBreadcrumbs: false);

        await tapMe(tester, sut, 'btn_1');
        SentryTracer? currentTracer;

        fixture.hub.configureScope((scope) {
          currentTracer = (scope.span as SentryTracer);
        });

        await tapMe(tester, sut, 'btn_2', pumpWidget: false);

        SentryTracer? tracer;
        fixture.hub.configureScope((scope) {
          tracer = (scope.span as SentryTracer);
        });
        expect(currentTracer, isNot(equals(tracer)));
      });
    });
  });
}

Future<void> tapMe(
  WidgetTester tester,
  Widget widget,
  String key, {
  bool pumpWidget = true,
}) async {
  if (pumpWidget) {
    await tester.pumpWidget(widget);
  }
  await tester.tap(find.byKey(Key(key)));
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

  Breadcrumb getBreadcrumb() {
    late final Breadcrumb crumb;
    hub.configureScope((scope) {
      crumb = scope.breadcrumbs.last;
    });
    return crumb;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welcome to Flutter',
      home: Page1(),
      routes: {'page2': (context) => const Page2()},
    );
  }
}

class Page1 extends StatelessWidget {
  const Page1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            MaterialButton(
              key: Key('btn_1'),
              onPressed: () {},
              child: const Text('Button 1'),
            ),
            CupertinoButton(
              key: Key('btn_2'),
              onPressed: () {},
              child: const Text('Button 2'),
            ),
            IconButton(
              key: Key('btn_3'),
              onPressed: () {},
              icon: Icon(
                Icons.dark_mode,
                semanticLabel: 'My Icon',
              ),
            ),
            Card(
              child: GestureDetector(
                key: Key('btn_4'),
                onTap: () => {},
                child: Stack(
                  children: [
                    //fancy card layout
                    ElevatedButton(
                      key: Key('btn_5'),
                      onPressed: () => {},
                      child: const Text('Button 5'),
                    ),
                  ],
                ),
              ),
            ),
            MaterialButton(
              key: Key('btn_go_to_page2'),
              onPressed: () {
                Navigator.of(context).pushNamed('page2');
              },
              child: const Text('Go to page 2'),
            ),
            PopupMenuButton(
              key: ValueKey('popup_menu_button'),
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  key: ValueKey('popup_menu_item_1'),
                  child: Text('first item'),
                ),
              ],
            ),
            Tooltip(
              message: 'Tooltip message.',
              child: ElevatedButton(
                key: ValueKey('tooltip_button'),
                onPressed: () {},
                child: Text('Button text'),
              ),
            ),
            MaterialButton(
              onPressed: () {},
              child: const Text('Button 5'),
            ),
          ],
        ),
      ),
    );
  }
}

class Page2 extends StatelessWidget {
  const Page2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            MaterialButton(
              key: Key('btn_page_2'),
              onPressed: () {},
              child: const Text('Button Page 2'),
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String replaceHashCodes() => replaceAll(RegExp(r'#[\da-fA-F]{5}'), '#00000');
}

extension on Map<dynamic, dynamic> {
  Map<dynamic, dynamic> replaceHashCodes() => map((key, value) {
        if (value is String) {
          value = value.replaceHashCodes();
        } else if (value is Map) {
          value = value.replaceHashCodes();
        } else if (value is List) {
          value = value.replaceHashCodes();
        }
        return MapEntry(key, value);
      });
}

extension on List<dynamic> {
  Iterable<dynamic> replaceHashCodes() => map((value) {
        if (value is String) {
          return value.replaceHashCodes();
        } else if (value is Map) {
          return value.replaceHashCodes();
        } else if (value is List) {
          return value.replaceHashCodes();
        } else {
          return value;
        }
      });
}
