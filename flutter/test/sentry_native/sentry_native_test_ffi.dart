import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/platform/platform.dart' as platform;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/c/sentry_native.dart';
import 'package:sentry_flutter/src/native/factory.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

enum NativeBackend { default_, crashpad, breakpad, inproc, none }

extension on NativeBackend {
  NativeBackend get actualValue =>
      this == NativeBackend.default_ ? NativeBackend.crashpad : this;
}

// NOTE: Don't run/debug this main(), it likely won't work.
// You can use main() in `sentry_native_test.dart`.
void main() {
  final currentPlatform = platform.Platform();

  final repoRootDir = Directory.current.path.endsWith('/test')
      ? Directory.current.parent.path
      : Directory.current.path;

  // assert(NativeBackend.values.length == 4);
  for (final backend in NativeBackend.values) {
    group(backend.name, () {
      late final NativeTestHelper helper;
      setUpAll(() async {
        late final List<String> expectedDistFiles;
        if (backend.actualValue == NativeBackend.crashpad) {
          expectedDistFiles = currentPlatform.isWindows
              ? ['sentry.dll', 'crashpad_handler.exe', 'crashpad_wer.dll']
              : ['libsentry.so', 'crashpad_handler'];
        } else {
          expectedDistFiles =
              currentPlatform.isWindows ? ['sentry.dll'] : ['libsentry.so'];
        }

        helper = NativeTestHelper(
          repoRootDir,
          backend,
          expectedDistFiles,
          '$repoRootDir/temp/native-test-${backend.name}',
        );

        Directory.current = await helper._buildSentryNative();
        SentryNative.dynamicLibraryDirectory = '${Directory.current.path}/';
        if (backend.actualValue == NativeBackend.crashpad) {
          SentryNative.crashpadPath =
              '${Directory.current.path}/${expectedDistFiles.firstWhere((f) => f.contains('crashpad_handler'))}';
        }
      });

      late SentryNative sut;
      late SentryFlutterOptions options;

      setUp(() {
        options = SentryFlutterOptions(dsn: fakeDsn)
          // ignore: invalid_use_of_internal_member
          ..automatedTestMode = true
          ..debug = true;
        sut = createBinding(options) as SentryNative;
      });

      test('native CMake was configured with configured backend', () async {
        final cmakeCacheTxt =
            await File('${helper.cmakeBuildDir}/CMakeCache.txt').readAsLines();
        expect(cmakeCacheTxt,
            contains('SENTRY_BACKEND:STRING=${backend.actualValue.name}'));
      });

      test('expected output files', () {
        for (var name in helper.expectedDistFiles) {
          if (!File(name).existsSync()) {
            fail('Native distribution file $name does not exist');
          }
        }
      });

      test('options', () {
        options
          ..debug = true
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
              fakeDsn);
          expect(
              SentryNative.native
                  .options_get_environment(cOptions)
                  .cast<Utf8>()
                  .toDartString(),
              'foo');
          expect(
              SentryNative.native
                  .options_get_release(cOptions)
                  .cast<Utf8>()
                  .toDartString(),
              'foo@bar+1');
          expect(
              SentryNative.native.options_get_auto_session_tracking(cOptions),
              1);
          expect(SentryNative.native.options_get_max_breadcrumbs(cOptions), 42);
        } finally {
          SentryNative.native.options_free(cOptions);
        }
      });

      test('SDK version', () {
        expect(helper.configuredSentryNativeVersion.length,
            greaterThanOrEqualTo(5));
        expect(SentryNative.native.sdk_version().cast<Utf8>().toDartString(),
            helper.configuredSentryNativeVersion);
      });

      test('SDK name', () {
        expect(SentryNative.native.sdk_name().cast<Utf8>().toDartString(),
            'sentry.native.flutter');
      });

      test('init', () async {
        addTearDown(sut.close);
        await sut.init(MockHub());
      });

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
            'unsupported': Object()
          },
        );

        await sut.setUser(user);
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

      test('startProfiler', () {
        expect(
            () => sut.startProfiler(SentryId.newId()), throwsUnsupportedError);
      });

      test('discardProfiler', () async {
        expect(() => sut.discardProfiler(SentryId.newId()),
            throwsUnsupportedError);
      });

      test('collectProfile', () async {
        final traceId = SentryId.newId();
        const startTime = 42;
        const endTime = 50;
        expect(() => sut.collectProfile(traceId, startTime, endTime),
            throwsUnsupportedError);
      });

      test('captureEnvelope', () async {
        final data = Uint8List.fromList([1, 2, 3]);
        expect(() => sut.captureEnvelope(data, false), throwsUnsupportedError);
      });

      test('loadContexts', () async {
        expect(await sut.loadContexts(), isNull);
      });

      test('loadDebugImages', () async {
        final list = await sut.loadDebugImages(SentryStackTrace(frames: []));
        expect(list, isNotEmpty);
        expect(list![0].type, currentPlatform.isWindows ? 'pe' : 'elf');
        expect(list[0].debugId!.length, greaterThan(30));
        expect(
            list[0].debugFile, currentPlatform.isWindows ? isNotEmpty : isNull);
        expect(list[0].imageSize, greaterThan(0));
        expect(list[0].imageAddr, startsWith('0x'));
        expect(list[0].imageAddr?.length, greaterThan(2));
        expect(list[0].codeId!.length, greaterThan(10));
        expect(list[0].codeFile, isNotEmpty);
        expect(
          File(list[0].codeFile!),
          (File file) => file.existsSync(),
        );
      });
    });
  }
}

