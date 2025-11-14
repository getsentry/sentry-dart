import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('SentryPrivacyOptions', () {
    test('toJson', () {
      final privacyOptions = SentryPrivacyOptions();
      privacyOptions.maskAllImages = false;
      privacyOptions.maskAllText = false;
      privacyOptions.mask(name: 'TestName', description: 'TestDesc');

      final json = privacyOptions.toJson();
      expect(json, {
        'maskAllText': false,
        'maskAllImages': false,
        'maskAssetImages': false,
        'maskingRules': ['TestName: TestDesc']
      });
    });
  });
}
