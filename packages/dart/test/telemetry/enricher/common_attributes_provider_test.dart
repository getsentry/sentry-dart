import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/enricher/common_attributes_provider.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';

void main() {
  group('CommonTelemetryAttributesProvider', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('includes SDK name and version', () async {
      final provider = fixture.getSut();
      final attributes = await provider.attributes(Object());

      expect(attributes[SemanticAttributesConstants.sentrySdkName]?.value,
          fixture.options.sdk.name);
      expect(attributes[SemanticAttributesConstants.sentrySdkVersion]?.value,
          fixture.options.sdk.version);
    });

    test('when environment is set includes environment attribute', () async {
      fixture.options.environment = 'production';
      final provider = fixture.getSut();

      final attributes = await provider.attributes(Object());

      expect(attributes[SemanticAttributesConstants.sentryEnvironment]?.value,
          'production');
    });

    test('when environment is null does not include environment attribute',
        () async {
      fixture.options.environment = null;
      final provider = fixture.getSut();

      final attributes = await provider.attributes(Object());

      expect(
          attributes.containsKey(SemanticAttributesConstants.sentryEnvironment),
          isFalse);
    });

    test('when release is set includes release attribute', () async {
      fixture.options.release = '1.0.0';
      final provider = fixture.getSut();

      final attributes = await provider.attributes(Object());

      expect(attributes[SemanticAttributesConstants.sentryRelease]?.value,
          '1.0.0');
    });

    test('when release is null does not include release attribute', () async {
      fixture.options.release = null;
      final provider = fixture.getSut();

      final attributes = await provider.attributes(Object());

      expect(attributes.containsKey(SemanticAttributesConstants.sentryRelease),
          isFalse);
    });

    group('when sendDefaultPii is true', () {
      test('includes user id when set', () async {
        fixture.options.sendDefaultPii = true;
        final provider = fixture.getSut();
        final scope = fixture.createScope(userId: 'user123');

        final attributes = await provider.attributes(Object(), scope: scope);

        expect(
            attributes[SemanticAttributesConstants.userId]?.value, 'user123');
      });

      test('includes user name when set', () async {
        fixture.options.sendDefaultPii = true;
        final provider = fixture.getSut();
        final scope = fixture.createScope(userName: 'John Doe');

        final attributes = await provider.attributes(Object(), scope: scope);

        expect(attributes[SemanticAttributesConstants.userName]?.value,
            'John Doe');
      });

      test('includes user email when set', () async {
        fixture.options.sendDefaultPii = true;
        final provider = fixture.getSut();
        final scope = fixture.createScope(userEmail: 'john@example.com');

        final attributes = await provider.attributes(Object(), scope: scope);

        expect(attributes[SemanticAttributesConstants.userEmail]?.value,
            'john@example.com');
      });

      test('includes all user attributes when all are set', () async {
        fixture.options.sendDefaultPii = true;
        final provider = fixture.getSut();
        final scope = fixture.createScope(
          userId: 'user123',
          userName: 'John Doe',
          userEmail: 'john@example.com',
        );

        final attributes = await provider.attributes(Object(), scope: scope);

        expect(
            attributes[SemanticAttributesConstants.userId]?.value, 'user123');
        expect(attributes[SemanticAttributesConstants.userName]?.value,
            'John Doe');
        expect(attributes[SemanticAttributesConstants.userEmail]?.value,
            'john@example.com');
      });

      test('does not include user attributes when user is null', () async {
        fixture.options.sendDefaultPii = true;
        final provider = fixture.getSut();
        final scope = Scope(fixture.options);

        final attributes = await provider.attributes(Object(), scope: scope);

        expect(attributes.containsKey(SemanticAttributesConstants.userId),
            isFalse);
        expect(attributes.containsKey(SemanticAttributesConstants.userName),
            isFalse);
        expect(attributes.containsKey(SemanticAttributesConstants.userEmail),
            isFalse);
      });

      test('does not include user attributes when scope is null', () async {
        fixture.options.sendDefaultPii = true;
        final provider = fixture.getSut();

        final attributes = await provider.attributes(Object(), scope: null);

        expect(attributes.containsKey(SemanticAttributesConstants.userId),
            isFalse);
        expect(attributes.containsKey(SemanticAttributesConstants.userName),
            isFalse);
        expect(attributes.containsKey(SemanticAttributesConstants.userEmail),
            isFalse);
      });
    });

    group('when sendDefaultPii is false', () {
      test('does not include user attributes', () async {
        fixture.options.sendDefaultPii = false;
        final provider = fixture.getSut();
        final scope = fixture.createScope(
          userId: 'user123',
          userName: 'John Doe',
          userEmail: 'john@example.com',
        );

        final attributes = await provider.attributes(Object(), scope: scope);

        expect(attributes.containsKey(SemanticAttributesConstants.userId),
            isFalse);
        expect(attributes.containsKey(SemanticAttributesConstants.userName),
            isFalse);
        expect(attributes.containsKey(SemanticAttributesConstants.userEmail),
            isFalse);
      });
    });

    test('includes OS name and version when available', () async {
      final provider = fixture.getSut();

      final attributes = await provider.attributes(Object());

      expect(
          attributes.containsKey(SemanticAttributesConstants.osName), isTrue);

      // Not always available on Linux, see [getSentryOperatingSystem] for more details.
      if (!fixture.options.platform.isLinux) {
        expect(attributes.containsKey(SemanticAttributesConstants.osVersion),
            isTrue);
      }
    });
  });
}

class Fixture {
  late SentryOptions options;

  Fixture() {
    options = defaultTestOptions();
  }

  CommonTelemetryAttributesProvider getSut() =>
      CommonTelemetryAttributesProvider(options);

  Scope createScope({
    String? userId,
    String? userName,
    String? userEmail,
  }) {
    final scope = Scope(options);

    if (userId != null || userName != null || userEmail != null) {
      scope.setUser(SentryUser(
        id: userId ?? 'test-user-id',
        name: userName,
        email: userEmail,
      ));
    }
    return scope;
  }
}
