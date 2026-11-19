import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/platform/platform.dart' as platform;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/c/binding.dart' as binding;
import 'package:sentry_flutter/src/native/c/native_database_path.dart';
import 'package:sentry_flutter/src/native/c/sentry_native.dart';
import 'package:sentry_flutter/src/native/c/sentry_native_worker.dart';
import 'package:sentry_flutter/src/native/factory.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';

enum NativeBackend { default_, empty, crashpad, breakpad, inproc, none }

extension on NativeBackend {
  NativeBackend get actualValue =>
      (this == NativeBackend.default_ || this == NativeBackend.empty)
      ? NativeBackend.breakpad
      : this;
}

// NOTE: Don't run/debug this main(), it likely won't work.
// You can use main() in `sentry_native_test.dart`.
// A native library remains loaded for the lifetime of this process.
// CI invokes this suite once per backend; local runs default to Breakpad.
NativeBackend get configuredNativeBackend => NativeBackend.values.byName(
  Platform.environment['SENTRY_TEST_NATIVE_BACKEND'] ?? 'default_',
);

/// Builds sentry-native for [backend] and points [SentryNative] at it.
Future<NativeTestHelper> setUpNativeBackend(NativeBackend backend) async {
  final currentPlatform = platform.Platform();
  final repoRootDir = Directory.current.path.endsWith('/test')
      ? Directory.current.parent.path
      : Directory.current.path;

  late final List<String> expectedDistFiles;
  if (backend.actualValue == NativeBackend.crashpad) {
    expectedDistFiles = currentPlatform.isWindows
        ? ['sentry.dll', 'crashpad_handler.exe', 'crashpad_wer.dll']
        : ['libsentry.so', 'crashpad_handler'];
  } else {
    expectedDistFiles = currentPlatform.isWindows
        ? ['sentry.dll']
        : ['libsentry.so'];
  }

  final helper = NativeTestHelper(
    repoRootDir,
    backend,
    expectedDistFiles,
    '$repoRootDir/temp/native-test-${backend.name}',
  );

  final distribution = await helper._buildSentryNative();
  SentryNative.dynamicLibraryDirectory = distribution;
  SentryNative.crashpadPath = null;
  if (backend.actualValue == NativeBackend.crashpad) {
    SentryNative.crashpadPath =
        '${helper.buildOutputDir}${expectedDistFiles.firstWhere((f) => f.contains('crashpad_handler'))}';
  }
  return helper;
}

