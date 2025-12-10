import 'package:sentry/sentry.dart';
import 'package:sentry/src/protocol/noop_span.dart';
import 'package:sentry/src/protocol/simple_span.dart';
import 'package:test/test.dart';

import 'mocks/mock_client_report_recorder.dart';
import 'mocks/mock_sentry_client.dart';
import 'test_utils.dart';

void main() {
  group('Hub', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('startSpan', () {
      group('span creation', () {
        test('returns SimpleSpan when tracing is enabled', () {
          final hub = fixture.getSut();

          final span = hub.startSpan('test-span');

          expect(span, isA<SimpleSpan>());
        });

        test('returns NoOpSpan when tracing is disabled', () {
          final hub = fixture.getSut(tracesSampleRate: null);

          final span = hub.startSpan('test-span');

          expect(span, isA<NoOpSpan>());
        });

        test('returns NoOpSpan when hub is closed', () async {
          final hub = fixture.getSut();
          await hub.close();

          final span = hub.startSpan('test-span');

          expect(span, isA<NoOpSpan>());
        });

        test('sets span name from parameter', () {
          final hub = fixture.getSut();

          final span = hub.startSpan('my-span-name');

          expect(span.name, equals('my-span-name'));
        });

        test('sets attributes on span when provided', () {
          final hub = fixture.getSut();
          final attributes = {
            'attr1': SentryAttribute.string('value1'),
            'attr2': SentryAttribute.int(42),
          };

          final span = hub.startSpan('test-span', attributes: attributes);

          expect(span.attributes, equals(attributes));
        });
      });

      group('active span handling', () {
        test('sets span as active on scope when active is true', () {
          final hub = fixture.getSut();

          final span = hub.startSpan('test-span', active: true);

          expect(hub.scope.getActiveSpan(), equals(span));
        });

        test('does not set span as active on scope when active is false', () {
          final hub = fixture.getSut();

          hub.startSpan('test-span', active: false);

          expect(hub.scope.getActiveSpan(), isNull);
        });
      });

      group('parent span resolution', () {
        test('creates root span when no active span exists', () {
          final hub = fixture.getSut();

          final span = hub.startSpan('test-span');

          expect(span.parentSpan, isNull);
        });

        test('uses active span as parent when parentSpan is not provided', () {
          final hub = fixture.getSut();
          final parentSpan = hub.startSpan('parent-span');

          final childSpan = hub.startSpan('child-span');

          expect(childSpan.parentSpan, equals(parentSpan));
        });

        test('uses explicit parentSpan instead of active span when provided',
            () {
          final hub = fixture.getSut();
          final explicitParent = hub.startSpan('explicit-parent');
          hub.startSpan('other-span'); // Changes active span

          final childSpan = hub.startSpan(
            'child-span',
            parentSpan: explicitParent,
            active: false,
          );

          expect(childSpan.parentSpan, equals(explicitParent));
        });

        test('allows finished span to be used as parent', () {
          final hub = fixture.getSut();
          final finishedParent = hub.startSpan('finished-parent');
          finishedParent.end();

          final childSpan = hub.startSpan(
            'child-span',
            parentSpan: finishedParent,
          );

          expect(childSpan.parentSpan, equals(finishedParent));
        });

        test('creates root span when parentSpan is explicitly set to null', () {
          final hub = fixture.getSut();
          hub.startSpan('active-span');

          final rootSpan = hub.startSpan('root-span', parentSpan: null);

          expect(rootSpan.parentSpan, isNull);
        });
      });

      group('span hierarchy', () {
        test('builds 3-level hierarchy with automatic parenting', () {
          final hub = fixture.getSut();

          final grandparent = hub.startSpan('grandparent');
          final parent = hub.startSpan('parent');
          final child = hub.startSpan('child');

          expect(grandparent.parentSpan, isNull);
          expect(parent.parentSpan, equals(grandparent));
          expect(child.parentSpan, equals(parent));
        });

        test('ending middle span allows new span to parent to grandparent', () {
          final hub = fixture.getSut();

          final grandparent = hub.startSpan('grandparent');
          final parent = hub.startSpan('parent');
          parent.end();

          final sibling = hub.startSpan('sibling');

          expect(sibling.parentSpan, equals(grandparent));
        });

        test('sibling spans share same parent when created as inactive', () {
          final hub = fixture.getSut();

          final parent = hub.startSpan('parent');
          final child1 = hub.startSpan('child1', active: false);
          final child2 = hub.startSpan('child2', active: false);

          expect(child1.parentSpan, equals(parent));
          expect(child2.parentSpan, equals(parent));
        });

        test('ending spans in reverse order cleans up active spans correctly',
            () {
          final hub = fixture.getSut();

          final span1 = hub.startSpan('span1');
          final span2 = hub.startSpan('span2');
          final span3 = hub.startSpan('span3');

          expect(hub.scope.activeSpans.length, 3);

          span3.end();
          expect(hub.scope.activeSpans.length, 2);
          expect(hub.scope.getActiveSpan(), equals(span2));

          span2.end();
          expect(hub.scope.getActiveSpan(), equals(span1));

          span1.end();
          expect(hub.scope.getActiveSpan(), isNull);
        });

        test('ending spans out of order removes them from active spans', () {
          final hub = fixture.getSut();

          final parent = hub.startSpan('parent');
          final child = hub.startSpan('child');

          parent.end();
          expect(hub.scope.activeSpans, contains(child));
          expect(hub.scope.activeSpans, isNot(contains(parent)));

          child.end();
          expect(hub.scope.activeSpans, isEmpty);
        });

        test(
            'new span parents to active root span when multiple root spans exist',
            () {
          final hub = fixture.getSut();

          final activeRoot =
              hub.startSpan('active-root', parentSpan: null, active: true);
          final inactiveRoot =
              hub.startSpan('inactive-root', parentSpan: null, active: false);

          final childToActiveSpan = hub.startSpan('child');
          expect(childToActiveSpan.parentSpan, equals(activeRoot));
          expect(childToActiveSpan.parentSpan, isNot(equals(inactiveRoot)));

          final childToInactiveSpan =
              hub.startSpan('child', parentSpan: inactiveRoot);
          expect(childToInactiveSpan.parentSpan, equals(inactiveRoot));
          expect(childToInactiveSpan.parentSpan, isNot(equals(activeRoot)));
        });

        test('deep hierarchy maintains correct parent chain', () {
          final hub = fixture.getSut();

          final spans = <Span>[];
          for (var i = 0; i < 5; i++) {
            spans.add(hub.startSpan('span-$i'));
          }

          // Verify chain: span0 <- span1 <- span2 <- span3 <- span4
          expect(spans[0].parentSpan, isNull);
          for (var i = 1; i < spans.length; i++) {
            expect(spans[i].parentSpan, equals(spans[i - 1]));
          }
        });
      });
    });

    group('captureSpan', () {
      // TODO: add test that it was added to buffer

      test('removes span from active spans on scope', () {
        final hub = fixture.getSut();
        final span = hub.startSpan('test-span');
        expect(hub.scope.activeSpans, contains(span));

        hub.captureSpan(span);

        expect(hub.scope.activeSpans, isNot(contains(span)));
      });

      test('does nothing when hub is closed', () async {
        final hub = fixture.getSut();
        final span = hub.startSpan('test-span');
        await hub.close();

        // Should not throw
        hub.captureSpan(span);
      });

      test('does nothing when tracing is disabled', () {
        final hub = fixture.getSut(tracesSampleRate: null);

        final span = hub.startSpan('test-span');
        expect(span, isA<NoOpSpan>());
        expect(hub.scope.activeSpans, isEmpty);

        hub.captureSpan(span);

        expect(hub.scope.activeSpans, isEmpty);
      });
    });
  });
}

class Fixture {
  final client = MockSentryClient();
  final recorder = MockClientReportRecorder();

  final options = defaultTestOptions();

  Hub getSut({
    double? tracesSampleRate = 1.0,
    TracesSamplerCallback? tracesSampler,
    bool debug = false,
  }) {
    options.tracesSampleRate = tracesSampleRate;
    options.tracesSampler = tracesSampler;
    options.debug = debug;

    final hub = Hub(options);

    hub.bindClient(client);
    options.recorder = recorder;

    return hub;
  }
}
