import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/user_interaction/user_interaction_widget_types.dart';

void main() {
  group('$UserInteractionWidgetTypes', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('typeOf', () {
      test('returns added type for widget of that type', () {
        final sut = fixture.getSut()
          ..addWidget<Text>('Text', labelFromText: true);

        expect(
            sut.typeOf(const Text('a')), (name: 'Text', labelFromText: true));
      });

      test('returns added type for subclass of that type', () {
        final sut = fixture.getSut()..addWidget<StatelessWidget>('Stateless');

        expect(
          sut.typeOf(const Text('a')),
          (name: 'Stateless', labelFromText: false),
        );
      });

      test('returns null for other widgets', () {
        final sut = fixture.getSut()..addWidget<Text>('Text');

        expect(sut.typeOf(const SizedBox()), isNull);
      });

      test('returns null when isEnabled returns false', () {
        final sut = fixture.getSut()
          ..addWidget<Text>('Text', isEnabled: (widget) => widget.data != 'a');

        expect(sut.typeOf(const Text('a')), isNull);
      });

      test('returns first added type that matches', () {
        final sut = fixture.getSut()
          ..addWidget<Text>('First')
          ..addWidget<Text>('Second');

        expect(sut.typeOf(const Text('a'))?.name, 'First');
      });

      test('skips added type whose isEnabled throws', () {
        final sut = fixture.getSut()
          ..addWidget<Text>(
            'Throws',
            isEnabled: (_) => throw StateError('isEnabled failed'),
          )
          ..addWidget<Text>('Text');

        expect(sut.typeOf(const Text('a'))?.name, 'Text');
      });
    });

    group('labelOf', () {
      test('returns label from added label type', () {
        final sut = fixture.getSut()..addLabel<Text>((widget) => widget.data);

        expect(sut.labelOf(const Text('a')), 'a');
      });

      test('returns null for other widgets', () {
        final sut = fixture.getSut()..addLabel<Text>((widget) => widget.data);

        expect(sut.labelOf(const SizedBox()), isNull);
      });

      test('skips added label type whose callback throws', () {
        final sut = fixture.getSut()
          ..addLabel<Text>((_) => throw StateError('label failed'))
          ..addLabel<Text>((widget) => widget.data);

        expect(sut.labelOf(const Text('a')), 'a');
      });
    });
  });
}

class Fixture {
  UserInteractionWidgetTypes getSut() => UserInteractionWidgetTypes();
}