void main() {
  final currentPlatform = platform.Platform();
  final backend = configuredNativeBackend;
  group(backend.name, () {
    late final NativeTestHelper helper;
    setUpAll(() async => helper = await setUpNativeBackend(backend));

    late SentryNative sut;
    late SentryFlutterOptions options;

    setUp(() {
      options = SentryFlutterOptions(dsn: fakeDsn)
        ..nativeDatabasePath = '${helper.nativeTestRoot}/db'
        // ignore: invalid_use_of_internal_member
        ..automatedTestMode = true
        ..debug = true;
      sut = createBinding(options) as SentryNative;
    });

    test('native CMake was configured with configured backend', () async {
      final cmakeCacheTxt = await File(
        '${helper.cmakeBuildDir}/CMakeCache.txt',
      ).readAsLines();
      expect(
        cmakeCacheTxt,
        contains('SENTRY_BACKEND:STRING=${backend.actualValue.name}'),
      );
    });

    test('expected output files', () {
      for (var name in helper.expectedDistFiles) {
        if (!File('${helper.buildOutputDir}$name').existsSync()) {
          fail('Native distribution file $name does not exist');
        }
      }
    });

    if (backend.actualValue == NativeBackend.breakpad) {
      test(
        'does not fetch Crashpad',
        () {
          expect(
            File(
              '${helper.cmakeBuildDir}/_deps/sn-src/'
              'external/crashpad/CMakeLists.txt',
            ).existsSync(),
            isFalse,
          );
        },
        // Windows fetches the full release zip, which includes Crashpad.
        skip: Platform.isWindows
            ? 'the release zip contains the Crashpad sources'
            : false,
      );

      test('does not bundle a crash handler', () {
        expect(
          Directory(
            helper.buildOutputDir,
          ).listSync().map((file) => file.uri.pathSegments.last),
          isNot(anyElement(contains('crashpad'))),
        );
      });
    }

    if (backend == NativeBackend.default_) {
      test('delivers the native minidump and scope after restart', () async {
        final database = await Directory.systemTemp.createTemp('sentry-crash-');
        addTearDown(() => database.delete(recursive: true));
        final envelope = File('${database.path}/captured.envelope');
        final executable =
            '${helper.buildOutputDir}sentry-native-flutter-test'
            '${Platform.isWindows ? '.exe' : ''}';
        final crashed = await Process.run(executable, [
          'crash',
          database.path,
          envelope.path,
        ]);
        expect(crashed.exitCode, isNot(0));
        expect(envelope.existsSync(), isFalse);

        final restarted = await Process.run(executable, [
          'restart',
          database.path,
          envelope.path,
        ]);
        expect(restarted.exitCode, 0, reason: '${restarted.stderr}');
        final contents = latin1.decode(await envelope.readAsBytes());
        expect(contents, contains('"attachment_type":"event.minidump"'));
        expect(contents, contains('"migration":"breakpad"'));
      });
    }

    test('options', () {
      options
        ..debug = true
        ..sampleRate = 0.25
        ..environment = 'foo'
        ..release = 'foo@bar+1'
        ..enableAutoSessionTracking = true
        ..dist = 'distfoo'
        ..maxBreadcrumbs = 42;

      final cOptions = sut.createOptions(options);
      try {
        expect(
          SentryNative.native
              .options_get_dsn(cOptions)
              .cast<Utf8>()
              .toDartString(),
          fakeDsn,
        );
        expect(SentryNative.native.options_get_sample_rate(cOptions), 0.25);
        expect(
          SentryNative.native
              .options_get_environment(cOptions)
              .cast<Utf8>()
              .toDartString(),
          'foo',
        );
        expect(
          SentryNative.native
              .options_get_release(cOptions)
              .cast<Utf8>()
              .toDartString(),
          'foo@bar+1',
        );
        expect(
          SentryNative.native.options_get_auto_session_tracking(cOptions),
          1,
        );
        expect(SentryNative.native.options_get_max_breadcrumbs(cOptions), 42);
      } finally {
        SentryNative.native.options_free(cOptions);
      }
    });

    test('SDK version', () {
      expect(
        helper.configuredSentryNativeVersion.length,
        greaterThanOrEqualTo(5),
      );
      expect(
        SentryNative.native.sdk_version().cast<Utf8>().toDartString(),
        helper.configuredSentryNativeVersion,
      );
    });

    test('SDK name', () {
      expect(
        SentryNative.native.sdk_name().cast<Utf8>().toDartString(),
        'sentry.native.flutter',
      );
    });

    test('init', () async {
      addTearDown(sut.close);
      await _init(sut);
    });

    test('init on Windows returns before sentry_init() finishes', () async {
      addTearDown(sut.close);

      expect(sut.init(MockHub()), isNull);
      final tag = sut.setTag('fixture-key', 'fixture-value');
      expect(tag, isA<Future<void>>());

      await tag;
      expect(await sut.worker!.target, isNotNull);
    }, testOn: 'windows');

    test('scope calls run on the worker after init', () async {
      await _init(sut);
      expect(await sut.worker!.target, isNotNull);

      await sut.addBreadcrumb(Breadcrumb(message: 'fixture-message'));
      await sut.setUser(SentryUser(id: 'fixture-id'));
      await sut.setContexts('fixture-key', {'object': Object()});
      await sut.setExtra('fixture-key', ReceivePort());
      await sut.removeExtra('fixture-key');
      await sut.removeContexts('fixture-key');
      await sut.setTag('fixture-key', 'fixture-value');
      await sut.removeTag('fixture-key');
      await sut.setUser(null);

      await sut.close();
    }, testOn: 'windows');

    test(
      'inits on the calling isolate when the worker fails to start',
      () async {
        final spawn = SentryNativeWorker.spawnWorkerFn;
        SentryNativeWorker.spawnWorkerFn = (_, _) async =>
            throw StateError('fixture-error');
        addTearDown(() => SentryNativeWorker.spawnWorkerFn = spawn);

        await _init(sut);

        expect(await sut.worker!.target, isNull);
        await sut.setTag('fixture-key', 'fixture-value');
        await sut.close();
      },
      testOn: 'windows',
    );

    test('a scope value that fails to serialize is logged, not thrown', () {
      // ignore: invalid_use_of_internal_member
      options.automatedTestMode = false;

      expect(() => sut.setUser(_UnserializableUser()), returnsNormally);
      expect(
        () => sut.addBreadcrumb(_UnserializableBreadcrumb()),
        returnsNormally,
      );
    });

    test('awaited scope updates are in the native scope', () async {
      Map<String, Object?>? captured;
      final beforeSend = NativeCallable<_EventFunction>.isolateLocal((
        binding.sentry_value_u event,
        Pointer<Void> hint,
        Pointer<Void> userData,
      ) {
        captured = {
          'user': event.get('user').get('id').castPrimitive<String>(),
          'tag': event.get('tags').get('fixture-key').castPrimitive<String>(),
        };
        SentryNative.native.value_decref(event);
        return SentryNative.native.value_new_null();
      });
      addTearDown(beforeSend.close);
      final native = _BeforeSendNative(options, beforeSend.nativeFunction);
      addTearDown(native.close);
      await _init(native);

      await native.setUser(SentryUser(id: 'fixture-id'));
      await native.setTag('fixture-key', 'fixture-value');
      _captureMessage();
      expect(captured, {'user': 'fixture-id', 'tag': 'fixture-value'});

      await native.setUser(null);
      await native.removeTag('fixture-key');
      _captureMessage();
      // Without a user, native adds its own installation id.
      expect(captured?['user'], isNot('fixture-id'));
      expect(captured?['tag'], isNull);
    });

    test(
      'init creates native database path directory when configured',
      () async {
        final dbDir = Directory(
          '${helper.nativeTestRoot}/db-${backend.actualValue.name}',
        );
        if (dbDir.existsSync()) {
          dbDir.deleteSync(recursive: true);
        }

        options.nativeDatabasePath = dbDir.path;

        addTearDown(() {
          if (dbDir.existsSync()) {
            dbDir.deleteSync(recursive: true);
          }
        });
        addTearDown(sut.close);

        await _init(sut);

        expect(dbDir.existsSync(), isTrue);
      },
    );

    group(
      'with unwritable working directory and no database path',
      () {
        // The fallback is under LOCALAPPDATA on Windows and XDG_CACHE_HOME on
        // Linux.
        final sep = currentPlatform.isWindows ? '\\' : '/';
        late Directory appDir;

        Directory databaseDir() => Directory(
          '${appDir.path}${sep}sentry-${dsnHash(options.dsn ?? '')}',
        );

        setUp(() {
          final root = Directory(
            '${helper.nativeTestRoot}/fallback-${backend.actualValue.name}',
          );
          if (root.existsSync()) {
            root.deleteSync(recursive: true);
          }
          // A file where `.sentry-native` would go blocks the default database.
          final workingDir = Directory('${root.path}/cwd')
            ..createSync(recursive: true);
          File('${workingDir.path}/.sentry-native').writeAsStringSync('');
          final fallbackRoot = Directory('${root.path}/fallback')
            ..createSync(recursive: true);
          final exeName = Platform.resolvedExecutable
              .split(RegExp(r'[\\/]'))
              .last
              .replaceFirst(RegExp(r'\.exe$', caseSensitive: false), '');
          appDir = Directory('${fallbackRoot.path}$sep$exeName');

          SentryNative.workingDirectory = () => workingDir.path;
          SentryNative.environment = () => currentPlatform.isWindows
              ? {'LOCALAPPDATA': fallbackRoot.path}
              : {'XDG_CACHE_HOME': fallbackRoot.path};
          options.nativeDatabasePath = null;

          addTearDown(() {
            SentryNative.workingDirectory = () => Directory.current.path;
            SentryNative.environment = () => Platform.environment;
            if (root.existsSync()) {
              root.deleteSync(recursive: true);
            }
          });
        });

        test(
          'init creates database in the fallback dir when app folder is missing',
          () async {
            expect(appDir.existsSync(), isFalse);
            addTearDown(sut.close);

            await _init(sut);

            expect(databaseDir().existsSync(), isTrue);
          },
        );

        test(
          'init creates database in an existing fallback app folder',
          () async {
            final existingFile = File('${appDir.path}${sep}settings.json')
              ..createSync(recursive: true)
              ..writeAsStringSync('{}');
            addTearDown(sut.close);

            await _init(sut);

            expect(databaseDir().existsSync(), isTrue);
            expect(existingFile.readAsStringSync(), '{}');
          },
        );
      },
      skip: currentPlatform.isWindows || currentPlatform.isLinux
          ? false
          : 'The database fallback only applies to Windows and Linux',
    );

    test('app start', () {
      expect(sut.fetchNativeAppStart(), null);
    });

    test('hang tracking', () {
      sut.pauseAppHangTracking();
      sut.resumeAppHangTracking();
    });

    test('setUser', () async {
      final user = SentryUser(
        id: "fixture-id",
        username: 'username',
        email: 'mail@domain.tld',
        ipAddress: '1.2.3.4',
        name: 'User Name',
        data: {
          'str': 'foo-bar',
          'double': 1.0,
          'int': 1,
          'int64': 0x7FFFFFFF + 1,
          'boo': true,
          'inner-map': {'str': 'inner'},
          'unsupported': Object(),
        },
      );

      await sut.setUser(user);
    });

    test('int64 value round-trips through native', () {
      const value = 0x7FFFFFFF + 1; // 2147483648, just outside int32 range
      final cValue = dynamicToNativeValue(value)!;
      expect(
        SentryNative.native.value_get_type(cValue),
        binding.sentry_value_type_t.SENTRY_VALUE_TYPE_INT64,
      );
      expect(cValue.castPrimitive<int>(), value);
    });

    test('addBreadcrumb', () async {
      final breadcrumb = Breadcrumb(
        type: 'type',
        message: 'message',
        category: 'category',
      );
      await sut.addBreadcrumb(breadcrumb);
    });

    test('clearBreadcrumbs', () async {
      await sut.clearBreadcrumbs();
    });

    test('displayRefreshRate', () async {
      expect(sut.displayRefreshRate(), isNull);
    });

    test('setContexts', () async {
      final value = {'object': Object()};
      await sut.setContexts('fixture-key', value);
    });

    test('removeContexts', () async {
      await sut.removeContexts('fixture-key');
    });

    test('setExtra', () async {
      final value = {'object': Object()};
      await sut.setExtra('fixture-key', value);
    });

    test('removeExtra', () async {
      await sut.removeExtra('fixture-key');
    });

    test('setTag', () async {
      await sut.setTag('fixture-key', 'fixture-value');
    });

    test('removeTag', () async {
      await sut.removeTag('fixture-key');
    });

    test('captureEnvelope', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      expect(() => sut.captureEnvelope(data), throwsUnsupportedError);
    });

    test('updateSessionForDroppedEventNonTerminating', () async {
      expect(
        () => sut.updateSessionForDroppedEventNonTerminating(true),
        throwsUnsupportedError,
      );
    });

    test('loadContexts', () async {
      expect(await sut.loadContexts(), isNull);
    });

    test('loadDebugImages', () async {
      addTearDown(sut.close);
      await _init(sut);
      final list = await sut.loadDebugImages(SentryStackTrace(frames: []));
      expect(list, isNotEmpty);
      expect(list![0].type, currentPlatform.isWindows ? 'pe' : 'elf');
      expect(list[0].debugId!.length, greaterThan(30));
      expect(
        list[0].debugFile,
        currentPlatform.isWindows ? isNotEmpty : isNull,
      );
      expect(list[0].imageSize, greaterThan(0));
      expect(list[0].imageAddr, startsWith('0x'));
      expect(list[0].imageAddr?.length, greaterThan(2));
      expect(list[0].codeId!.length, greaterThan(10));
      expect(list[0].codeFile, isNotEmpty);
      expect(File(list[0].codeFile!), (File file) => file.existsSync());
    });
  });
}

