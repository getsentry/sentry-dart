import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/binding_wrapper.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';
import 'package:sentry_flutter/src/view_hierarchy/view_hierarchy_event_processor.dart';

import '../mocks.dart';

void main() {
  group(SentryViewHierarchyEventProcessor, () {
    late Fixture fixture;
    late WidgetsBinding instance;

    setUp(() {
      fixture = Fixture();
      instance = TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('adds view hierarchy to hint only for event with exception',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(instance);

        await tester.pumpWidget(MyApp());

        final event = SentryEvent(
            exceptions: [SentryException(type: 'type', value: 'value')]);
        final hint = Hint();

        await sut.apply(event, hint);

        expect(hint.viewHierarchy, isNotNull);
      });
    });

    testWidgets('adds view hierarchy to hint only for event with throwable',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(instance);

        await tester.pumpWidget(MyApp());

        final event = SentryEvent(throwable: StateError('error'));
        final hint = Hint();

        await sut.apply(event, hint);

        expect(hint.viewHierarchy, isNotNull);
      });
    });

    testWidgets('does not add view hierarchy to hint if not an error',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(instance);

        await tester.pumpWidget(MyApp());

        final event = SentryEvent();
        final hint = Hint();

        await sut.apply(event, hint);

        expect(hint.viewHierarchy, isNull);
      });
    });

    testWidgets('does not add view hierarchy if widget returns null',
        (tester) async {
      await tester.runAsync(() async {
        final sut = fixture.getSut(instance);

        // does not pumpWidget

        final event = SentryEvent();
        final hint = Hint();

        await sut.apply(event, hint);

        expect(hint.viewHierarchy, isNull);
      });
    });

    testWidgets('does not add view hierarchy identifiers if opt out in options',
        (tester) async {
      await tester.runAsync(() async {
        final sut =
            fixture.getSut(instance, reportViewHierarchyIdentifiers: false);

        await tester.pumpWidget(MyApp());

        final event = SentryEvent(
            exceptions: [SentryException(type: 'type', value: 'value')]);
        final hint = Hint();

        await sut.apply(event, hint);

        expect(hint.viewHierarchy, isNotNull);
        final bytes = await hint.viewHierarchy!.bytes;
        final jsonString = utf8.decode(bytes);
        expect(jsonString, isNot(contains('identifier')));
      });
    });

    group('beforeCaptureViewHierarchy', () {
      late SentryEvent event;
      late Hint hint;

      Future<void> _addViewHierarchyAttachment(
        WidgetTester tester, {
        required bool added,
      }) async {
        // Run with real async https://stackoverflow.com/a/54021863
        await tester.runAsync(() async {
          final sut = fixture.getSut(instance);

          await tester.pumpWidget(MyApp());

          final throwable = Exception();
          event = SentryEvent(throwable: throwable);
          hint = Hint();
          await sut.apply(event, hint);

          expect(hint.viewHierarchy != null, added);
        });
      }

      testWidgets('does add view hierarchy if beforeCapture returns true',
          (tester) async {
        fixture.options.beforeCaptureViewHierarchy =
            (SentryEvent event, Hint hint, bool shouldDebounce) {
          return true;
        };
        await _addViewHierarchyAttachment(tester, added: true);
      });

      testWidgets('does add view hierarchy if async beforeCapture returns true',
          (tester) async {
        fixture.options.beforeCaptureViewHierarchy =
            (SentryEvent event, Hint hint, bool shouldDebounce) async {
          await Future<void>.delayed(Duration(milliseconds: 1));
          return true;
        };
        await _addViewHierarchyAttachment(tester, added: true);
      });

      testWidgets('does not add view hierarchy if beforeCapture returns false',
          (tester) async {
        fixture.options.beforeCaptureViewHierarchy =
            (SentryEvent event, Hint hint, bool shouldDebounce) {
          return false;
        };
        await _addViewHierarchyAttachment(tester, added: false);
      });

      testWidgets(
          'does not add view hierarchy if async beforeCapture returns false',
          (tester) async {
        fixture.options.beforeCaptureViewHierarchy =
            (SentryEvent event, Hint hint, bool shouldDebounce) async {
          await Future<void>.delayed(Duration(milliseconds: 1));
          return false;
        };
        await _addViewHierarchyAttachment(tester, added: false);
      });

      testWidgets('does add view hierarchy if beforeCapture throws',
          (tester) async {
        fixture.options.automatedTestMode = false;
        fixture.options.beforeCaptureViewHierarchy =
            (SentryEvent event, Hint hint, bool shouldDebounce) {
          throw Error();
        };
        await _addViewHierarchyAttachment(tester, added: true);
      });

      testWidgets('does add view hierarchy if async beforeCapture throws',
          (tester) async {
        fixture.options.automatedTestMode = false;
        fixture.options.beforeCaptureViewHierarchy =
            (SentryEvent event, Hint hint, bool shouldDebounce) async {
          await Future<void>.delayed(Duration(milliseconds: 1));
          throw Error();
        };
        await _addViewHierarchyAttachment(tester, added: true);
      });

      testWidgets('does add view hierarchy event if shouldDebounce true',
          (tester) async {
        await tester.runAsync(() async {
          var shouldDebounceValues = <bool>[];

          fixture.options.beforeCaptureViewHierarchy =
              (SentryEvent event, Hint hint, bool shouldDebounce) {
            shouldDebounceValues.add(shouldDebounce);
            return true;
          };

          final sut = fixture.getSut(instance);
          await tester.pumpWidget(MyApp());

          final event = SentryEvent(throwable: Exception());
          final hintOne = Hint();
          final hintTwo = Hint();

          await sut.apply(event, hintOne);
          await sut.apply(event, hintTwo);

          expect(hintOne.viewHierarchy, isNotNull);
          expect(hintTwo.viewHierarchy, isNotNull);

          expect(shouldDebounceValues[0], false);
          expect(shouldDebounceValues[1], true);
        });
      });

      testWidgets('passes event & hint to beforeCapture callback',
          (tester) async {
        SentryEvent? beforeScreenshotEvent;
        Hint? beforeScreenshotHint;

        fixture.options.beforeCaptureViewHierarchy =
            (SentryEvent event, Hint hint, bool shouldDebounce) {
          beforeScreenshotEvent = event;
          beforeScreenshotHint = hint;
          return true;
        };

        await _addViewHierarchyAttachment(tester, added: true);

        expect(beforeScreenshotEvent, event);
        expect(beforeScreenshotHint, hint);
      });
    });

    group("debounce", () {
      testWidgets("limits added view hierarchy within debounce timeframe",
          (tester) async {
        // Run with real async https://stackoverflow.com/a/54021863
        await tester.runAsync(() async {
          var firstCall = true;
          // ignore: invalid_use_of_internal_member
          fixture.options.clock = () {
            if (firstCall) {
              firstCall = false;
              return DateTime.fromMillisecondsSinceEpoch(0);
            } else {
              return DateTime.fromMillisecondsSinceEpoch(2000 - 1);
            }
          };

          final sut = fixture.getSut(instance);
          await tester.pumpWidget(MyApp());

          final throwable = Exception();

          final firstEvent = SentryEvent(throwable: throwable);
          final firstHint = Hint();

          final secondEvent = SentryEvent(throwable: throwable);
          final secondHint = Hint();

          await sut.apply(firstEvent, firstHint);
          await sut.apply(secondEvent, secondHint);

          expect(firstHint.viewHierarchy, isNotNull);
          expect(secondHint.viewHierarchy, isNull);
        });
      });

      testWidgets("adds view hierarchy after debounce timeframe",
          (tester) async {
        // Run with real async https://stackoverflow.com/a/54021863
        await tester.runAsync(() async {
          var firstCall = true;
          // ignore: invalid_use_of_internal_member
          fixture.options.clock = () {
            if (firstCall) {
              firstCall = false;
              return DateTime.fromMillisecondsSinceEpoch(0);
            } else {
              return DateTime.fromMillisecondsSinceEpoch(2001);
            }
          };

          final sut = fixture.getSut(instance);
          await tester.pumpWidget(MyApp());

          final throwable = Exception();

          final firstEvent = SentryEvent(throwable: throwable);
          final firstHint = Hint();

          final secondEvent = SentryEvent(throwable: throwable);
          final secondHint = Hint();

          await sut.apply(firstEvent, firstHint);
          await sut.apply(secondEvent, secondHint);

          expect(firstHint.viewHierarchy, isNotNull);
          expect(secondHint.viewHierarchy, isNotNull);
        });
      });
    });
  });
}

class TestBindingWrapper implements BindingWrapper {
  TestBindingWrapper(this._binding);

  final WidgetsBinding _binding;

  @override
  WidgetsBinding ensureInitialized() {
    return TestWidgetsFlutterBinding.ensureInitialized();
  }

  @override
  WidgetsBinding get instance {
    return _binding;
  }
}

class Fixture {
  SentryFlutterOptions options = defaultTestOptions();

  SentryViewHierarchyEventProcessor getSut(WidgetsBinding instance,
      {bool reportViewHierarchyIdentifiers = true}) {
    options
      ..bindingUtils = TestBindingWrapper(instance)
      ..reportViewHierarchyIdentifiers = reportViewHierarchyIdentifiers;
    return SentryViewHierarchyEventProcessor(options);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welcome to Flutter',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Welcome to Flutter'),
        ),
      ),
    );
  }
}
