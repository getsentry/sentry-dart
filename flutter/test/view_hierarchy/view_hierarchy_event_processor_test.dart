import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/binding_wrapper.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';
import 'package:sentry_flutter/src/view_hierarchy/view_hierarchy_event_processor.dart';

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

        sut.apply(event, hint);

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

        sut.apply(event, hint);

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

        sut.apply(event, hint);

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

        sut.apply(event, hint);

        expect(hint.viewHierarchy, isNull);
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
  SentryViewHierarchyEventProcessor getSut(WidgetsBinding instance) {
    final options = SentryFlutterOptions()
      ..bindingUtils = TestBindingWrapper(instance);
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
