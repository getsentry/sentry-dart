import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/client_reports/discarded_event.dart';
import 'package:sentry/src/transport/data_category.dart';
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

          final span =
              hub.startInactiveSpan('test-span', attributes: attributes);

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
              traceLifecycle: SentryTraceLifecycle.stream,
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

        test('uses startTimestamp when provided', () {
          final hub = fixture.getSut();
          final past = DateTime(2024, 1, 1, 12, 0, 0);

          final span = hub.startInactiveSpan('test-span', startTimestamp: past)
              as RecordingSentrySpanV2;

          expect(span.startTimestamp, equals(past.toUtc()));
        });

        test('uses clock when startTimestamp is not provided', () {
          final hub = fixture.getSut();

          final span =
              hub.startInactiveSpan('test-span') as RecordingSentrySpanV2;

          expect(span.startTimestamp, isNotNull);
          expect(span.startTimestamp.difference(DateTime.now()).abs(),
              lessThan(Duration(seconds: 1)));
        });

        test('child span uses startTimestamp when provided', () {
          final hub = fixture.getSut();
          final past = DateTime(2024, 1, 1, 12, 0, 0);

          final root = hub.startInactiveSpan('root', parentSpan: null);
          final child = hub.startInactiveSpan('child',
              parentSpan: root, startTimestamp: past) as RecordingSentrySpanV2;

          expect(child.startTimestamp, equals(past.toUtc()));
          expect(child.startTimestamp.isUtc, isTrue);
        });
      });

      group('when ignoreSpans rules are configured', () {
        test('returns NoOpSentrySpanV2 for matching rule', () {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-span'),
          ];
          final hub = fixture.getSut();

          final span = hub.startInactiveSpan('ignored-span');

          expect(span, isA<NoOpSentrySpanV2>());
        });

        test('returns RecordingSentrySpanV2 for non-matching rule', () {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-span'),
          ];
          final hub = fixture.getSut();

          final span = hub.startInactiveSpan('other-span');

          expect(span, isA<RecordingSentrySpanV2>());
        });

        test('re-parents through multiple consecutive ignored spans', () {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-1'),
            IgnoreSpanRule.nameEquals('ignored-2'),
            IgnoreSpanRule.nameEquals('ignored-3'),
          ];
          final hub = fixture.getSut();

          final root = hub.startInactiveSpan('root', parentSpan: null);
          final ignored1 = hub.startInactiveSpan('ignored-1', parentSpan: root);
          final ignored2 =
              hub.startInactiveSpan('ignored-2', parentSpan: ignored1);
          final ignored3 =
              hub.startInactiveSpan('ignored-3', parentSpan: ignored2);
          final child = hub.startInactiveSpan('child', parentSpan: ignored3);

          expect(child, isA<RecordingSentrySpanV2>());
          expect(child.parentSpan, same(root));
        });

        test('re-parents correctly with ignored spans at different levels', () {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-span'),
          ];
          final hub = fixture.getSut();

          // root -> ignored -> child1 -> ignored -> child2
          final root = hub.startInactiveSpan('root', parentSpan: null);
          final ignored1 =
              hub.startInactiveSpan('ignored-span', parentSpan: root);
          final child1 = hub.startInactiveSpan('child1', parentSpan: ignored1);
          final ignored2 =
              hub.startInactiveSpan('ignored-span', parentSpan: child1);
          final child2 = hub.startInactiveSpan('child2', parentSpan: ignored2);

          expect(child1, isA<RecordingSentrySpanV2>());
          expect(child1.parentSpan, same(root));
          expect(child2, isA<RecordingSentrySpanV2>());
          expect(child2.parentSpan, same(child1));
        });

        test('cascades NoOp to attempted children of an ignored segment', () {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-root'),
          ];
          final hub = fixture.getSut();

          final ignored =
              hub.startInactiveSpan('ignored-root', parentSpan: null);
          final child = hub.startInactiveSpan('child', parentSpan: ignored);
          final grandchild =
              hub.startInactiveSpan('grandchild', parentSpan: child);

          expect(ignored, isA<NoOpSentrySpanV2>());
          expect(child, same(NoOpSentrySpanV2.instance));
          expect(grandchild, same(NoOpSentrySpanV2.instance));
        });

        test('does not re-parent when parent is unsampled NoOp', () {
          final hub = fixture.getSut(tracesSampleRate: 0.0);

          final unsampledRoot = hub.startInactiveSpan('root', parentSpan: null);
          expect(unsampledRoot, isA<NoOpSentrySpanV2>());

          final child =
              hub.startInactiveSpan('child', parentSpan: unsampledRoot);

          expect(child, isA<NoOpSentrySpanV2>());
          expect((child as NoOpSentrySpanV2).isIgnored, isFalse);
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
          final child1 = hub.startInactiveSpan('child1', parentSpan: parent);
          final child2 = hub.startInactiveSpan('child2', parentSpan: parent);

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

          final rootSpan =
              hub.startInactiveSpan('root-span') as RecordingSentrySpanV2;
          final childSpan = hub.startInactiveSpan('child-span',
              parentSpan: rootSpan) as RecordingSentrySpanV2;

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

          final rootSpan =
              hub.startInactiveSpan('root-span') as RecordingSentrySpanV2;
          final child1 = hub.startInactiveSpan('child-1', parentSpan: rootSpan)
              as RecordingSentrySpanV2;
          final child2 = hub.startInactiveSpan('child-2', parentSpan: child1)
              as RecordingSentrySpanV2;
          final child3 = hub.startInactiveSpan('child-3', parentSpan: child2)
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
          final childSpan =
              hub.startInactiveSpan('child-span', parentSpan: rootSpan);
          expect(childSpan, isA<NoOpSentrySpanV2>());
        });

        test('sampleRand is reused across all spans in the same trace', () {
          final hub = fixture.getSut(tracesSampleRate: 1.0);

          final rootSpan =
              hub.startInactiveSpan('root-span') as RecordingSentrySpanV2;
          final sampleRand = rootSpan.samplingDecision.sampleRand;

          // Create multiple child spans
          final child1 = hub.startInactiveSpan('child-1', parentSpan: rootSpan)
              as RecordingSentrySpanV2;
          final child2 = hub.startInactiveSpan('child-2', parentSpan: rootSpan)
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

    group('startSpanSync', () {
      group('with sync callback', () {
        test('returns callback result', () {
          final hub = fixture.getSut();

          final result = hub.startSpanSync('test-span', (span) => 42);

          expect(result, equals(42));
        });

        test('ends span after callback completes', () {
          final hub = fixture.getSut();
          late RecordingSentrySpanV2 capturedSpan;

          hub.startSpanSync('test-span', (span) {
            capturedSpan = span as RecordingSentrySpanV2;
            expect(span.isEnded, isFalse);
          });

          expect(capturedSpan.isEnded, isTrue);
        });

        test('provides RecordingSentrySpanV2 when tracing is enabled', () {
          final hub = fixture.getSut();

          hub.startSpanSync('test-span', (span) {
            expect(span, isA<RecordingSentrySpanV2>());
          });
        });

        test('provides NoOpSentrySpanV2 when tracing is disabled', () {
          final hub = fixture.getSut(tracesSampleRate: null);

          hub.startSpanSync('test-span', (span) {
            expect(span, isA<NoOpSentrySpanV2>());
          });
        });

        test('sets error status and ends span on throw', () {
          final hub = fixture.getSut();
          late RecordingSentrySpanV2 capturedSpan;

          expect(
            () => hub.startSpanSync('test-span', (span) {
              capturedSpan = span as RecordingSentrySpanV2;
              throw StateError('test error');
            }),
            throwsA(isA<StateError>()),
          );

          expect(capturedSpan.isEnded, isTrue);
          expect(capturedSpan.status, equals(SentrySpanStatusV2.error));
        });

        test(
          'provides NoOpSentrySpanV2 and still calls callback when hub is closed',
          () async {
            final hub = fixture.getSut();
            await hub.close();
            var callbackInvoked = false;

            final result = hub.startSpanSync('test-span', (span) {
              callbackInvoked = true;
              expect(span, isA<NoOpSentrySpanV2>());
              return 42;
            });

            expect(callbackInvoked, isTrue);
            expect(result, equals(42));
            expect(fixture.client.captureSpanCalls, isEmpty);
          },
        );

        test(
          'provides NoOpSentrySpanV2 and still calls callback when traceLifecycle is static',
          () {
            final hub = fixture.getSut(
              traceLifecycle: SentryTraceLifecycle.static,
            );
            var callbackInvoked = false;

            final result = hub.startSpanSync('test-span', (span) {
              callbackInvoked = true;
              expect(span, isA<NoOpSentrySpanV2>());
              return 42;
            });

            expect(callbackInvoked, isTrue);
            expect(result, equals(42));
            expect(fixture.client.captureSpanCalls, isEmpty);
          },
        );
      });

      group('with zone-based scope forking', () {
        test('nested calls build correct parent-child chain', () {
          final hub = fixture.getSut();
          late SentrySpanV2 outerSpan;
          late SentrySpanV2 innerSpan;

          hub.startSpanSync('outer', (span) {
            outerSpan = span;
            hub.startSpanSync('inner', (span) {
              innerSpan = span;
            });
          });

          expect(outerSpan.parentSpan, isNull);
          expect(innerSpan.parentSpan, equals(outerSpan));
        });

        test('sibling spans share same parent', () {
          final hub = fixture.getSut();
          late SentrySpanV2 parent;
          late SentrySpanV2 child1;
          late SentrySpanV2 child2;

          hub.startSpanSync('parent', (span) {
            parent = span;
            hub.startSpanSync('child-1', (span) {
              child1 = span;
            });
            hub.startSpanSync('child-2', (span) {
              child2 = span;
            });
          });

          expect(child1.parentSpan, equals(parent));
          expect(child2.parentSpan, equals(parent));
        });

        test('does not leak active span to outer scope after callback', () {
          final hub = fixture.getSut();

          hub.startSpanSync('outer', (span) {
            final outerActiveSpan = hub.getActiveSpan();
            expect(outerActiveSpan, equals(span));

            hub.startSpanSync('inner', (innerSpan) {
              final innerActiveSpan = hub.getActiveSpan();
              expect(innerActiveSpan, equals(innerSpan));
            });

            final afterInner = hub.getActiveSpan();
            expect(afterInner, equals(span));
          });
        });

        test('does not pollute hub scope active span', () {
          final hub = fixture.getSut();

          expect(hub.scope.activeSpan, isNull);

          hub.startSpanSync('test-span', (span) {});

          expect(hub.scope.activeSpan, isNull);
        });
      });

      group('with explicit parentSpan', () {
        test('uses provided parent instead of zone-resolved parent', () {
          final hub = fixture.getSut();
          late SentrySpanV2 explicitParent;
          late SentrySpanV2 child;

          hub.startSpanSync('explicit-parent', (span) {
            explicitParent = span;
          });

          hub.startSpanSync('outer', (outerSpan) {
            hub.startSpanSync('child', (span) {
              child = span;
            }, parentSpan: explicitParent);
          });

          expect(child.parentSpan, equals(explicitParent));
        });

        test('creates root span when parentSpan is null', () {
          final hub = fixture.getSut();
          late SentrySpanV2 child;

          hub.startSpanSync('outer', (outerSpan) {
            hub.startSpanSync('root-child', (span) {
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

          hub.startSpanSync('test-span', (span) {
            expect(span.attributes, equals(attrs));
          }, attributes: attrs);
        });
      });

      group('with startTimestamp', () {
        test('uses provided timestamp', () {
          final hub = fixture.getSut();
          final past = DateTime(2024, 1, 1, 12, 0, 0);
          late RecordingSentrySpanV2 capturedSpan;

          hub.startSpanSync('test-span', (span) {
            capturedSpan = span as RecordingSentrySpanV2;
          }, startTimestamp: past);

          expect(capturedSpan.startTimestamp, equals(past.toUtc()));
          expect(capturedSpan.startTimestamp.isUtc, isTrue);
        });
      });

      group('when capturing spans', () {
        test('captures span via client on end', () {
          final hub = fixture.getSut();

          hub.startSpanSync('test-span', (span) {});

          expect(fixture.client.captureSpanCalls, hasLength(1));
        });

        test('captures all nested spans', () {
          final hub = fixture.getSut();

          hub.startSpanSync('outer', (span) {
            hub.startSpanSync('inner', (span) {});
          });

          expect(fixture.client.captureSpanCalls, hasLength(2));
        });
      });

      group('when ignoreSpans rules are configured', () {
        test('does not capture ignored span', () {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-span'),
          ];
          final hub = fixture.getSut();

          hub.startSpanSync('ignored-span', (span) {});

          expect(fixture.client.captureSpanCalls, isEmpty);
        });

        test('still returns sync callback result for ignored span', () {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-span'),
          ];
          final hub = fixture.getSut();

          final result = hub.startSpanSync('ignored-span', (span) => 42);

          expect(result, equals(42));
        });
      });
    });

    group('startSpan', () {
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

        test('provides RecordingSentrySpanV2 when tracing is enabled',
            () async {
          final hub = fixture.getSut();

          await hub.startSpan('test-span', (span) async {
            expect(span, isA<RecordingSentrySpanV2>());
          });
        });

        test('provides NoOpSentrySpanV2 when tracing is disabled', () async {
          final hub = fixture.getSut(tracesSampleRate: null);

          await hub.startSpan('test-span', (span) async {
            expect(span, isA<NoOpSentrySpanV2>());
          });
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

        test(
          'provides NoOpSentrySpanV2 and still calls callback when hub is closed',
          () async {
            final hub = fixture.getSut();
            await hub.close();
            var callbackInvoked = false;

            final result = await hub.startSpan('test-span', (span) async {
              callbackInvoked = true;
              expect(span, isA<NoOpSentrySpanV2>());
              return 42;
            });

            expect(callbackInvoked, isTrue);
            expect(result, equals(42));
            expect(fixture.client.captureSpanCalls, isEmpty);
          },
        );

        test(
          'provides NoOpSentrySpanV2 and still calls callback when traceLifecycle is static',
          () async {
            final hub = fixture.getSut(
              traceLifecycle: SentryTraceLifecycle.static,
            );
            var callbackInvoked = false;

            final result = await hub.startSpan('test-span', (span) async {
              callbackInvoked = true;
              expect(span, isA<NoOpSentrySpanV2>());
              return 42;
            });

            expect(callbackInvoked, isTrue);
            expect(result, equals(42));
            expect(fixture.client.captureSpanCalls, isEmpty);
          },
        );
      });

      group('with zone-based scope forking', () {
        test('nested calls build correct parent-child chain', () async {
          final hub = fixture.getSut();
          late SentrySpanV2 outerSpan;
          late SentrySpanV2 innerSpan;

          await hub.startSpan('outer', (span) async {
            outerSpan = span;
            await hub.startSpan('inner', (span) async {
              innerSpan = span;
              await Future<void>.delayed(Duration.zero);
            });
          });

          expect(outerSpan.parentSpan, isNull);
          expect(innerSpan.parentSpan, equals(outerSpan));
        });

        test('sibling spans share same parent', () async {
          final hub = fixture.getSut();
          late SentrySpanV2 parent;
          late SentrySpanV2 child1;
          late SentrySpanV2 child2;

          await hub.startSpan('parent', (span) async {
            parent = span;
            await hub.startSpan('child-1', (span) async {
              child1 = span;
            });
            await hub.startSpan('child-2', (span) async {
              child2 = span;
            });
          });

          expect(child1.parentSpan, equals(parent));
          expect(child2.parentSpan, equals(parent));
        });

        test('does not leak active span to outer scope after callback',
            () async {
          final hub = fixture.getSut();

          await hub.startSpan('outer', (span) async {
            final outerActiveSpan = hub.getActiveSpan();
            expect(outerActiveSpan, equals(span));

            await hub.startSpan('inner', (innerSpan) async {
              final innerActiveSpan = hub.getActiveSpan();
              expect(innerActiveSpan, equals(innerSpan));
              await Future<void>.delayed(Duration.zero);
            });

            final afterInner = hub.getActiveSpan();
            expect(afterInner, equals(span));
          });
        });

        test('parallel async spans share same parent', () async {
          final hub = fixture.getSut();
          late SentrySpanV2 parent;
          late SentrySpanV2 child1;
          late SentrySpanV2 child2;

          await hub.startSpan('parent', (span) async {
            parent = span;
            final f1 = hub.startSpan('child-1', (span) async {
              child1 = span;
              await Future<void>.delayed(Duration.zero);
            });
            final f2 = hub.startSpan('child-2', (span) async {
              child2 = span;
              await Future<void>.delayed(Duration.zero);
            });
            await Future.wait([f1, f2]);
          });

          expect(child1.parentSpan, equals(parent));
          expect(child2.parentSpan, equals(parent));
        });

        test('does not pollute hub scope active span', () async {
          final hub = fixture.getSut();

          expect(hub.scope.activeSpan, isNull);

          await hub.startSpan('test-span', (span) async {});

          expect(hub.scope.activeSpan, isNull);
        });
      });

      group('with explicit parentSpan', () {
        test('uses provided parent instead of zone-resolved parent', () async {
          final hub = fixture.getSut();
          late SentrySpanV2 explicitParent;
          late SentrySpanV2 child;

          await hub.startSpan('explicit-parent', (span) async {
            explicitParent = span;
          });

          await hub.startSpan('outer', (outerSpan) async {
            await hub.startSpan('child', (span) async {
              child = span;
            }, parentSpan: explicitParent);
          });

          expect(child.parentSpan, equals(explicitParent));
        });

        test('creates root span when parentSpan is null', () async {
          final hub = fixture.getSut();
          late SentrySpanV2 child;

          await hub.startSpan('outer', (outerSpan) async {
            await hub.startSpan('root-child', (span) async {
              child = span;
            }, parentSpan: null);
          });

          expect(child.parentSpan, isNull);
        });
      });

      group('with attributes', () {
        test('passes attributes to created span', () async {
          final hub = fixture.getSut();
          final attrs = {
            'http.method': SentryAttribute.string('GET'),
            'http.status_code': SentryAttribute.int(200),
          };

          await hub.startSpan('test-span', (span) async {
            expect(span.attributes, equals(attrs));
          }, attributes: attrs);
        });
      });

      group('with startTimestamp', () {
        test('uses provided timestamp', () async {
          final hub = fixture.getSut();
          final past = DateTime(2024, 1, 1, 12, 0, 0);
          late RecordingSentrySpanV2 capturedSpan;

          await hub.startSpan('test-span', (span) async {
            capturedSpan = span as RecordingSentrySpanV2;
          }, startTimestamp: past);

          expect(capturedSpan.startTimestamp, equals(past.toUtc()));
          expect(capturedSpan.startTimestamp.isUtc, isTrue);
        });
      });

      group('when capturing spans', () {
        test('captures span via client on end', () async {
          final hub = fixture.getSut();

          await hub.startSpan('test-span', (span) async {});

          expect(fixture.client.captureSpanCalls, hasLength(1));
        });

        test('captures all nested spans', () async {
          final hub = fixture.getSut();

          await hub.startSpan('outer', (span) async {
            await hub.startSpan('inner', (span) async {});
          });

          expect(fixture.client.captureSpanCalls, hasLength(2));
        });
      });

      group('when ignoreSpans rules are configured', () {
        test('does not capture ignored span', () async {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-span'),
          ];
          final hub = fixture.getSut();

          await hub.startSpan('ignored-span', (span) async {});

          expect(fixture.client.captureSpanCalls, isEmpty);
        });

        test('still returns async callback result for ignored span', () async {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-span'),
          ];
          final hub = fixture.getSut();

          final result =
              await hub.startSpan('ignored-span', (span) async => 42);

          expect(result, equals(42));
        });
      });
    });

    group('when mixing startSpan and startSpanSync', () {
      test('parents sync child to async parent', () async {
        final hub = fixture.getSut();
        late SentrySpanV2 asyncParent;
        late SentrySpanV2 syncChild;

        await hub.startSpan('async-parent', (span) async {
          asyncParent = span;
          hub.startSpanSync('sync-child', (span) {
            syncChild = span;
          });
        });

        expect(asyncParent.parentSpan, isNull);
        expect(syncChild.parentSpan, equals(asyncParent));
      });

      test('parents async child to sync parent', () async {
        final hub = fixture.getSut();
        late SentrySpanV2 syncParent;
        late SentrySpanV2 asyncChild;

        await hub.startSpanSync('sync-parent', (span) {
          syncParent = span;
          return hub.startSpan('async-child', (span) async {
            asyncChild = span;
          });
        });

        expect(syncParent.parentSpan, isNull);
        expect(asyncChild.parentSpan, equals(syncParent));
      });

      test('builds correct chain with deeply nested alternating calls',
          () async {
        final hub = fixture.getSut();
        late SentrySpanV2 span1;
        late SentrySpanV2 span2;
        late SentrySpanV2 span3;
        late SentrySpanV2 span4;

        await hub.startSpan('async-1', (s1) async {
          span1 = s1;
          hub.startSpanSync('sync-2', (s2) {
            span2 = s2;
            hub.startSpanSync('sync-3', (s3) {
              span3 = s3;
            });
          });
          await hub.startSpan('async-4', (s4) async {
            span4 = s4;
          });
        });

        expect(span1.parentSpan, isNull);
        expect(span2.parentSpan, equals(span1));
        expect(span3.parentSpan, equals(span2));
        expect(span4.parentSpan, equals(span1));
      });

      test('resolves active span to sync child inside async parent', () async {
        final hub = fixture.getSut();

        await hub.startSpan('async-parent', (asyncSpan) async {
          hub.startSpanSync('sync-child', (syncSpan) {
            expect(hub.getActiveSpan(), equals(syncSpan));
          });
          expect(hub.getActiveSpan(), equals(asyncSpan));
        });
      });

      test('resolves active span to async child inside sync parent', () async {
        final hub = fixture.getSut();

        await hub.startSpanSync('sync-parent', (syncSpan) {
          expect(hub.getActiveSpan(), equals(syncSpan));
          return hub.startSpan('async-child', (asyncSpan) async {
            expect(hub.getActiveSpan(), equals(asyncSpan));
          });
        });
      });

      test('parents sibling sync and async children to same parent', () async {
        final hub = fixture.getSut();
        late SentrySpanV2 parent;
        late SentrySpanV2 syncChild;
        late SentrySpanV2 asyncChild;

        await hub.startSpan('parent', (span) async {
          parent = span;
          hub.startSpanSync('sync-child', (span) {
            syncChild = span;
          });
          await hub.startSpan('async-child', (span) async {
            asyncChild = span;
          });
        });

        expect(syncChild.parentSpan, equals(parent));
        expect(asyncChild.parentSpan, equals(parent));
      });

      test('does not pollute hub scope active span', () async {
        final hub = fixture.getSut();

        expect(hub.scope.activeSpan, isNull);

        await hub.startSpan('async-parent', (span) async {
          hub.startSpanSync('sync-child', (span) {});
        });

        expect(hub.scope.activeSpan, isNull);
      });

      test('captures all nested spans', () async {
        final hub = fixture.getSut();

        await hub.startSpan('async-root', (span) async {
          hub.startSpanSync('sync-child', (span) {});
          await hub.startSpan('async-child', (span) async {});
        });

        expect(fixture.client.captureSpanCalls, hasLength(3));
      });
    });

    group('when using idle spans', () {
      test('uses startTimestamp when provided', () {
        final hub = fixture.getSut();
        final past = DateTime(2024, 1, 1, 12, 0, 0);

        final idleSpan = hub.startIdleSpan(
          'idle-root',
          startTimestamp: past,
          idleTimeout: Duration(seconds: 1),
          finalTimeout: Duration(seconds: 2),
        ) as RecordingSentrySpanV2;

        expect(idleSpan.startTimestamp, equals(past.toUtc()));
        expect(idleSpan.startTimestamp.isUtc, isTrue);
      });

      test('clears active idle span when ended directly', () async {
        final hub = fixture.getSut();
        final idleSpan = hub.startIdleSpan(
          'idle-root',
          idleTimeout: Duration(seconds: 1),
          finalTimeout: Duration(seconds: 2),
        ) as RecordingSentrySpanV2;
        expect(hub.getActiveSpan(), isA<IdleRecordingSentrySpanV2>());

        final activeIdleSpan = hub.getActiveSpan() as IdleRecordingSentrySpanV2;
        activeIdleSpan
          ..status = SentrySpanStatusV2.cancelled
          ..end();
        await Future<void>.delayed(Duration.zero);

        expect(idleSpan.isEnded, isTrue);
        expect(idleSpan.status, equals(SentrySpanStatusV2.cancelled));
        expect(hub.getActiveSpan(), isNull);
      });

      test('clears active idle span when idle span instance is ended directly',
          () async {
        final hub = fixture.getSut();
        final idleSpan = hub.startIdleSpan(
          'idle-root',
          idleTimeout: Duration(seconds: 1),
          finalTimeout: Duration(seconds: 2),
        ) as RecordingSentrySpanV2;
        expect(hub.getActiveSpan(), isA<IdleRecordingSentrySpanV2>());

        idleSpan.end();
        await Future<void>.delayed(Duration.zero);

        expect(idleSpan.isEnded, isTrue);
        expect(hub.getActiveSpan(), isNull);
      });

      test('does not extend idle timeout when unrelated spans end', () async {
        final hub = fixture.getSut();
        final idleSpan = hub.startIdleSpan(
          'idle-root',
          idleTimeout: Duration(milliseconds: 120),
          finalTimeout: Duration(seconds: 2),
        ) as RecordingSentrySpanV2;

        await Future<void>.delayed(Duration(milliseconds: 40));
        final unrelatedSpan = hub.startInactiveSpan(
          'unrelated-root',
          parentSpan: null,
        ) as RecordingSentrySpanV2;
        unrelatedSpan.end();

        await Future<void>.delayed(Duration(milliseconds: 90));
        expect(idleSpan.isEnded, isTrue);
      });

      test('finishes active children when final timeout is reached', () async {
        final hub = fixture.getSut();
        final idleSpan = hub.startIdleSpan(
          'idle-root',
          idleTimeout: Duration(seconds: 1),
          finalTimeout: Duration(milliseconds: 180),
        ) as RecordingSentrySpanV2;

        final childSpan =
            hub.startInactiveSpan('child') as RecordingSentrySpanV2;

        await Future<void>.delayed(Duration(milliseconds: 240));
        expect(idleSpan.isEnded, isTrue);
        expect(idleSpan.status, equals(SentrySpanStatusV2.deadlineExceeded));
        expect(childSpan.isEnded, isTrue);
        expect(childSpan.status, equals(SentrySpanStatusV2.cancelled));
        expect(childSpan.endTimestamp, isNotNull);
        expect(idleSpan.endTimestamp, isNotNull);
        final endTimestampDelta =
            idleSpan.endTimestamp!.difference(childSpan.endTimestamp!).abs();
        expect(endTimestampDelta, lessThan(Duration(milliseconds: 10)));
      });

      test('trims idle span end timestamp to latest finished child', () async {
        final hub = fixture.getSut();
        final idleSpan = hub.startIdleSpan(
          'idle-root',
          idleTimeout: Duration(milliseconds: 100),
          finalTimeout: Duration(seconds: 1),
          trimIdleSpanEndTimestamp: true,
        ) as RecordingSentrySpanV2;

        final childSpan =
            hub.startInactiveSpan('child') as RecordingSentrySpanV2;
        await Future<void>.delayed(Duration(milliseconds: 40));
        childSpan.end();

        await Future<void>.delayed(Duration(milliseconds: 140));
        expect(idleSpan.isEnded, isTrue);
        expect(idleSpan.endTimestamp, equals(childSpan.endTimestamp));
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
        // using startInactiveSpan for convenience in creating a span
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

    group('when recording client reports for span discards', () {
      group('with ignoreSpans rule matching a segment', () {
        test('records ignored span outcome for the segment', () {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-root'),
          ];
          final hub = fixture.getSut();

          hub.startInactiveSpan('ignored-root', parentSpan: null);

          expect(
            fixture.recorder.discardedEvents,
            [_discarded(DiscardReason.ignored, DataCategory.span)],
          );
        });

        test('records ignored span outcome for each attempted child', () {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-root'),
          ];
          final hub = fixture.getSut();

          final ignored =
              hub.startInactiveSpan('ignored-root', parentSpan: null);
          hub.startInactiveSpan('child-1', parentSpan: ignored);
          hub.startInactiveSpan('child-2', parentSpan: ignored);

          expect(
            fixture.recorder.discardedEvents,
            List.filled(
              3,
              _discarded(DiscardReason.ignored, DataCategory.span),
            ),
          );
        });
      });

      group('with ignoreSpans rule matching a child', () {
        test('records one ignored span outcome for the matched child', () {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-child'),
          ];
          final hub = fixture.getSut();

          final root = hub.startInactiveSpan('root', parentSpan: null);
          hub.startInactiveSpan('ignored-child', parentSpan: root);

          expect(
            fixture.recorder.discardedEvents,
            [_discarded(DiscardReason.ignored, DataCategory.span)],
          );
        });

        test(
            'does not record an outcome for re-parented grandchildren that do '
            'not match a rule', () {
          fixture.options.ignoreSpans = [
            IgnoreSpanRule.nameEquals('ignored-child'),
          ];
          final hub = fixture.getSut();

          final root = hub.startInactiveSpan('root', parentSpan: null);
          final ignored =
              hub.startInactiveSpan('ignored-child', parentSpan: root);
          hub.startInactiveSpan('grandchild', parentSpan: ignored);

          expect(
            fixture.recorder.discardedEvents,
            [_discarded(DiscardReason.ignored, DataCategory.span)],
          );
        });
      });

      group('with a negatively sampled root span', () {
        test('records sample_rate span outcome for the root', () {
          final hub = fixture.getSut(tracesSampleRate: 0.0);

          hub.startInactiveSpan('root', parentSpan: null);

          expect(
            fixture.recorder.discardedEvents,
            [_discarded(DiscardReason.sampleRate, DataCategory.span)],
          );
        });

        test('records sample_rate span outcome for each attempted child', () {
          final hub = fixture.getSut(tracesSampleRate: 0.0);

          final unsampled = hub.startInactiveSpan('root', parentSpan: null);
          hub.startInactiveSpan('child-1', parentSpan: unsampled);
          hub.startInactiveSpan('child-2', parentSpan: unsampled);

          expect(
            fixture.recorder.discardedEvents,
            List.filled(
              3,
              _discarded(DiscardReason.sampleRate, DataCategory.span),
            ),
          );
        });
      });

      group('with a negatively sampled idle span', () {
        test('records sample_rate span outcome', () {
          final hub = fixture.getSut(tracesSampleRate: 0.0);

          hub.startIdleSpan('idle');

          expect(
            fixture.recorder.discardedEvents,
            [_discarded(DiscardReason.sampleRate, DataCategory.span)],
          );
        });
      });
    });
  });
}

Matcher _discarded(DiscardReason reason, DataCategory category,
    {int quantity = 1}) {
  return isA<DiscardedEvent>()
      .having((e) => e.reason, 'reason', reason)
      .having((e) => e.category, 'category', category)
      .having((e) => e.quantity, 'quantity', quantity);
}

class Fixture {
  final client = MockSentryClient();
  final recorder = MockClientReportRecorder();

  final options = defaultTestOptions();

  Hub getSut({
    double? tracesSampleRate = 1.0,
    TracesSamplerCallback? tracesSampler,
    bool debug = false,
    SentryTraceLifecycle traceLifecycle = SentryTraceLifecycle.stream,
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
