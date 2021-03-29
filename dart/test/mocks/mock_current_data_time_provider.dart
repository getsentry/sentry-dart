import 'package:sentry/src/current_date_provider.dart';

class MockCurrentDateTimeProvider implements CurrentDateTimeProvider {
  var dateTimesToReturn = <int>[];

  @override
  int currentDateTime() {
    // TODO: implement currentDateTime
    if (dateTimesToReturn.length > 1) {
      return dateTimesToReturn.removeAt(0);
    } else {
      return dateTimesToReturn.first;
    }
  }
}
