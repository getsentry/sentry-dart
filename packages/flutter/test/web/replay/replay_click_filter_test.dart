import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/web/replay/replay_click_filter.dart';

void main() {
  group('isFlutterViewClickEvent', () {
    test('is true for the DOM click on the flutter-view', () {
      expect(isFlutterViewClickEvent(_breadcrumbEvent('flutter-view')), isTrue);
    });

    test('is false for a DOM click on another element', () {
      expect(isFlutterViewClickEvent(_breadcrumbEvent('button')), isFalse);
    });

    test('is false for the Flutter click breadcrumb', () {
      expect(
        isFlutterViewClickEvent(
            _breadcrumbEvent('flutter-view', category: 'flutter.ui.click')),
        isFalse,
      );
    });

    test('is false for other breadcrumb categories', () {
      expect(
        isFlutterViewClickEvent(
            _breadcrumbEvent('flutter-view', category: 'navigation')),
        isFalse,
      );
    });

    test('is false for non-breadcrumb custom events', () {
      expect(
        isFlutterViewClickEvent(<dynamic, dynamic>{
          'type': 5,
          'data': {'tag': 'performanceSpan', 'payload': <dynamic, dynamic>{}},
        }),
        isFalse,
      );
    });

    test('is false for non-custom events', () {
      expect(
          isFlutterViewClickEvent(
              <dynamic, dynamic>{'type': 3, 'data': <dynamic, dynamic>{}}),
          isFalse);
    });

    test('is false for malformed events', () {
      expect(isFlutterViewClickEvent(null), isFalse);
      expect(isFlutterViewClickEvent(<dynamic, dynamic>{'type': 5}), isFalse);
      expect(
          isFlutterViewClickEvent(<dynamic, dynamic>{'type': 5, 'data': 'x'}),
          isFalse);
      expect(
        isFlutterViewClickEvent(<dynamic, dynamic>{
          'type': 5,
          'data': {'tag': 'breadcrumb', 'payload': 'x'},
        }),
        isFalse,
      );
    });
  });
}

Map<dynamic, dynamic> _breadcrumbEvent(
  String tagName, {
  String category = 'ui.click',
}) =>
    {
      'type': 5,
      'data': {
        'tag': 'breadcrumb',
        'payload': {
          'category': category,
          'message': 'body > $tagName',
          'data': {
            'nodeId': 27,
            'node': {'id': 27, 'tagName': tagName},
          },
        },
      },
    };
