@TestOn('browser')
library;

import 'package:sentry_grpc/sentry_grpc.dart';
import 'package:test/test.dart';

void main() {
  group('web compile smoke test', () {
    test('SentryGrpcInterceptor can be constructed', () {
      final interceptor = SentryGrpcInterceptor();
      expect(interceptor, isNotNull);
    });
  });
}
