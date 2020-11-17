import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/default_integrations.dart';

void main() {
  const MethodChannel channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {});
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('nativeSdkIntegration wont throw', () async {
    await nativeSdkIntegration(SentryOptions(), channel);
  });
}
