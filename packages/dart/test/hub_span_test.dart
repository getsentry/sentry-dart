import 'dart:async';

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

    group('startInactiveSpan', () {
      group('span creation', () {
        test('returns RecordingSentrySpanV2 when tracing is enabled', () {
          final hub = fixture.getSut();

          final span = hub.startInactiveSpan('test-span');

          expect(span, isA<RecordingSentrySpanV2>());
        });

        test('returns NoOpSentrySpanV2 when tracing is disabled', () {
          final hub = fixture.getSut(tracesSampleRate: null);

          final span = hub.startInactiveSpan('test-span');

          expect(span, isA<NoOpSentrySpanV2>());
        });

        test('returns NoOpSentrySpanV2 when hub is closed', () async {
          final hub = fixture.getSut();
          await hub.close();

          final span = hub.startInactiveSpan('test-span');

          expect(span, isA<NoOpSentrySpanV2>());
        });

        test('sets span name from parameter', () {
          final hub = fixture.getSut();

          final span = hub.startInactiveSpan('my-span-name');

          expect(span.name, equals('my-span-name'));
        });

        test('sets attributes on span when provided', () {
          final hub = fixture.getSut();
          final attributes = {
            'attr1': SentryAttribute.string('value1'),
            'attr2': SentryAttribute.int(42),
          };

          final span = hub.startInactiveSpan('test-span', attributes: attributes);

          expect(span.attributes, equals(attributes));
        });

        test('returns NoOpSentrySpanV2 when traceLifecycle is static', () {
          final hub = fixture.getSut(
            traceLifecycle: SentryTraceLifecycle.static,
          );

          final span = hub.startInactiveSpan('test-span');

          expect(span, isA<NoOpSentrySpanV2>());
        });

        test(
          'returns RecordingSentrySpanV2 when traceLifecycle is streaming',
          () {
            final hub = fixture.getSut(
              traceLifecycle: SentryTraceLifecycle.streaming,
            );

            final span = hub.startInactiveSpan('test-span');

            expect(span, isA<RecordingSentrySpanV2>());
          },
        );

        test('does not set span as active on scope', () {
          final hub = fixture.getSut();

          hub.startInactiveSpan('test-span');

          expect(hub.scope.getActiveSpan(), isNull);
        });
      });

      group('parent span resolution', () {
        test('creates root span when no active span exists', () {
          final hub = fixture.getSut();

          final span = hub.startInactiveSpan('test-span');

          expect(span.parentSpan, isNull);
        });

        test(
          'uses explicit parentSpan instead of active span when provided',
          () {
            final hub = fixture.getSut();
            final explicitParent = hub.startInactiveSpan('explicit-parent');

            final childSpan = hub.startInactiveSpan(
              'child-span',
              parentSpan: explicitParent,
            );

            expect(childSpan.parentSpan, equals(explicitParent));
          },
        );

        test('allows finished span to be used as parent', () {
          final hub = fixture.getSut();
          final finishedParent = hub.startInactiveSpan('finished-parent');
          finishedParent.end();

          final childSpan = hub.startInactiveSpan(
            'child-span',
            parentSpan: finishedParent,
          );

          expect(childSpan.parentSpan, equals(finishedParent));
        });

        test('creates root span when parentSpan is explicitly set to null', () {
          final hub = fixture.getSut();

          final rootSpan = hub.startInactiveSpan('root-span', parentSpan: null);

          expect(rootSpan.parentSpan, isNull);
        });
      });

      group('span hierarchy', () {
        test('builds 3-level hierarchy with explicit parenting', () {
          final hub = fixture.getSut();

          final grandparent = hub.startInactiveSpan('grandparent');
          final parent =
              hub.startInactiveSpan('parent', parentSpan: grandparent);
          final child = hub.startInactiveSpan('child', parentSpan: parent);

          expect(grandparent.parentSpan, isNull);
          expect(parent.parentSpan, equals(grandparent));
          expect(child.parentSpan, equals(parent));
        });

        test('sibling spans share same parent', () {
          final hub = fixture.getSut();

          final parent = hub.startInactiveSpan('parent');
          final child1 =
              hub.startInactiveSpan('child1', parentSpan: parent);
          final child2 =
              hub.startInactiveSpan('child2', parentSpan: parent);

          expect(child1.parentSpan, equals(parent));
          expect(child2.parentSpan, equals(parent));
        });

        test('deep hierarchy maintains correct parent chain', () {
          final hub = fixture.getSut();

          final spans = <SentrySpanV2>[];
          for (var i = 0; i < 5; i++) {
            final parent = i > 0 ? spans[i - 1] : null;
            spans.add(hub.startInactiveSpan('span-$i', parentSpan: parent));
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

          final rootSpan = hub.startInactiveSpan('root-span');

          expect(rootSpan, isA<RecordingSentrySpanV2>());
          final recordingSpan = rootSpan as RecordingSentrySpanV2;
          expect(recordingSpan.samplingDecision.sampled, isTrue);
          expect(recordingSpan.samplingDecision.sampleRate, equals(1.0));
        });

        test('child span inherits parent sampling decision', () {
          final hub = fixture.getSut(tracesSampleRate: 1.0);

          final rootSpan = hub.startInactiveSpan('root-span') as RecordingSentrySpanV2;
          final childSpan =
              hub.startInactiveSpan('child-span', parentSpan: rootSpan)
                  as RecordingSentrySpanV2;

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

          final rootSpan = hub.startInactiveSpan('root-span') as RecordingSentrySpanV2;
          final child1 =
              hub.startInactiveSpan('child-1', parentSpan: rootSpan)
                  as RecordingSentrySpanV2;
          final child2 =
              hub.startInactiveSpan('child-2', parentSpan: child1)
                  as RecordingSentrySpanV2;
          final child3 =
              hub.startInactiveSpan('child-3', parentSpan: child2)
                  as RecordingSentrySpanV2;

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
          final rootSpan = hub.startInactiveSpan('root-span');
          expect(rootSpan, isA<RecordingSentrySpanV2>());

          // Start child spans (should NOT trigger new sampling evaluations)
          final child1 = hub.startInactiveSpan('child-1', parentSpan: rootSpan);
          final child2 = hub.startInactiveSpan('child-2', parentSpan: rootSpan);

          expect(child1, isA<RecordingSentrySpanV2>());
          expect(child2, isA<RecordingSentrySpanV2>());

          // All spans should be recording spans, using the same sampling decision
        });

        test('root span with sampleRate=0 prevents all child spans', () {
          final hub = fixture.getSut(tracesSampleRate: 0.0);

          final rootSpan = hub.startInactiveSpan('root-span');

          // Root span should be NoOp when sampled out
          expect(rootSpan, isA<NoOpSentrySpanV2>());

          // Children should also be NoOp (can't have recording children of NoOp)
          final childSpan = hub.startInactiveSpan('child-span', parentSpan: rootSpan);
          expect(childSpan, isA<NoOpSentrySpanV2>());
        });

        test('sampleRand is reused across all spans in the same trace', () {
          final hub = fixture.getSut(tracesSampleRate: 1.0);

          final rootSpan = hub.startInactiveSpan('root-span') as RecordingSentrySpanV2;
          final sampleRand = rootSpan.samplingDecision.sampleRand;

          // Create multiple child spans
          final child1 =
              hub.startInactiveSpan('child-1', parentSpan: rootSpan)
                  as RecordingSentrySpanV2;
          final child2 =
              hub.startInactiveSpan('child-2', parentSpan: rootSpan)
                  as RecordingSentrySpanV2;

          // All spans should use the same sampleRand
          expect(child1.samplingDecision.sampleRand, equals(sampleRand));
          expect(child2.samplingDecision.sampleRand, equals(sampleRand));
        });

        test('new trace gets new sampling decision', () {
          final hub = fixture.getSut(tracesSampleRate: 1.0);

          // First trace
          final rootSpan1 = hub.startInactiveSpan('root-1', parentSpan: null)
              as RecordingSentrySpanV2;
          final decision1 = rootSpan1.samplingDecision;

          // Generate new trace
          hub.generateNewTrace();

          // Second trace
          final rootSpan2 = hub.startInactiveSpan('root-2', parentSpan: null)
              as RecordingSentrySpanV2;
          final decision2 = rootSpan2.samplingDecision;

          // New trace should have a different sampleRand
          // (extremely unlikely to be the same by chance)
          expect(decision2.sampleRand, isNot(equals(decision1.sampleRand)));
        });
      });
    });

    group('startSpan', () {
      group('with sync callback', () {
        test('returns callback result', () {
          final hub = fixture.getSut();

          final result = hub.startSpan('test-span', (span) => 42);

          expect(result, equals(42));
        });

        test('ends span after callback completes', () {
          final hub = fixture.getSut();
          late RecordingSentrySpanV2 capturedSpan;

          hub.startSpan('test-span', (span) {
            capturedSpan = span as RecordingSentrySpanV2;
            expect(span.isEnded, isFalse);
          });

          expect(capturedSpan.isEnded, isTrue);
        });

        test('provides RecordingSentrySpanV2 when tracing is enabled', () {
          final hub = fixture.getSut();

          hub.startSpan('test-span', (span) {
            expect(span, isA<RecordingSentrySpanV2>());
          });
        });

        test('provides NoOpSentrySpanV2 when tracing is disabled', () {
          final hub = fixture.getSut(tracesSampleRate: null);

          hub.startSpan('test-span', (span) {
            expect(span, isA<NoOpSentrySpanV2>());
          });
        });

        test('sets error status and ends span on throw', () {
          final hub = fixture.getSut();
          late RecordingSentrySpanV2 capturedSpan;

          expect(
            () => hub.startSpan('test-span', (span) {
              capturedSpan = span as RecordingSentrySpanV2;
              throw StateError('test error');
            }),
            throwsA(isA<StateError>()),
          );

          expect(capturedSpan.isEnded, isTrue);
          expect(capturedSpan.status, equals(SentrySpanStatusV2.error));
        });
      });

      group('with async callback', () {
        test('returns callback result', () async {
          final hub = fixture.getSut();

          final result = await hub.startSpan('test-span', (span) async => 42);

          expect(result, equals(42));
        });

        test('ends span after future completes', () async {
          final hub = fixture.getSut();
          late RecordingSentrySpanV2 capturedSpan;

          await hub.startSpan('test-span', (span) async {
            capturedSpan = span as RecordingSentrySpanV2;
            expect(span.isEnded, isFalse);
          });

          expect(capturedSpan.isEnded, isTrue);
        });

        test('sets error status and ends span on async error', () async {
          final hub = fixture.getSut();
          late RecordingSentrySpanV2 capturedSpan;

          await expectLater(
            hub.startSpan('test-span', (span) async {
              capturedSpan = span as RecordingSentrySpanV2;
              throw StateError('async error');
            }),
            throwsA(isA<StateError>()),
          );

          expect(capturedSpan.isEnded, isTrue);
          expect(capturedSpan.status, equals(SentrySpanStatusV2.error));
        });
      });

      group('with zone-based scope forking', () {
        test('nested calls build correct parent-child chain', () {
          final hub = fixture.getSut();
          late SentrySpanV2 outerSpan;
          late SentrySpanV2 innerSpan;

          hub.startSpan('outer', (span) {
            outerSpan = span;
            hub.startSpan('inner', (span) {
              innerSpan = span;
            });
          });

          expect(outerSpan.parentSpan, isNull);
          expect(innerSpan.parentSpan, equals(outerSpan));
        });

        test('3-level nesting builds correct parent chain', () {
          final hub = fixture.getSut();
          late SentrySpanV2 level1;
          late SentrySpanV2 level2;
          late SentrySpanV2 level3;

          hub.startSpan('level-1', (span) {
            level1 = span;
            hub.startSpan('level-2', (span) {
              level2 = span;
              hub.startSpan('level-3', (span) {
                level3 = span;
              });
            });
          });

          expect(level1.parentSpan, isNull);
          expect(level2.parentSpan, equals(level1));
          expect(level3.parentSpan, equals(level2));
        });

        test('sibling spans share same parent', () {
          final hub = fixture.getSut();
          late SentrySpanV2 parent;
          late SentrySpanV2 child1;
          late SentrySpanV2 child2;

          hub.startSpan('parent', (span) {
            parent = span;
            hub.startSpan('child-1', (span) {
              child1 = span;
            });
            hub.startSpan('child-2', (span) {
              child2 = span;
            });
          });

          expect(child1.parentSpan, equals(parent));
          expect(child2.parentSpan, equals(parent));
        });

        test('does not leak active span to outer scope after callback', () {
          final hub = fixture.getSut();

          hub.startSpan('outer', (span) {
            final outerActiveSpan = hub.getActiveSpan();
            expect(outerActiveSpan, equals(span));

            hub.startSpan('inner', (innerSpan) {
              final innerActiveSpan = hub.getActiveSpan();
              expect(innerActiveSpan, equals(innerSpan));
            });

            // After inner callback, zone pops so active span should still
            // be the outer span in this zone.
            final afterInner = hub.getActiveSpan();
            expect(afterInner, equals(span));
          });
        });

        test('parallel async spans share same parent', () async {
          final hub = fixture.getSut();
          late SentrySpanV2 parent;
          late SentrySpanV2 child1;
          late SentrySpanV2 child2;

          await hub.startSpan<void>('parent', (span) async {
            parent = span;
            final f1 = hub.startSpan<void>('child-1', (span) async {
              child1 = span;
              await Future.delayed(Duration.zero);
            });
            final f2 = hub.startSpan<void>('child-2', (span) async {
              child2 = span;
              await Future.delayed(Duration.zero);
            });
            await Future.wait([f1 as Future<void>, f2 as Future<void>]);
          });

          expect(child1.parentSpan, equals(parent));
          expect(child2.parentSpan, equals(parent));
        });

        test('does not pollute hub scope active span', () {
          final hub = fixture.getSut();

          expect(hub.scope.activeSpan, isNull);

          hub.startSpan('test-span', (span) {});

          expect(hub.scope.activeSpan, isNull);
        });
      });

      group('with explicit parentSpan', () {
        test('uses provided parent instead of zone-resolved parent', () {
          final hub = fixture.getSut();
          late SentrySpanV2 explicitParent;
          late SentrySpanV2 child;

          hub.startSpan('explicit-parent', (span) {
            explicitParent = span;
          });

          hub.startSpan('outer', (outerSpan) {
            child = hub.startInactiveSpan(
              'child',
              parentSpan: explicitParent,
            );
          });

          expect(child.parentSpan, equals(explicitParent));
        });

        test('creates root span when parentSpan is null', () {
          final hub = fixture.getSut();
          late SentrySpanV2 child;

          hub.startSpan('outer', (outerSpan) {
            hub.startSpan('root-child', (span) {
              child = span;
            }, parentSpan: null);
          });

          expect(child.parentSpan, isNull);
        });
      });

      group('with attributes', () {
        test('passes attributes to created span', () {
          final hub = fixture.getSut();
          final attrs = {
            'http.method': SentryAttribute.string('GET'),
            'http.status_code': SentryAttribute.int(200),
          };

          hub.startSpan('test-span', (span) {
            expect(span.attributes, equals(attrs));
          }, attributes: attrs);
        });
      });

      group('when capturing spans', () {
        test('captures span via client on end', () {
          final hub = fixture.getSut();

          hub.startSpan('test-span', (span) {});

          expect(fixture.client.captureSpanCalls, hasLength(1));
        });

        test('captures all nested spans', () {
          final hub = fixture.getSut();

          hub.startSpan('outer', (span) {
            hub.startSpan('inner', (span) {});
          });

          expect(fixture.client.captureSpanCalls, hasLength(2));
        });
      });
    });

    group('when capturing span', () {
      test('calls client.captureSpan with span and scope', () async {
        final hub = fixture.getSut();
        final span = hub.startInactiveSpan('test-span');

        await hub.captureSpan(span);

        expect(fixture.client.captureSpanCalls, hasLength(1));
        expect(fixture.client.captureSpanCalls.first.span, equals(span));
        expect(fixture.client.captureSpanCalls.first.scope, isNotNull);
      });

      test('does nothing when hub is closed', () async {
        final hub = fixture.getSut();
        final span = hub.startInactiveSpan('test-span');
        await hub.close();

        await hub.captureSpan(span);

        expect(fixture.client.captureSpanCalls, isEmpty);
      });

      test('does nothing when tracing is disabled', () async {
        final hub = fixture.getSut(tracesSampleRate: null);

        final span = hub.startInactiveSpan('test-span');
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
