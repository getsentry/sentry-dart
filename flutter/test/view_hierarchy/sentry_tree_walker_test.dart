import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/view_hierarchy/sentry_tree_walker.dart';

void main() {
  group('TreeWalker', () {
    late WidgetsBinding instance;

    setUp(() {
      instance = TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('returns a SentryViewHierarchy with flutter render',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MyApp());

        final sentryViewHierarchy = walkWidgetTree(instance);

        expect(sentryViewHierarchy!.renderingSystem, 'flutter');
      });
    });

    testWidgets('returns a SentryViewHierarchyElement with a type',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MyApp());

        final first = _getFirstSentryViewHierarchy(instance);

        expect(
            true,
            _findWidget(first, (element) {
              return element.type == 'MaterialApp';
            }));
      });
    });

    testWidgets('returns a SentryViewHierarchyElement with a depth',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MyApp());

        final first = _getFirstSentryViewHierarchy(instance);

        expect(
            true,
            _findWidget(first, (element) {
              return element.depth != null;
            }));
      });
    });

    testWidgets('returns a SentryViewHierarchyElement with a identifier',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MyApp());

        final first = _getFirstSentryViewHierarchy(instance);

        expect(
            true,
            _findWidget(first, (element) {
              return element.identifier == 'btn_1';
            }));
      });
    });

    testWidgets('returns a SentryViewHierarchyElement with X and Y',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MyApp());

        final first = _getFirstSentryViewHierarchy(instance);

        expect(
            true,
            _findWidget(first, (element) {
              return element.x != null && element.y != null;
            }));
      });
    });

    testWidgets('returns a SentryViewHierarchyElement with visibility',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MyApp());

        final first = _getFirstSentryViewHierarchy(instance);

        expect(
            true,
            _findWidget(first, (element) {
              return element.visible == true;
            }));
      });
    });

    testWidgets(
        'does not return a SentryViewHierarchyElement without visibility',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MyApp());

        final first = _getFirstSentryViewHierarchy(instance);

        expect(
            false,
            _findWidget(first, (element) {
              return element.visible == false;
            }));
      });
    });

    testWidgets('returns a SentryViewHierarchyElement with alpha',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MyApp());

        final first = _getFirstSentryViewHierarchy(instance);

        expect(
            true,
            _findWidget(first, (element) {
              return element.alpha == 0.5;
            }));
      });
    });

    testWidgets('does not return a SentryViewHierarchyElement with private key',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MyApp());

        final first = _getFirstSentryViewHierarchy(instance);

        expect(
            false,
            _findWidget(first, (element) {
              return element.identifier == '_btn_3';
            }));
      });
    });
  });
}

SentryViewHierarchyElement _getFirstSentryViewHierarchy(
    WidgetsBinding instance) {
  final sentryViewHierarchy = walkWidgetTree(instance);

  return sentryViewHierarchy!.windows.first;
}

bool _findWidget(
  SentryViewHierarchyElement element,
  bool Function(SentryViewHierarchyElement element) predicate,
) {
  if (predicate(element)) {
    return true;
  }

  if (element.children.isNotEmpty) {
    for (final child in element.children) {
      if (_findWidget(child, predicate)) {
        return true;
      }
    }
  }

  return false;
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
        body: Center(
          child: Column(
            children: [
              MaterialButton(
                key: Key('btn_1'),
                onPressed: () {},
                child: const Text('Button 1'),
              ),
              MaterialButton(
                  key: Key('btn_2'),
                  onPressed: () {},
                  child: Visibility(
                    key: Key('btn_2_visibility'),
                    visible: true,
                    child: Opacity(
                      key: Key('btn_2_opacity'),
                      opacity: 0.5,
                      child: const Text('Button 2'),
                    ),
                  )),
              MaterialButton(
                key: Key('_btn_3'),
                onPressed: () {},
                child: const Text('Button 3'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
