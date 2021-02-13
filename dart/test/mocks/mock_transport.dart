import 'package:sentry/sentry.dart';

class MockTransport implements Transport {
  List<SentryEvent> events = [];

  bool called(int calls) {
    return events.length == calls;
  }

  @override
  Future<SentryId> send(SentryEvent event) async {
    events.add(event);
    return SentryId.empty();
  }
}
