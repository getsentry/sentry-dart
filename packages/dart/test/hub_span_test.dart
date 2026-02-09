import 'package:sentry/sentry.dart';
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

    group('startSpanManual', () {
      group('span creation', () {
        test('returns RecordingSentrySpanV2 when tracing is enabled', () {
          final hub = fixture.getSut();

          final span = hub.startSpanManual('test-span');

          expect(span, isA<RecordingSentrySpanV2>());
        });

        test('returns NoOpSentrySpanV2 when tracing is disabled', () {
          final hub = fixture.getSut(tracesSampleRate: null);

          final span = hub.startSpanManual('test-span');

          expect(span, isA<NoOpSentrySpanV2>());
        });

        test('returns NoOpSentrySpanV2 when hub is closed', () async {
          final hub = fixture.getSut();
          await hub.close();

          final span = hub.startSpanManual('test-span');

          expect(span, isA<NoOpSentrySpanV2>());
        });

        test('sets span name from parameter', () {
          final hub = fixture.getSut();

          final span = hub.startSpanManual('my-span-name');

          expect(span.name, equals('my-span-name'));
        });

        test('sets attributes on span when provided', () {
          final hub = fixture.getSut();
          final attributes = {
            'attr1': SentryAttribute.string('value1'),
            'attr2': SentryAttribute.int(42),
          };

          final span = hub.startSpanManual('test-span', attributes: attributes);

          expect(span.attributes, equals(attributes));
        });

        test('returns NoOpSentrySpanV2 when traceLifecycle is static', () {
          final hub = fixture.getSut(
            traceLifecycle: SentryTraceLifecycle.static,
          );

          final span = hub.startSpanManual('test-span');

          expect(span, isA<NoOpSentrySpanV2>());
        });

        test(
          'returns RecordingSentrySpanV2 when traceLifecycle is streaming',
          () {
            final hub = fixture.getSut(
              traceLifecycle: SentryTraceLifecycle.streaming,
            );

            final span = hub.startSpanManual('test-span');

            expect(span, isA<RecordingSentrySpanV2>());
          },
        );
      });

      group('active span handling', () {
        test('sets span as active on scope when active is true', () {
          final hub = fixture.getSut();

          final span = hub.startSpanManual('test-span', active: true);

          expect(hub.scope.getActiveSpan(), equals(span));
        });

        test('does not set span as active on scope when active is false', () {
          final hub = fixture.getSut();

          hub.startSpanManual('test-span', active: false);

          expect(hub.scope.getActiveSpan(), isNull);
        });
      });

      group('parent span resolution', () {
        test('creates root span when no active span exists', () {
          final hub = fixture.getSut();

          final span = hub.startSpanManual('test-span');

          expect(span.parentSpan, isNull);
        });

        test('uses active span as parent when parentSpan is not provided', () {
          final hub = fixture.getSut();
          final parentSpan = hub.startSpanManual('parent-span');

          final childSpan = hub.startSpanManual('child-span');

          expect(childSpan.parentSpan, equals(parentSpan));
        });

        test(
          'uses explicit parentSpan instead of active span when provided',
          () {
            final hub = fixture.getSut();
            final explicitParent = hub.startSpanManual('explicit-parent');
            hub.startSpanManual('other-span'); // Changes active span

            final childSpan = hub.startSpanManual(
              'child-span',
              parentSpan: explicitParent,
              active: false,
            );

            expect(childSpan.parentSpan, equals(explicitParent));
          },
        );

        test('allows finished span to be used as parent', () {
          final hub = fixture.getSut();
          final finishedParent = hub.startSpanManual('finished-parent');
          finishedParent.end();

          final childSpan = hub.startSpanManual(
            'child-span',
            parentSpan: finishedParent,
          );

          expect(childSpan.parentSpan, equals(finishedParent));
        });

        test('creates root span when parentSpan is explicitly set to null', () {
          final hub = fixture.getSut();
          hub.startSpanManual('active-span');

          final rootSpan = hub.startSpanManual('root-span', parentSpan: null);

          expect(rootSpan.parentSpan, isNull);
        });
      });

      group('span hierarchy', () {
        test('builds 3-level hierarchy with automatic parenting', () {
          final hub = fixture.getSut();

          final grandparent = hub.startSpanManual('grandparent');
          final parent = hub.startSpanManual('parent');
          final child = hub.startSpanManual('child');

          expect(grandparent.parentSpan, isNull);
          expect(parent.parentSpan, equals(grandparent));
          expect(child.parentSpan, equals(parent));
        });

        test('ending active span clears it from scope', () {
          final hub = fixture.getSut();

          hub.startSpanManual('grandparent');
          final parent = hub.startSpanManual('parent');
          parent.end();

          // Active span was parent, now cleared since parent ended
          expect(hub.scope.activeSpan, isNull);
        });

        test('sibling spans share same parent when created as inactive', () {
          final hub = fixture.getSut();

          final parent = hub.startSpanManual('parent');
          final child1 = hub.startSpanManual('child1', active: false);
          final child2 = hub.startSpanManual('child2', active: false);

          expect(child1.parentSpan, equals(parent));
          expect(child2.parentSpan, equals(parent));
        });

        test('ending active span clears scope active span', () {
          final hub = fixture.getSut();

          hub.startSpanManual('span1');
          hub.startSpanManual('span2');
          final span3 = hub.startSpanManual('span3');

          expect(hub.scope.getActiveSpan(), equals(span3));

          span3.end();
          expect(hub.scope.getActiveSpan(), isNull);
        });

        test(
            'ending non-active span does not clear active span from scope', () {
          final hub = fixture.getSut();

          hub.startSpanManual('parent');
          final child = hub.startSpanManual('child');
          final inactive =
              hub.startSpanManual('inactive', active: false);

          inactive.end();
          // child is still active since inactive wasn't the active span
          expect(hub.scope.getActiveSpan(), equals(child));

          child.end();
          expect(hub.scope.getActiveSpan(), isNull);
        });

        test(
          'new span parents to active root span when multiple root spans exist',
          () {
            final hub = fixture.getSut();

            final activeRoot = hub.startSpanManual(
              'active-root',
              parentSpan: null,
              active: true,
            );
            final inactiveRoot = hub.startSpanManual(
              'inactive-root',
              parentSpan: null,
              active: false,
            );

            final childToActiveSpan = hub.startSpanManual('child');
            expect(childToActiveSpan.parentSpan, equals(activeRoot));
            expect(childToActiveSpan.parentSpan, isNot(equals(inactiveRoot)));

            final childToInactiveSpan = hub.startSpanManual(
              'child',
              parentSpan: inactiveRoot,
            );
            expect(childToInactiveSpan.parentSpan, equals(inactiveRoot));
            expect(childToInactiveSpan.parentSpan, isNot(equals(activeRoot)));
          },
        );

        test('deep hierarchy maintains correct parent chain', () {
          final hub = fixture.getSut();

          final spans = <SentrySpanV2>[];
          for (var i = 0; i < 5; i++) {
            spans.add(hub.startSpanManual('span-$i'));
          }

          // Verify chain: span0 <- span1 <- span2 <- span3 <- span4
          expect(spans[0].parentSpan, isNull);
          for (var i = 1; i < spans.length; i++) {
            expect(spans[i].parentSpan, equals(spans[i - 1]));
          }
        });
      });

      group('sampling inheritance', () {
        test('root span has sampling decision', () {
          final hub = fixture.getSut(tracesSampleRate: 1.0);

          final rootSpan = hub.startSpanManual('root-span');

          expect(rootSpan, isA<RecordingSentrySpanV2>());
          final recordingSpan = rootSpan as RecordingSentrySpanV2;
          expect(recordingSpan.samplingDecision.sampled, isTrue);
          expect(recordingSpan.samplingDecision.sampleRate, equals(1.0));
        });

        test('child span inherits parent sampling decision', () {
          final hub = fixture.getSut(tracesSampleRate: 1.0);

          final rootSpan = hub.startSpanManual('root-span') as RecordingSentrySpanV2;
          final childSpan =
              hub.startSpanManual('child-span') as RecordingSentrySpanV2;

          // Both should have the same sampling decision
          expect(
            childSpan.samplingDecision.sampled,
            equals(rootSpan.samplingDecision.sampled),
          );
          expect(
            childSpan.samplingDecision.sampleRate,
            equals(rootSpan.samplingDecision.sampleRate),
          );
          expect(
            childSpan.samplingDecision.sampleRand,
            equals(rootSpan.samplingDecision.sampleRand),
          );
        });

        test('deeply nested spans all inherit root sampling decision', () {
          final hub = fixture.getSut(tracesSampleRate: 1.0);

          final rootSpan = hub.startSpanManual('root-span') as RecordingSentrySpanV2;
          final child1 = hub.startSpanManual('child-1') as RecordingSentrySpanV2;
          final child2 = hub.startSpanManual('child-2') as RecordingSentrySpanV2;
          final child3 = hub.startSpanManual('child-3') as RecordingSentrySpanV2;

          final rootDecision = rootSpan.samplingDecision;

          // All children should have the same sampling decision
          expect(child1.samplingDecision.sampled, equals(rootDecision.sampled));
          expect(
            child1.samplingDecision.sampleRate,
            equals(rootDecision.sampleRate),
          );
          expect(
            child1.samplingDecision.sampleRand,
            equals(rootDecision.sampleRand),
          );

          expect(child2.samplingDecision.sampled, equals(rootDecision.sampled));
          expect(
            child2.samplingDecision.sampleRate,
            equals(rootDecision.sampleRate),
          );
          expect(
            child2.samplingDecision.sampleRand,
            equals(rootDecision.sampleRand),
          );

          expect(child3.samplingDecision.sampled, equals(rootDecision.sampled));
          expect(
            child3.samplingDecision.sampleRate,
            equals(rootDecision.sampleRate),
          );
          expect(
            child3.samplingDecision.sampleRand,
            equals(rootDecision.sampleRand),
          );
        });

        test('sampling is evaluated once at root level', () {
          final hub = fixture.getSut(tracesSampleRate: 1.0);

          // Start root span (should trigger sampling evaluation)
          final rootSpan = hub.startSpanManual('root-span');
          expect(rootSpan, isA<RecordingSentrySpanV2>());

          // Start child spans (should NOT trigger new sampling evaluations)
          final child1 = hub.startSpanManual('child-1');
          final child2 = hub.startSpanManual('child-2');

          expect(child1, isA<RecordingSentrySpanV2>());
          expect(child2, isA<RecordingSentrySpanV2>());

          // All spans should be recording spans, using the same sampling decision
        });

        test('root span with sampleRate=0 prevents all child spans', () {
          final hub = fixture.getSut(tracesSampleRate: 0.0);

          final rootSpan = hub.startSpanManual('root-span');

          // Root span should be NoOp when sampled out
          expect(rootSpan, isA<NoOpSentrySpanV2>());

          // Children should also be NoOp (can't have recording children of NoOp)
          final childSpan = hub.startSpanManual('child-span');
          expect(childSpan, isA<NoOpSentrySpanV2>());
        });

        test('sampleRand is reused across all spans in the same trace', () {
          final hub = fixture.getSut(tracesSampleRate: 1.0);

          final rootSpan = hub.startSpanManual('root-span') as RecordingSentrySpanV2;
          final sampleRand = rootSpan.samplingDecision.sampleRand;

          // Create multiple child spans
          final child1 = hub.startSpanManual('child-1') as RecordingSentrySpanV2;
          final child2 = hub.startSpanManual('child-2') as RecordingSentrySpanV2;

          // All spans should use the same sampleRand
          expect(child1.samplingDecision.sampleRand, equals(sampleRand));
          expect(child2.samplingDecision.sampleRand, equals(sampleRand));
        });

        test('new trace gets new sampling decision', () {
          final hub = fixture.getSut(tracesSampleRate: 1.0);

          // First trace
          final rootSpan1 = hub.startSpanManual('root-1', parentSpan: null)
              as RecordingSentrySpanV2;
          final decision1 = rootSpan1.samplingDecision;

          // Generate new trace
          hub.generateNewTrace();

          // Second trace
          final rootSpan2 = hub.startSpanManual('root-2', parentSpan: null)
              as RecordingSentrySpanV2;
          final decision2 = rootSpan2.samplingDecision;

          // New trace should have a different sampleRand
          // (extremely unlikely to be the same by chance)
          expect(decision2.sampleRand, isNot(equals(decision1.sampleRand)));
        });
      });
    });

    group('when capturing span', () {
      test('calls client.captureSpan with span and scope', () async {
        final hub = fixture.getSut();
        final span = hub.startSpanManual('test-span');

        await hub.captureSpan(span);

        expect(fixture.client.captureSpanCalls, hasLength(1));
        expect(fixture.client.captureSpanCalls.first.span, equals(span));
        expect(fixture.client.captureSpanCalls.first.scope, isNotNull);
      });

      test('clears active span from scope when it matches', () async {
        final hub = fixture.getSut();
        final span = hub.startSpanManual('test-span');
        expect(hub.scope.activeSpan, equals(span));

        await hub.captureSpan(span);

        expect(hub.scope.activeSpan, isNull);
      });

      test('does nothing when hub is closed', () async {
        final hub = fixture.getSut();
        final span = hub.startSpanManual('test-span');
        await hub.close();

        await hub.captureSpan(span);

        expect(fixture.client.captureSpanCalls, isEmpty);
        expect(hub.scope.activeSpan, equals(span));
      });

      test('does nothing when tracing is disabled', () async {
        final hub = fixture.getSut(tracesSampleRate: null);

        final span = hub.startSpanManual('test-span');
        expect(span, isA<NoOpSentrySpanV2>());
        expect(hub.scope.activeSpan, isNull);

        await hub.captureSpan(span);

        expect(hub.scope.activeSpan, isNull);
        expect(fixture.client.captureSpanCalls, isEmpty);
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
    SentryTraceLifecycle traceLifecycle = SentryTraceLifecycle.streaming,
  }) {
    options.tracesSampleRate = tracesSampleRate;
    options.tracesSampler = tracesSampler;
    options.debug = debug;
    options.traceLifecycle = traceLifecycle;

    final hub = Hub(options);

    hub.bindClient(client);
    options.recorder = recorder;

    return hub;
  }
}