class NativeTestHelper {
  final String repoRootDir;
  final NativeBackend nativeBackend;
  final List<String> expectedDistFiles;
  final String nativeTestRoot;
  late final cmakeBuildDir = '$nativeTestRoot/build';
  late final cmakeConfDir = '$nativeTestRoot/conf';
  late final buildOutputDir = '$nativeTestRoot/dist/';

  NativeTestHelper(this.repoRootDir, this.nativeBackend, this.expectedDistFiles,
      this.nativeTestRoot);

  /// Runs [command] with command's stdout and stderr being forwrarded to
  /// test runner's respective streams. It buffers stdout and returns it.
  ///
  /// Returns [_CommandResult] with exitCode and stdout as a single sting
  Future<void> _exec(String executable, List<String> arguments) async {
    final env = Map.of(Platform.environment);
    if (nativeBackend != NativeBackend.default_) {
      env['SENTRY_NATIVE_BACKEND'] = nativeBackend.name;
    } else {
      env.remove('SENTRY_NATIVE_BACKEND');
    }

    final process = await Process.start(executable, arguments,
        environment: env, includeParentEnvironment: false);

    // forward standard streams
    unawaited(stderr.addStream(process.stderr));
    unawaited(stdout.addStream(process.stdout));

    int exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception(
          "$executable ${arguments.join(' ')} failed with exit code $exitCode");
    }
  }

  /// Compile sentry-native using CMake, as if it was part of a Flutter app.
  /// Returns the directory containing built libraries
  Future<String> _buildSentryNative() async {
    final currentPlatform = platform.Platform();
    if (!_builtVersionIsExpected()) {
      Directory(cmakeConfDir).createSync(recursive: true);
      Directory(buildOutputDir).createSync(recursive: true);
      File('$cmakeConfDir/main.c').writeAsStringSync('''
int main(int argc, char *argv[]) { return 0; }
''');
      File('$cmakeConfDir/CMakeLists.txt').writeAsStringSync('''
cmake_minimum_required(VERSION 3.14)
project(sentry-native-flutter-test)
add_subdirectory(../../../${currentPlatform.operatingSystem.name} plugin)
add_executable(\${CMAKE_PROJECT_NAME} main.c)
target_link_libraries(\${CMAKE_PROJECT_NAME} PRIVATE sentry_flutter_plugin)

# Same as generated_plugins.cmake
list(APPEND PLUGIN_BUNDLED_LIBRARIES \$<TARGET_FILE:sentry_flutter_plugin>)
list(APPEND PLUGIN_BUNDLED_LIBRARIES \${sentry_flutter_bundled_libraries})
install(FILES "\${PLUGIN_BUNDLED_LIBRARIES}" DESTINATION "${buildOutputDir.replaceAll('\\', '/')}" COMPONENT Runtime)
set(CMAKE_INSTALL_PREFIX "${buildOutputDir.replaceAll('\\', '/')}")
''');
      await _exec('cmake', ['-B', cmakeBuildDir, cmakeConfDir]);
      await _exec('cmake',
          ['--build', cmakeBuildDir, '--config', 'Release', '--parallel']);
      await _exec('cmake', [
        '--install',
        cmakeBuildDir,
        '--config',
        'Release',
      ]);
      if (currentPlatform.isLinux &&
          nativeBackend.actualValue == NativeBackend.crashpad) {
        await _exec('chmod', ['+x', '$buildOutputDir/crashpad_handler']);
      }
    }
    return buildOutputDir;
  }

  bool _builtVersionIsExpected() {
    final buildCmake = File(
        '$cmakeBuildDir/_deps/sentry-native-build/sentry-config-version.cmake');
    if (!buildCmake.existsSync()) return false;

    if (!buildCmake
        .readAsStringSync()
        .contains('set(PACKAGE_VERSION "$configuredSentryNativeVersion")')) {
      return false;
    }

    return !expectedDistFiles
        .any((name) => !File('$buildOutputDir/$name').existsSync());
  }

  late final configuredSentryNativeVersion =
      File('$repoRootDir/sentry-native/CMakeCache.txt')
          .readAsLinesSync()
          .map((line) => line.startsWith('version=') ? line.substring(8) : null)
          .firstWhere((line) => line != null)!;
}
