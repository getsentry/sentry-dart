import 'package:sentry/src/hub.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('unsupported throwable types', () {
    test('wrapped string throwable does not throw when expanding', () async {
      final throwableHandler = fixture.sut;
      final unsupportedThrowable = 'test throwable';
      final wrappedThrowable =
          throwableHandler.wrapIfUnsupportedType(unsupportedThrowable);

      expect(() {
        fixture.expando[wrappedThrowable];
      }, returnsNormally);
    });

    test('wrapped int throwable does not throw when expanding', () async {
      final throwableHandler = fixture.sut;
      final unsupportedThrowable = 1;
      final wrappedThrowable =
          throwableHandler.wrapIfUnsupportedType(unsupportedThrowable);

      expect(() {
        fixture.expando[wrappedThrowable];
      }, returnsNormally);
    });

    test('wrapped double throwable does not throw when expanding', () async {
      final throwableHandler = fixture.sut;
      final unsupportedThrowable = 1.0;
      final wrappedThrowable =
          throwableHandler.wrapIfUnsupportedType(unsupportedThrowable);

      expect(() {
        fixture.expando[wrappedThrowable];
      }, returnsNormally);
    });

    test('wrapped bool throwable does not throw when expanding', () async {
      final throwableHandler = fixture.sut;
      final unsupportedThrowable = true;
      final wrappedThrowable =
          throwableHandler.wrapIfUnsupportedType(unsupportedThrowable);

      expect(() {
        fixture.expando[wrappedThrowable];
      }, returnsNormally);
    });

    test(
        'creating multiple instances of string wrapped exceptions accesses the same expando value',
        () async {
      final unsupportedThrowable = 'test throwable';
      final throwableHandler = fixture.sut;

      final first =
          throwableHandler.wrapIfUnsupportedType(unsupportedThrowable);
      fixture.expando[first] = 1;

      final second =
          throwableHandler.wrapIfUnsupportedType(unsupportedThrowable);
      expect(fixture.expando[second], 1);
      fixture.expando[second] = 2.0;

      final third =
          throwableHandler.wrapIfUnsupportedType(unsupportedThrowable);
      expect(fixture.expando[third], 2.0);
    });
  });

  group('supported throwable type', () {
    test('does not wrap exception if it is a supported type', () async {
      final supportedThrowable = Exception('test throwable');
      final result = fixture.sut.wrapIfUnsupportedType(supportedThrowable);

      expect(result, supportedThrowable);
    });
  });
}

class Fixture {
  final expando = Expando();

  UnsupportedThrowablesHandler get sut => UnsupportedThrowablesHandler();
}
