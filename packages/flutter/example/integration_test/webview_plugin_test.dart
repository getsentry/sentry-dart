import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('communicates with the native WebView controller', (
    tester,
  ) async {
    final controller = WebViewController();
    const userAgent = 'SentryWebViewIntegrationTest';
    await controller.setUserAgent(userAgent);
    expect(await controller.getUserAgent(), userAgent);
  }, skip: !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS));
}
