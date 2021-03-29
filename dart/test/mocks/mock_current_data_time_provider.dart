import 'package:sentry/src/current_date_provider.dart';

class MockCurrentDateTimeProvider implements CurrentDateTimeProvider {
  var dateTimeToReturn = 0;

  @override
  int currentDateTime() {
    return dateTimeToReturn;
  }
}
