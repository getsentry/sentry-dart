@TestOn('vm')
library;
// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry/src/sentry_tracer.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

// The Scaffold widget tree uses AnimatedBuilder on stable but Builder on beta.
// Use anyOf to accept either name since this is a framework-internal detail.
final _animatedBuilderElement = {
  'element': anyOf('AnimatedBuilder', 'Builder')
};

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
                _animatedBuilderElement,
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
                _animatedBuilderElement,
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
                _animatedBuilderElement,
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
                _animatedBuilderElement,
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
                _animatedBuilderElement,
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

        final data = fixture.getBreadcrumb().data?.replaceHashCodes();
        final path = (data?['path'] as Iterable?)?.toList();

        expect(data?['label'], equals('Button text'));
        expect(data?['view.id'], equals('tooltip_button'));
        expect(data?['view.class'], equals('ButtonStyleButton'));
        expect(path?.first,
            equals({'name': 'tooltip_button', 'element': 'ButtonStyleButton'}));
        expect(
            path?.any((element) =>
                element['element'] == 'Tooltip' &&
                element['label'] == 'Tooltip message.'),
            isTrue);
      });
    });

    // Regression test for https://github.com/getsentry/sentry-dart/issues/1208
    testWidgets(
        'Add crumb for button on Page2 not Page1 when pages are stacked',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut();

        await tester.pumpWidget(sut);

        // Navigate to Page2 (Page1 stays behind in the nav stack).
        await tester.tap(find.byKey(Key('btn_go_to_page2')));
        await tester.pumpAndSettle();

        // Page2's btn_page_2 fills the entire screen (SizedBox.expand).
        // Tap at btn_1's center, which is inside both buttons' bounds.
        final btn1Center =
            tester.getCenter(find.byKey(Key('btn_1'), skipOffstage: false));
        await tester.tapAt(btn1Center);

        final data = fixture.getBreadcrumb().data;
        expect(data?['view.id'], equals('btn_page_2'),
            reason: 'Should identify the Page2 button, not the Page1 button '
                'behind it in the navigation stack');
        expect(data?['view.class'], equals('MaterialButton'));
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
                _animatedBuilderElement,
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

    testWidgets(
        'Cancel transaction if already started for same widget and start new one',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(
            enableUserInteractionTracing: true,
            enableUserInteractionBreadcrumbs: false);

        await tapMe(tester, sut, 'btn_1');
        SentryTracer? initialTracer;

        fixture.hub.configureScope((scope) {
          initialTracer = (scope.span as SentryTracer);
        });

        await tapMe(tester, sut, 'btn_1');

        SentryTracer? tracer;
        fixture.hub.configureScope((scope) {
          tracer = (scope.span as SentryTracer);
        });
        expect(initialTracer?.finished, isTrue);
        expect(initialTracer?.status, equals(SpanStatus.cancelled()));

        expect(initialTracer, isNot(equals(tracer)));
      });
    });

    testWidgets(
        'Finish transaction if already started with children for same widget and start new one',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(
            enableUserInteractionTracing: true,
            enableUserInteractionBreadcrumbs: false);

        await tapMe(tester, sut, 'btn_1');
        SentryTracer? initialTracer;

        await fixture.hub.configureScope((scope) async {
          initialTracer = (scope.span as SentryTracer);
          final child = initialTracer?.startChild("btn_1_child");
          await child?.finish();
        });

        await tapMe(tester, sut, 'btn_1');

        SentryTracer? tracer;
        fixture.hub.configureScope((scope) {
          tracer = (scope.span as SentryTracer);
        });
        expect(initialTracer?.finished, isTrue);
        expect(initialTracer, isNot(equals(tracer)));
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

  group('$SentryUserInteractionWidget spanV2', () {
    late Fixture fixture;
    setUp(() async {
      fixture = Fixture();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('starts idle span on tap', (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(
          enableUserInteractionTracing: true,
          enableUserInteractionBreadcrumbs: false,
          traceLifecycle: SentryTraceLifecycle.streaming,
        );

        await tapMe(tester, sut, 'btn_1');

        final activeSpan = fixture.hub.getActiveSpan();
        expect(activeSpan, isA<IdleRecordingSentrySpanV2>());
        expect(activeSpan?.name, 'btn_1');
        expect(
          activeSpan?.attributes[SemanticAttributesConstants.sentryOp]?.value,
          SentrySpanOperations.uiActionClick,
        );
      });
    });

    testWidgets('does not start idle span when ui.load span is active',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(
          enableUserInteractionTracing: true,
          enableUserInteractionBreadcrumbs: false,
          traceLifecycle: SentryTraceLifecycle.streaming,
        );

        // Start a ui.load idle span before tapping
        fixture.hub.startIdleSpan(
          'ui.load',
          attributes: {
            SemanticAttributesConstants.sentryOp:
                SentryAttribute.string(SentrySpanOperations.uiLoad),
          },
        );
        final loadSpan = fixture.hub.getActiveSpan();
        expect(loadSpan, isA<IdleRecordingSentrySpanV2>());

        await tapMe(tester, sut, 'btn_1');

        // The ui.load span should still be the active one (not replaced)
        expect(fixture.hub.getActiveSpan(), same(loadSpan));
      });
    });

    testWidgets('resets idle timer when same widget is tapped again',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(
          enableUserInteractionTracing: true,
          enableUserInteractionBreadcrumbs: false,
          traceLifecycle: SentryTraceLifecycle.streaming,
        );

        await tapMe(tester, sut, 'btn_1');
        final firstSpan = fixture.hub.getActiveSpan();
        expect(firstSpan, isA<IdleRecordingSentrySpanV2>());

        // Tap same widget again
        await tapMe(tester, sut, 'btn_1');

        // Should still be the same span (not a new one)
        expect(fixture.hub.getActiveSpan(), same(firstSpan));
        expect(firstSpan?.isEnded, isFalse);
      });
    });

    testWidgets(
        'cancels previous idle span when tapping different widget after activity',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(
          enableUserInteractionTracing: true,
          enableUserInteractionBreadcrumbs: false,
          traceLifecycle: SentryTraceLifecycle.streaming,
        );

        await tapMe(tester, sut, 'btn_1');
        final firstSpan = fixture.hub.getActiveSpan();
        expect(firstSpan, isA<IdleRecordingSentrySpanV2>());

        // Simulate descendant activity by starting a child span
        fixture.hub.startSpanSync('child-work', (span) {});

        await Future<void>.delayed(Duration.zero);
        // Tap a different widget
        await tapMe(tester, sut, 'btn_2', pumpWidget: false);

        // First span should be cancelled
        expect(firstSpan!.isEnded, isTrue);
        expect(firstSpan.status, SentrySpanStatusV2.cancelled);

        // New idle span should be started for btn_2
        final newSpan = fixture.hub.getActiveSpan();
        expect(newSpan, isA<IdleRecordingSentrySpanV2>());
        expect(newSpan?.name, 'btn_2');
      });
    });
  });

  // Regression tests for https://github.com/getsentry/sentry-dart/issues/3503
  group('$SentryUserInteractionWidget tap distortion', () {
    testWidgets(
      'does not re-trigger hitTest on descendant render objects during pointerUp',
      (tester) async {
        final hitTestPositions = <Offset>[];
        final hitNotifier = ValueNotifier<Offset?>(null);

        await tester.pumpWidget(fixture.getSut(
          child: MaterialApp(
            home: Scaffold(
              body: GestureDetector(
                onTap: () {},
                child: HitTestTracker(
                  hitTestPositions: hitTestPositions,
                  hitNotifier: hitNotifier,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ));

        hitTestPositions.clear();

        final center = tester.getCenter(find.byType(SizedBox).last);
        final gesture = await tester.startGesture(center);
        await tester.pump();

        final hitTestCountAfterDown = hitTestPositions.length;

        await gesture.up();
        await tester.pumpAndSettle();

        expect(hitTestPositions.length, equals(hitTestCountAfterDown),
            reason: 'SentryUserInteractionWidget should not re-trigger '
                'hitTest on pointerUp');
      },
    );

    testWidgets(
      'does not overwrite hitNotifier value that was set during pointerDown',
      (tester) async {
        final hitTestPositions = <Offset>[];
        final hitNotifier = ValueNotifier<Offset?>(null);

        await tester.pumpWidget(fixture.getSut(
          child: MaterialApp(
            home: Scaffold(
              body: GestureDetector(
                onTap: () {},
                child: HitTestTracker(
                  hitTestPositions: hitTestPositions,
                  hitNotifier: hitNotifier,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ));

        final center = tester.getCenter(find.byType(SizedBox).last);
        final gesture = await tester.startGesture(center);
        await tester.pump();

        expect(hitNotifier.value, isNotNull);

        hitNotifier.value = null;

        await gesture.up();
        await tester.pumpAndSettle();

        expect(hitNotifier.value, isNull,
            reason: 'SentryUserInteractionWidget should not overwrite '
                'hitNotifier during pointerUp');
      },
    );
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
  final _options = defaultTestOptions();
  final _transport = MockTransport();
  late Hub hub;

  SentryUserInteractionWidget getSut({
    bool enableUserInteractionTracing = false,
    bool enableUserInteractionBreadcrumbs = true,
    double? tracesSampleRate = 1.0,
    bool sendDefaultPii = false,
    SentryTraceLifecycle? traceLifecycle,
    Widget? child,
  }) {
    // Missing mock exception
    when(_transport.send(any)).thenAnswer((_) async => SentryId.newId());

    _options.transport = _transport;
    _options.tracesSampleRate = tracesSampleRate;
    _options.enableUserInteractionTracing = enableUserInteractionTracing;
    _options.enableUserInteractionBreadcrumbs =
        enableUserInteractionBreadcrumbs;
    _options.sendDefaultPii = sendDefaultPii;
    if (traceLifecycle != null) {
      _options.traceLifecycle = traceLifecycle;
    }

    hub = Hub(_options);

    return SentryUserInteractionWidget(
      hub: hub,
      child: child ?? MyApp(),
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
      body: SizedBox.expand(
        child: MaterialButton(
          key: Key('btn_page_2'),
          onPressed: () {},
          child: const Text('Button Page 2'),
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

/// A widget whose [RenderBox] records every [hitTest] call and updates a
/// [ValueNotifier] — mimicking flutter_map's `LayerHitNotifier` pattern
/// where state is set during hit testing.
class HitTestTracker extends SingleChildRenderObjectWidget {
  const HitTestTracker({
    required this.hitTestPositions,
    required this.hitNotifier,
    super.child,
    super.key,
  });

  final List<Offset> hitTestPositions;
  final ValueNotifier<Offset?> hitNotifier;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderHitTestTracker(
      hitTestPositions: hitTestPositions,
      hitNotifier: hitNotifier,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderHitTestTracker renderObject) {
    renderObject
      ..hitTestPositions = hitTestPositions
      ..hitNotifier = hitNotifier;
  }
}

class RenderHitTestTracker extends RenderProxyBox {
  RenderHitTestTracker({
    required List<Offset> hitTestPositions,
    required ValueNotifier<Offset?> hitNotifier,
  })  : _hitTestPositions = hitTestPositions,
        _hitNotifier = hitNotifier;

  List<Offset> _hitTestPositions;
  set hitTestPositions(List<Offset> value) => _hitTestPositions = value;

  ValueNotifier<Offset?> _hitNotifier;
  set hitNotifier(ValueNotifier<Offset?> value) => _hitNotifier = value;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    _hitTestPositions.add(position);
    _hitNotifier.value = position;
    return super.hitTest(result, position: position);
  }
}
