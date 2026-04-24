@TestOn('browser')
library;

import 'package:sentry/sentry.dart';
import 'package:sentry/src/platform/web_platform_context_provider.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  group('WebPlatformContextProvider', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('buildContexts', () {
      test('returns device with screen dimensions and density', () async {
        final contexts = await fixture.getSut().buildContexts();

        expect(contexts.device?.screenHeightPixels, isNotNull);
        expect(contexts.device?.screenWidthPixels, isNotNull);
        expect(contexts.device?.screenDensity, isNotNull);
      });

      test('returns device with online status', () async {
        final contexts = await fixture.getSut().buildContexts();

        expect(contexts.device?.online, isNotNull);
      });

      test('returns device with portrait or landscape orientation', () async {
        final contexts = await fixture.getSut().buildContexts();

        final orientation = contexts.device?.orientation;
        expect(
          orientation == SentryOrientation.portrait ||
              orientation == SentryOrientation.landscape ||
              orientation == null,
          isTrue,
        );
      });

      test('returns culture with timezone', () async {
        final contexts = await fixture.getSut().buildContexts();

        expect(contexts.culture?.timezone, isNotNull);
      });

      test('does not emit operating system', () async {
        final contexts = await fixture.getSut().buildContexts();

        expect(contexts.operatingSystem, isNull);
      });

      test('returns a fresh Contexts instance on each call', () async {
        final sut = fixture.getSut();

        final first = await sut.buildContexts();
        final second = await sut.buildContexts();

        expect(identical(first, second), isFalse);
      });
    });
  });
}

class Fixture {
  WebPlatformContextProvider getSut() {
    return WebPlatformContextProvider(web.window);
  }
}