class NativeTestHelper {
  final String repoRootDir;
  final NativeBackend nativeBackend;
  final List<String> expectedDistFiles;
  final String nativeTestRoot;
  late final cmakeBuildDir = '$nativeTestRoot/build';
  late final cmakeConfDir = '$nativeTestRoot/conf';
  late final buildOutputDir = '$nativeTestRoot/dist/';

  NativeTestHelper(
    this.repoRootDir,
    this.nativeBackend,
    this.expectedDistFiles,
    this.nativeTestRoot,
  );

  /// Runs [command] with command's stdout and stderr being forwrarded to
  /// test runner's respective streams. It buffers stdout and returns it.
  ///
  /// Returns [_CommandResult] with exitCode and stdout as a single sting
  Future<void> _exec(String executable, List<String> arguments) async {
    final env = Map.of(Platform.environment);
    if (nativeBackend != NativeBackend.default_) {
      env['SENTRY_NATIVE_BACKEND'] = nativeBackend == NativeBackend.empty
          ? ''
          : nativeBackend.name;
    } else {
      env.remove('SENTRY_NATIVE_BACKEND');
    }

    final process = await Process.start(
      executable,
      arguments,
      environment: env,
      includeParentEnvironment: false,
      workingDirectory: repoRootDir,
    );

    // forward standard streams
    final streams = [
      stderr.addStream(process.stderr),
      stdout.addStream(process.stdout),
    ];
    final exitCode = await process.exitCode;
    await Future.wait(streams);
    if (exitCode != 0) {
      throw Exception(
        "$executable ${arguments.join(' ')} failed with exit code $exitCode",
      );
    }
  }

