import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/user_interaction/user_interaction_widget_types.dart';

void main() {
  group('$UserInteractionWidgetTypes', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('nameOf', () {
      test('returns name of added type for widget of that type', () {
        final sut = fixture.getSut()..addWidget<Text>('Text');

        expect(sut.nameOf(const Text('a')), 'Text');
      });

      test('returns name of added type for subclass of that type', () {
        final sut = fixture.getSut()..addWidget<StatelessWidget>('Stateless');

        expect(sut.nameOf(const Text('a')), 'Stateless');
      });

      test('returns null for other widgets', () {
        final sut = fixture.getSut()..addWidget<Text>('Text');

        expect(sut.nameOf(const SizedBox()), isNull);
      });

      test('returns null when isEnabled returns false', () {
        final sut = fixture.getSut()
          ..addWidget<Text>('Text', isEnabled: (widget) => widget.data != 'a');

        expect(sut.nameOf(const Text('a')), isNull);
      });

      test('returns name of first added type that matches', () {
        final sut = fixture.getSut()
          ..addWidget<Text>('First')
          ..addWidget<Text>('Second');

        expect(sut.nameOf(const Text('a')), 'First');
      });

      test('skips added type whose isEnabled throws', () {
        final sut = fixture.getSut()
          ..addWidget<Text>(
            'Throws',
            isEnabled: (_) => throw StateError('isEnabled failed'),
          )
          ..addWidget<Text>('Text');

        expect(sut.nameOf(const Text('a')), 'Text');
      });
    });
  });
}

class Fixture {
  UserInteractionWidgetTypes getSut() => UserInteractionWidgetTypes();
}
