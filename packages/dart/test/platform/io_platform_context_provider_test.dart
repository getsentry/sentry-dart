@TestOn('vm')
library;

import 'dart:io';

import 'package:sentry/src/platform/io_platform_context_provider.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('IoPlatformContextProvider', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('buildContexts', () {
      test('returns device with processor count', () async {
        final contexts = await fixture.getSut().buildContexts();

        expect(contexts.device?.processorCount, Platform.numberOfProcessors);
      });

      test('does not include hostname when sendDefaultPii is false', () async {
        final contexts =
            await fixture.getSut(includePii: false).buildContexts();

        expect(contexts.device?.name, isNull);
      });

      test('includes hostname when sendDefaultPii is true', () async {
        final contexts = await fixture.getSut(includePii: true).buildContexts();

        expect(contexts.device?.name, Platform.localHostname);
      });

      test('returns operating system with name', () async {
        final contexts = await fixture.getSut().buildContexts();

        expect(contexts.operatingSystem?.name, isNotNull);
      });

      test('returns Dart runtime with parsed version and raw description',
          () async {
        final contexts = await fixture.getSut().buildContexts();

        final dart =
            contexts.runtimes.firstWhere((runtime) => runtime.name == 'Dart');
        expect(dart.version, isNotNull);
        expect(Platform.version, contains(dart.version.toString()));
        expect(dart.rawDescription, Platform.version);
      });

      test('returns culture with locale and timezone', () async {
        final contexts = await fixture.getSut().buildContexts();

        expect(contexts.culture?.locale, Platform.localeName);
        expect(contexts.culture?.timezone, isNotNull);
      });

      test('returns app with current RSS as app memory', () async {
        final contexts = await fixture.getSut().buildContexts();

        expect(contexts.app?.appMemory, isNotNull);
        expect(contexts.app!.appMemory!, greaterThan(0));
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
  IoPlatformContextProvider getSut({bool includePii = false}) {
    final options = defaultTestOptions()..sendDefaultPii = includePii;
    return IoPlatformContextProvider(options);
  }
}