  /// Compile sentry-native using CMake, as if it was part of a Flutter app.
  /// Returns the directory containing built libraries
  Future<String> _buildSentryNative() async {
    final currentPlatform = platform.Platform();
    Directory(cmakeConfDir).createSync(recursive: true);
    Directory(buildOutputDir).createSync(recursive: true);
    File(
      '$repoRootDir/test/native/c/crash_test.c',
    ).copySync('$cmakeConfDir/main.c');
    File('$cmakeConfDir/CMakeLists.txt').writeAsStringSync('''
cmake_minimum_required(VERSION 3.14)
project(sentry-native-flutter-test)
add_subdirectory(../../../${currentPlatform.operatingSystem.name} plugin)
add_executable(\${CMAKE_PROJECT_NAME} main.c)
target_link_libraries(\${CMAKE_PROJECT_NAME} PRIVATE sentry_flutter_plugin)
if(UNIX)
  set_target_properties(\${CMAKE_PROJECT_NAME} PROPERTIES INSTALL_RPATH "\$ORIGIN")
endif()

# Same as generated_plugins.cmake
list(APPEND PLUGIN_BUNDLED_LIBRARIES \$<TARGET_FILE:sentry_flutter_plugin>)
list(APPEND PLUGIN_BUNDLED_LIBRARIES \${sentry_flutter_bundled_libraries})
install(TARGETS \${CMAKE_PROJECT_NAME} RUNTIME DESTINATION "${buildOutputDir.replaceAll('\\', '/')}" COMPONENT Runtime)
install(FILES "\${PLUGIN_BUNDLED_LIBRARIES}" DESTINATION "${buildOutputDir.replaceAll('\\', '/')}" COMPONENT Runtime)
set(CMAKE_INSTALL_PREFIX "${buildOutputDir.replaceAll('\\', '/')}")
''');
    await _exec('cmake', ['-B', cmakeBuildDir, cmakeConfDir]);
    await _exec('cmake', [
      '--build',
      cmakeBuildDir,
      '--config',
      'Release',
      '--parallel',
    ]);
    // Installation does not remove handlers left by a previous backend.
    final distribution = Directory(buildOutputDir);
    if (distribution.existsSync()) {
      distribution.deleteSync(recursive: true);
    }
    await _exec('cmake', ['--install', cmakeBuildDir, '--config', 'Release']);
    if (currentPlatform.isLinux &&
        nativeBackend.actualValue == NativeBackend.crashpad) {
      await _exec('chmod', ['+x', '$buildOutputDir/crashpad_handler']);
    }
    return buildOutputDir;
  }

