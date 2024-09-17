@TestOn('vm && windows')
library flutter_test;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/platform/platform.dart' as platform;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/c/sentry_native.dart';
import 'package:sentry_flutter/src/native/factory.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

late final String repoRootDir;
late final List<String> expectedDistFiles;

void main() {
  repoRootDir = Directory.current.path.endsWith('/test')
      ? Directory.current.parent.path
      : Directory.current.path;

  expectedDistFiles = [
    'sentry.dll',
    'crashpad_handler.exe',
    'crashpad_wer.dll',
  ];

  setUpAll(() async {
    Directory.current =
        await _buildSentryNative('$repoRootDir/temp/native-test');
    SentryNative.crashpadPath =
        '${Directory.current.path}/${expectedDistFiles.firstWhere((f) => f.startsWith('crashpad_handler'))}';
  });

  late SentryNative sut;
  late SentryFlutterOptions options;

  setUp(() {
    options = SentryFlutterOptions(dsn: fakeDsn)
      // ignore: invalid_use_of_internal_member
      ..automatedTestMode = true
      ..debug = true
      ..fileSystem = MemoryFileSystem.test();
    sut = createBinding(options) as SentryNative;
  });

  test('expected output files', () {
    for (var name in expectedDistFiles) {
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
          SentryNative.native.options_get_auto_session_tracking(cOptions), 1);
      expect(SentryNative.native.options_get_max_breadcrumbs(cOptions), 42);
    } finally {
      SentryNative.native.options_free(cOptions);
    }
  });

  test('SDK version', () {
    expect(_configuredSentryNativeVersion.length, greaterThanOrEqualTo(5));
    expect(SentryNative.native.sdk_version().cast<Utf8>().toDartString(),
        _configuredSentryNativeVersion);
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

  test('frames tracking', () {
    sut.beginNativeFrames();
    expect(sut.endNativeFrames(SentryId.newId()), null);
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
    expect(() => sut.startProfiler(SentryId.newId()), throwsUnsupportedError);
  });

  test('discardProfiler', () async {
    expect(() => sut.discardProfiler(SentryId.newId()), throwsUnsupportedError);
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
    expect(list![0].type, 'pe');
    expect(list[0].debugId!.length, greaterThan(30));
    expect(list[0].debugFile, isNotEmpty);
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

  test('getAppDebugImage returns app.so debug image', () async {
    await options.fileSystem.directory('/path/to/data').create(recursive: true);
    await options.fileSystem
        .file('/path/to/data/app.so')
        .writeAsString('12345');

    final image = await sut.getAppDebugImage(
      SentryStackTrace(
        frames: [],
        // ignore: invalid_use_of_internal_member
        buildId: '4c6950bd9e9cc9839071742a7295c09e',
        // ignore: invalid_use_of_internal_member
        baseAddr: '0x123',
      ),
      [DebugImage(type: 'pe', codeFile: '/path/to/application.exe')],
    );

    expect(image, isNotNull);
    expect(image!.codeFile, '/path/to/data/app.so');
    expect(image.codeId, '4c6950bd9e9cc9839071742a7295c09e');
    expect(image.debugId, 'bd50694c9c9e83c99071742a7295c09e');
    expect(image.imageAddr, '0x123');
    expect(image.imageSize, 5);
  });
}

/// Runs [command] with command's stdout and stderr being forwrarded to
/// test runner's respective streams. It buffers stdout and returns it.
///
/// Returns [_CommandResult] with exitCode and stdout as a single sting
Future<void> _exec(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments);

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
Future<String> _buildSentryNative(String nativeTestRoot) async {
  final cmakeBuildDir = '$nativeTestRoot/build';
  final cmakeConfDir = '$nativeTestRoot/conf';
  final buildOutputDir = '$nativeTestRoot/dist/';

  if (!_builtVersionIsExpected(cmakeBuildDir, buildOutputDir)) {
    Directory(cmakeConfDir).createSync(recursive: true);
    Directory(buildOutputDir).createSync(recursive: true);
    File('$cmakeConfDir/main.c').writeAsStringSync('''
int main(int argc, char *argv[]) { return 0; }
''');
    File('$cmakeConfDir/CMakeLists.txt').writeAsStringSync('''
cmake_minimum_required(VERSION 3.14)
project(sentry-native-flutter-test)
add_subdirectory(../../../${platform.instance.operatingSystem} plugin)
add_executable(\${CMAKE_PROJECT_NAME} main.c)
target_link_libraries(\${CMAKE_PROJECT_NAME} PRIVATE sentry_flutter_plugin)

# Same as generated_plugins.cmake
list(APPEND PLUGIN_BUNDLED_LIBRARIES \$<TARGET_FILE:sentry_flutter_plugin>)
list(APPEND PLUGIN_BUNDLED_LIBRARIES \${sentry_flutter_bundled_libraries})
install(FILES "\${PLUGIN_BUNDLED_LIBRARIES}" DESTINATION "${buildOutputDir.replaceAll('\\', '/')}" COMPONENT Runtime)
''');
    await _exec('cmake', ['-B', cmakeBuildDir, cmakeConfDir]);
    await _exec('cmake',
        ['--build', cmakeBuildDir, '--config', 'Release', '--parallel']);
    await _exec('cmake', ['--install', cmakeBuildDir, '--config', 'Release']);
  }
  return buildOutputDir;
}

bool _builtVersionIsExpected(String cmakeBuildDir, String buildOutputDir) {
  final buildCmake = File(
      '$cmakeBuildDir/_deps/sentry-native-build/sentry-config-version.cmake');
  if (!buildCmake.existsSync()) return false;

  if (!buildCmake
      .readAsStringSync()
      .contains('set(PACKAGE_VERSION "$_configuredSentryNativeVersion")')) {
    return false;
  }

  return !expectedDistFiles
      .any((name) => !File('$buildOutputDir/$name').existsSync());
}

late final _configuredSentryNativeVersion =
    File('$repoRootDir/sentry-native/CMakeCache.txt')
        .readAsLinesSync()
        .map((line) => line.startsWith('version=') ? line.substring(8) : null)
        .firstWhere((line) => line != null)!;
