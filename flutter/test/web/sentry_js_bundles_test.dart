@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';

void main() {
  group('Sentry Js Bundles', () {
    Future<void> checkScript(Map<String, String> script) async {
      final response = await http.get(Uri.parse(script['url']!));

      expect(response.statusCode, 200);
      expect(response.body, isNotEmpty);
    }

    test('Production script is accessible', () async {
      await Future.forEach(productionScripts,
          (Map<String, String> script) async {
        await checkScript(script);
      });
    });

    test('Debug script is accessible', () async {
      await Future.forEach(debugScripts, (Map<String, String> script) async {
        await checkScript(script);
      });
    });
  });
}
