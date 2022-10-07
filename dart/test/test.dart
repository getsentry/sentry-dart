import 'package:sentry/sentry.dart';

void test() {
  final transaction = Sentry.getSpan();

  // Record amount of memory used
  transaction?.setMeasurement('memoryUsed', 123,
      unit: SentryMeasurementUnit.byte);

  // Record time when Footer component renders on page
  transaction?.setMeasurement('ui.footerComponent.render', 1.3,
      unit: SentryMeasurementUnit.second);

  // Record amount of times localStorage was read
  transaction?.setMeasurement('localStorageRead', 4);
}