  late final configuredSentryNativeVersion =
      File('$repoRootDir/sentry-native/CMakeCache.txt')
          .readAsLinesSync()
          .map((line) => line.startsWith('version=') ? line.substring(8) : null)
          .firstWhere((line) => line != null)!;
}

/// On Windows init returns before `sentry_init()` finishes.
Future<void> _init(SentryNative native) async {
  await native.init(MockHub());
  await native.worker?.initialized;
}

typedef _EventFunction =
    binding.sentry_value_u Function(
      binding.sentry_value_u event,
      Pointer<Void> hint,
      Pointer<Void> userData,
    );

DynamicLibrary _sentryLibrary() => DynamicLibrary.open(
  '${SentryNative.dynamicLibraryDirectory}'
  '${Platform.isWindows ? 'sentry.dll' : 'libsentry.so'}',
);

final class _Uuid extends Struct {
  @Array(16)
  external Array<Uint8> bytes;
}

/// Runs before_send on the calling thread with the native scope applied.
void _captureMessage() {
  final library = _sentryLibrary();
  final newMessageEvent = library
      .lookupFunction<
        binding.sentry_value_u Function(Int32, Pointer<Utf8>, Pointer<Utf8>),
        binding.sentry_value_u Function(int, Pointer<Utf8>, Pointer<Utf8>)
      >('sentry_value_new_message_event');
  final captureEvent = library
      .lookupFunction<
        _Uuid Function(binding.sentry_value_u),
        _Uuid Function(binding.sentry_value_u)
      >('sentry_capture_event');
  final text = 'fixture-message'.toNativeUtf8();
  try {
    captureEvent(newMessageEvent(0, nullptr, text));
  } finally {
    malloc.free(text);
  }
}

class _BeforeSendNative extends SentryNative {
  _BeforeSendNative(super.options, this._beforeSend);

  final Pointer<NativeFunction<_EventFunction>> _beforeSend;

  @override
  Pointer<binding.sentry_options_s> createOptions(
    SentryFlutterOptions options,
  ) {
    final cOptions = super.createOptions(options);
    _sentryLibrary().lookupFunction<
      Void Function(
        Pointer<binding.sentry_options_s>,
        Pointer<NativeFunction<_EventFunction>>,
        Pointer<Void>,
      ),
      void Function(
        Pointer<binding.sentry_options_s>,
        Pointer<NativeFunction<_EventFunction>>,
        Pointer<Void>,
      )
    >('sentry_options_set_before_send')(cOptions, _beforeSend, nullptr);
    return cOptions;
  }
}

class _UnserializableUser extends SentryUser {
  _UnserializableUser() : super(id: 'fixture-id');

  @override
  Map<String, dynamic> toJson() => throw StateError('fixture-error');
}

class _UnserializableBreadcrumb extends Breadcrumb {
  @override
  Map<String, dynamic> toJson() => throw StateError('fixture-error');
}
