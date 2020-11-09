import 'package:sentry/src/transport/http_transport.dart';
import 'package:test/test.dart';

void main() {
  test("options can't be null", () {
    expect(() => HttpTransport(null), throwsArgumentError);
  });
}
