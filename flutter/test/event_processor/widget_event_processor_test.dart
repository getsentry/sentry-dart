import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/event_processor/widget_event_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  testWidgets('adds screenshot attachment dart:io', (tester) async {
    await tester.runAsync(() async {
      final sut = fixture.getSut();
      await tester.pumpWidget(
        SentryWidget(
          child: Text(
            'Catching Pokémon is a snap!',
            textDirection: TextDirection.ltr,
          ),
        ),
      );

      final throwable = Exception();
      SentryEvent? event = SentryEvent(throwable: throwable);
      event = event.copyWith(
        contexts: event.contexts.copyWith(
          app: SentryApp(),
        ),
      );
      event = await sut.apply(event, Hint());

      expect(event?.contexts.app?.textScale, 1.0);
    });
  });
}

class Fixture {
  WidgetEventProcessor getSut() {
    return WidgetEventProcessor();
  }
}
