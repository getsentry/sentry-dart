import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('json', () {
    test('toJson with children', () {
      final element = SentryViewHierarchyElement(
        'RenderObjectToWidgetAdapter<RenderBox>',
        depth: 1,
        identifier: 'RenderView#a2216',
      );

      final element2 = SentryViewHierarchyElement(
        'SentryScreenshotWidget',
        depth: 2,
      );
      element.children.add(element2);

      final viewHierrchy = SentryViewHierarchy('flutter');
      viewHierrchy.windows.add(element);

      final map = viewHierrchy.toJson();

      expect(map, {
        'rendering_system': 'flutter',
        'windows': [
          {
            'type': 'RenderObjectToWidgetAdapter<RenderBox>',
            'depth': 1,
            'identifier': 'RenderView#a2216',
            'children': [
              {
                'type': 'SentryScreenshotWidget',
                'depth': 2,
              },
            ]
          },
        ],
      });
    });

    test('toJson no children', () {
      final viewHierrchy = SentryViewHierarchy('flutter');

      final map = viewHierrchy.toJson();

      expect(map, {
        'rendering_system': 'flutter',
      });
    });
  });
}
