import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../mocks.mocks.dart';

void main() {
  test('fullDisplayed called with correct spanId', () async {
    final mockTimeToDisplayTracker = MockTimeToDisplayTracker();
    when(mockTimeToDisplayTracker.reportFullyDisplayed(
            spanId: anyNamed('spanId')))
        .thenAnswer((_) => Future<void>.value());

    final options = SentryFlutterOptions();
    options.timeToDisplayTracker = mockTimeToDisplayTracker;

    final mockHub = MockHub();
    when(mockHub.options).thenReturn(options);

    final spanId = SpanId.newId();
    final display = SentryDisplay(spanId, hub: mockHub);

    await display.reportFullyDisplayed();

    verify(mockTimeToDisplayTracker.reportFullyDisplayed(spanId: spanId));
  });
}
