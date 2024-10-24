// import 'package:flutter_test/flutter_test.dart';
// import 'package:mockito/mockito.dart';
// import 'package:sentry_flutter/src/frame_tracking/span_frame_metrics_collector.dart';
// import 'package:sentry_flutter/src/frame_tracking/sentry_delayed_frames_tracker.dart';
// import 'package:sentry_flutter/src/frame_tracking/span_frame_metrics_calculator.dart';
//
// import '../mocks.dart';
// import '../mocks.mocks.dart';
//
// void main() {
//   late Fixture fixture;
//
//   setUp(() {
//     fixture = Fixture();
//   });
//
//   test('clear() clears frame tracker and active spans', () async {
//     final sut = fixture.getSut();
//     final mockSpan = MockSentrySpan();
//     when(mockSpan.startTimestamp).thenReturn(DateTime.now());
//     when(fixture.mockFrameTracker.expectedFrameDuration)
//         .thenReturn(Duration(milliseconds: 16));
//
//     await sut.onSpanStarted(mockSpan);
//     expect(sut.activeSpans, isNotEmpty);
//
//     sut.clear();
//
//     verify(fixture.mockFrameTracker.clear()).called(1);
//     expect(sut.activeSpans, isEmpty);
//   });
//
//   test('does not process span if frames tracking is disabled', () async {
//     fixture.options.enableFramesTracking = false;
//     final sut = fixture.getSut();
//
//     final span = MockSentrySpan();
//     await sut.onSpanStarted(span);
//
//     verifyNever(fixture.mockFrameTracker.resume());
//     expect(sut.activeSpans, isEmpty);
//   });
//
//   test('does not process span if expected frame duration is not initialized',
//       () async {
//     when(fixture.mockFrameTracker.expectedFrameDuration).thenReturn(null);
//     when(fixture.mockNativeBinding.displayRefreshRate())
//         .thenAnswer((_) async => null);
//     final sut = fixture.getSut();
//
//     final span = MockSentrySpan();
//     await sut.onSpanStarted(span);
//
//     verifyNever(fixture.mockFrameTracker.resume());
//     expect(sut.activeSpans, isEmpty);
//   });
//
//   test('initializes expected frame duration on first span', () async {
//     when(fixture.mockFrameTracker.expectedFrameDuration).thenReturn(null);
//     when(fixture.mockNativeBinding.displayRefreshRate())
//         .thenAnswer((_) async => 60);
//     final sut = fixture.getSut();
//
//     final span = MockSentrySpan();
//     when(span.startTimestamp).thenReturn(DateTime.now());
//     await sut.onSpanStarted(span);
//
//     verify(fixture.mockFrameTracker
//             .setExpectedFrameDuration(Duration(milliseconds: 16)))
//         .called(1);
//     verify(fixture.mockFrameTracker.resume()).called(1);
//     expect(sut.activeSpans, contains(span));
//   });
//
//   test('onSpanFinished calculates metrics for fully contained span', () async {
//     final sut = fixture.getSut();
//     final span = MockSentrySpan();
//     final startTimestamp = DateTime.now();
//     final endTimestamp = startTimestamp.add(Duration(seconds: 1));
//
//     when(span.startTimestamp).thenReturn(startTimestamp);
//     when(span.endTimestamp).thenReturn(endTimestamp);
//     when(span.isRootSpan).thenReturn(false);
//
//     when(fixture.mockFrameTracker.expectedFrameDuration)
//         .thenReturn(Duration(milliseconds: 16));
//     when(fixture.mockFrameTracker.getFramesIntersecting(
//       startTimestamp: startTimestamp,
//       endTimestamp: endTimestamp,
//     )).thenReturn([
//       SentryFrameTiming(
//           startTimestamp: startTimestamp.add(Duration(milliseconds: 100)),
//           endTimestamp: startTimestamp.add(Duration(milliseconds: 150))),
//       SentryFrameTiming(
//           startTimestamp: startTimestamp.add(Duration(milliseconds: 200)),
//           endTimestamp: startTimestamp.add(Duration(milliseconds: 220))),
//     ]);
//
//     await sut.onSpanStarted(span);
//     await sut.onSpanFinished(span, endTimestamp);
//
//     verify(span.setData('frames.total', 61)).called(1);
//     verify(span.setData('frames.slow', 2)).called(1);
//     verify(span.setData('frames.frozen', 0)).called(1);
//     verify(span.setData('frames.delay', 38)).called(1);
//
//     expect(sut.activeSpans, isEmpty);
//   });
//
//   test(
//       'onSpanFinished calculates metrics for partially contained span (starts before, ends within)',
//       () async {
//     final sut = fixture.getSut();
//     final span = MockSentrySpan();
//     final startTimestamp = DateTime.now();
//     final endTimestamp = startTimestamp.add(Duration(seconds: 1));
//
//     when(span.startTimestamp).thenReturn(startTimestamp);
//     when(span.endTimestamp).thenReturn(endTimestamp);
//     when(span.isRootSpan).thenReturn(false);
//
//     when(fixture.mockFrameTracker.expectedFrameDuration)
//         .thenReturn(Duration(milliseconds: 16));
//     when(fixture.mockFrameTracker.getFramesIntersecting(
//       startTimestamp: startTimestamp,
//       endTimestamp: endTimestamp,
//     )).thenReturn([
//       SentryFrameTiming(
//           startTimestamp: startTimestamp.subtract(Duration(milliseconds: 50)),
//           endTimestamp: startTimestamp.add(Duration(milliseconds: 50))),
//       SentryFrameTiming(
//           startTimestamp: startTimestamp.add(Duration(milliseconds: 100)),
//           endTimestamp: startTimestamp.add(Duration(milliseconds: 150))),
//     ]);
//
//     await sut.onSpanStarted(span);
//     await sut.onSpanFinished(span, endTimestamp);
//
//     verify(span.setData('frames.total', 59)).called(1);
//     verify(span.setData('frames.slow', 2)).called(1);
//     verify(span.setData('frames.frozen', 0)).called(1);
//     verify(span.setData('frames.delay', 76)).called(1);
//
//     expect(sut.activeSpans, isEmpty);
//   });
//
//   test(
//       'onSpanFinished calculates metrics for partially contained span (starts within, ends after)',
//       () async {
//     final sut = fixture.getSut();
//     final span = MockSentrySpan();
//     final startTimestamp = DateTime.now();
//     final endTimestamp = startTimestamp.add(Duration(seconds: 1));
//
//     when(span.startTimestamp).thenReturn(startTimestamp);
//     when(span.endTimestamp).thenReturn(endTimestamp);
//     when(span.isRootSpan).thenReturn(false);
//
//     when(fixture.mockFrameTracker.expectedFrameDuration)
//         .thenReturn(Duration(milliseconds: 16));
//     when(fixture.mockFrameTracker.getFramesIntersecting(
//       startTimestamp: startTimestamp,
//       endTimestamp: endTimestamp,
//     )).thenReturn([
//       SentryFrameTiming(
//           startTimestamp: startTimestamp.add(Duration(milliseconds: 900)),
//           endTimestamp: startTimestamp.add(Duration(milliseconds: 1100))),
//     ]);
//
//     await sut.onSpanStarted(span);
//     await sut.onSpanFinished(span, endTimestamp);
//
//     verify(span.setData('frames.total', 58)).called(1);
//     verify(span.setData('frames.slow', 1)).called(1);
//     verify(span.setData('frames.frozen', 0)).called(1);
//     verify(span.setData('frames.delay', 92)).called(1);
//
//     expect(sut.activeSpans, isEmpty);
//   });
//
//   test('onSpanFinished handles multiple overlapping spans correctly', () async {
//     final sut = fixture.getSut();
//     final span1 = MockSentrySpan();
//     final span2 = MockSentrySpan();
//     final startTimestamp1 = DateTime.now();
//     final startTimestamp2 = startTimestamp1.add(Duration(milliseconds: 200));
//     final endTimestamp1 = startTimestamp1.add(Duration(seconds: 1));
//     final endTimestamp2 = startTimestamp2.add(Duration(milliseconds: 200));
//
//     when(span1.startTimestamp).thenReturn(startTimestamp1);
//     when(span1.endTimestamp).thenReturn(endTimestamp1);
//     when(span1.isRootSpan).thenReturn(false);
//     when(span2.startTimestamp).thenReturn(startTimestamp2);
//     when(span2.endTimestamp).thenReturn(endTimestamp2);
//     when(span2.isRootSpan).thenReturn(false);
//
//     when(fixture.mockFrameTracker.expectedFrameDuration)
//         .thenReturn(Duration(milliseconds: 16));
//     when(fixture.mockFrameTracker.getFramesIntersecting(
//       startTimestamp: startTimestamp1,
//       endTimestamp: endTimestamp1,
//     )).thenReturn([
//       SentryFrameTiming(
//           startTimestamp: startTimestamp1.add(Duration(milliseconds: 100)),
//           endTimestamp: startTimestamp1.add(Duration(milliseconds: 150))),
//     ]);
//     when(fixture.mockFrameTracker.getFramesIntersecting(
//       startTimestamp: startTimestamp2,
//       endTimestamp: endTimestamp2,
//     )).thenReturn([
//       SentryFrameTiming(
//           startTimestamp: startTimestamp2.add(Duration(milliseconds: 100)),
//           endTimestamp: startTimestamp2.add(Duration(milliseconds: 180))),
//     ]);
//
//     await sut.onSpanStarted(span1);
//     await sut.onSpanStarted(span2);
//     await sut.onSpanFinished(span2, endTimestamp2);
//     await sut.onSpanFinished(span1, endTimestamp1);
//
//     verify(span1.setData('frames.total', 61)).called(1);
//     verify(span1.setData('frames.slow', 1)).called(1);
//     verify(span1.setData('frames.frozen', 0)).called(1);
//     verify(span1.setData('frames.delay', 34)).called(1);
//
//     verify(span2.setData('frames.total', 9)).called(1);
//     verify(span2.setData('frames.slow', 1)).called(1);
//     verify(span2.setData('frames.frozen', 0)).called(1);
//     verify(span2.setData('frames.delay', 64)).called(1);
//
//     expect(sut.activeSpans, isEmpty);
//   });
// }
//
// class Fixture {
//   final options = defaultTestOptions();
//   final mockNativeBinding = MockSentryNativeBinding();
//   final mockFrameTracker = MockSentryDelayedFramesTracker();
//
//   SpanFrameMetricsCollector getSut() {
//     return SpanFrameMetricsCollector(
//       options,
//       mockFrameTracker,
//       SpanFrameMetricsCalculator(),
//       mockNativeBinding,
//     );
//   }
// }
