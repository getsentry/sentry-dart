import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('json', () {
    test('toJson with children', () {
      final element = SentryViewHierarchyElement(
        'RenderObjectToWidgetAdapter<RenderBox>',
        depth: 1,
        identifier: 'RenderView#a2216',
        width: 100,
        height: 200,
        x: 100,
        y: 50,
        z: 30,
        visible: true,
        alpha: 90,
        extra: {'key': 'value'},
      );
      final element2 = SentryViewHierarchyElement(
        'SentryScreenshotWidget',
        depth: 2,
      );
      element.children.add(element2);

      final map = element.toJson();

      expect(map, {
        'type': 'RenderObjectToWidgetAdapter<RenderBox>',
        'depth': 1,
        'identifier': 'RenderView#a2216',
        'children': [
          {
            'type': 'SentryScreenshotWidget',
            'depth': 2,
          },
        ],
        'width': 100,
        'height': 200,
        'x': 100,
        'y': 50,
        'z': 30,
        'visible': true,
        'alpha': 90,
        'key': 'value',
      });
    });

    test('toJson no children', () {
      final element = SentryViewHierarchyElement(
        'RenderObjectToWidgetAdapter<RenderBox>',
        depth: 1,
        identifier: 'RenderView#a2216',
      );

      final map = element.toJson();

      expect(map, {
        'type': 'RenderObjectToWidgetAdapter<RenderBox>',
        'depth': 1,
        'identifier': 'RenderView#a2216',
      });
    });
  });
}
