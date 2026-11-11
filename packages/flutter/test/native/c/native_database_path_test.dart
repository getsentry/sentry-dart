@TestOn('vm')
library;

import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/native/c/native_database_path.dart';

void main() {
  group('resolveNativeDatabasePath', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() {
      fixture.dispose();
    });

    group('on Windows', () {
      test('with unwritable working directory returns LOCALAPPDATA path', () {
        fixture.blockWorkingDirectory();

        final path = fixture.getSut();

        expect(path, r'C:\Users\me\AppData\Local\my_app\sentry');
      });

      test('with unwritable working directory reads LOCALAPPDATA', () {
        fixture.blockWorkingDirectory();

        fixture.getSut();

        expect(fixture.environment.readKeys, ['LOCALAPPDATA']);
      });

      test('with writable working directory does not read environment', () {
        fixture.getSut();

        expect(fixture.environment.readKeys, isEmpty);
      });

      test('with access denied to working directory returns LOCALAPPDATA '
          'path', () {
        final path = IOOverrides.runZoned(
          fixture.getSut,
          createDirectory: AccessDeniedDirectory.new,
        );

        expect(path, r'C:\Users\me\AppData\Local\my_app\sentry');
      });

      test('with writable working directory returns null', () {
        final path = fixture.getSut();

        expect(path, isNull);
      });

      test('with configured path returns configured path', () {
        fixture.blockWorkingDirectory();

        final path = fixture.getSut(configuredPath: r'D:\custom\db');

        expect(path, r'D:\custom\db');
      });

      test('with configured path does not create default database', () {
        fixture.getSut(configuredPath: r'D:\custom\db');

        expect(fixture.defaultDatabase.existsSync(), isFalse);
      });

      test('without LOCALAPPDATA returns null', () {
        fixture.blockWorkingDirectory();
        fixture.environment = RecordingEnvironment({});

        final path = fixture.getSut();

        expect(path, isNull);
      });
    });

    group('on other platforms', () {
      test('with unwritable working directory returns null', () {
        fixture.blockWorkingDirectory();

        final path = fixture.getSut(isWindows: false);

        expect(path, isNull);
      });

      test('does not create default database', () {
        fixture.getSut(isWindows: false);

        expect(fixture.defaultDatabase.existsSync(), isFalse);
      });
    });
  });
}

class Fixture {
  final workingDirectory = Directory.systemTemp.createTempSync(
    'sentry-native-db-',
  );
  var environment = RecordingEnvironment({
    'LOCALAPPDATA': r'C:\Users\me\AppData\Local',
  });

  late final defaultDatabase = Directory(_defaultDatabasePath);

  String get _defaultDatabasePath =>
      '${workingDirectory.path}${Platform.pathSeparator}.sentry-native';

  /// Makes `.sentry-native` impossible to create by placing a file at that
  /// path, which simulates a read-only working directory on every platform.
  void blockWorkingDirectory() {
    File(_defaultDatabasePath).writeAsStringSync('');
  }

  String? getSut({String? configuredPath, bool isWindows = true}) =>
      resolveNativeDatabasePath(
        configuredPath: configuredPath,
        isWindows: isWindows,
        workingDirectory: workingDirectory.path,
        environment: environment,
        resolvedExecutable: r'C:\Program Files\MyApp\my_app.exe',
      );

  void dispose() => workingDirectory.deleteSync(recursive: true);
}

/// Environment map that records which variables were read.
class RecordingEnvironment extends MapView<String, String> {
  RecordingEnvironment(super.map);

  final readKeys = <Object?>[];

  @override
  String? operator [](Object? key) {
    readKeys.add(key);
    return super[key];
  }
}

/// Fails like Windows does when the process has no write access to a folder,
/// e.g. `C:\Windows\System32` for a packaged (MSIX) app.
class AccessDeniedDirectory extends Fake implements Directory {
  AccessDeniedDirectory(this.path);

  @override
  final String path;

  @override
  void createSync({bool recursive = false}) {
    throw FileSystemException(
      'Creation failed',
      path,
      const OSError('Access is denied.', 5),
    );
  }
}
