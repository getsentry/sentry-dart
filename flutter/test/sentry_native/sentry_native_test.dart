@TestOn('vm && windows')
library flutter_test;

import 'dart:async';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/platform/platform.dart' as platform;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/c/sentry_native.dart';
import 'package:sentry_flutter/src/native/factory.dart';

import '../mocks.dart';

void main() {
  if (Directory.current.path.endsWith('/test')) {
    Directory.current = Directory.current.parent;
  }

  setUpAll(() async {
    Directory.current = await _buildSentryNative('temp/native-test');
  });

  late SentryNative sut;
  late SentryFlutterOptions options;

  setUp(() {
    options = SentryFlutterOptions(dsn: fakeDsn)
      // ignore: invalid_use_of_internal_member
      ..automatedTestMode = true;
    sut = createBinding(options) as SentryNative;
  });

  tearDown(() => sut.close());

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
    // There's nothing we can check here - just that it doesn't crash.
    await sut.init(options);
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

  //   test('captureEnvelope', () async {
  //     final data = Uint8List.fromList([1, 2, 3]);

  //     late Uint8List captured;
  //     when(channel.invokeMethod('captureEnvelope', any)).thenAnswer(
  //         (invocation) async =>
  //             {captured = invocation.positionalArguments[1][0] as Uint8List});

  //     await sut.captureEnvelope(data, false);

  //     expect(captured, data);
  //   });

  test('loadContexts', () async {
    expect(await sut.loadContexts(), isNull);
  });

  //   test('loadDebugImages', () async {
  //     final json = [
  //       {
  //         'code_file': '/apex/com.android.art/javalib/arm64/boot.oat',
  //         'code_id': '13577ce71153c228ecf0eb73fc39f45010d487f8',
  //         'image_addr': '0x6f80b000',
  //         'image_size': 3092480,
  //         'type': 'elf',
  //         'debug_id': 'e77c5713-5311-28c2-ecf0-eb73fc39f450',
  //         'debug_file': 'test'
  //       }
  //     ];

  //     when(channel.invokeMethod('loadImageList'))
  //         .thenAnswer((invocation) async => json);

  //     final data = await sut.loadDebugImages();

  //     expect(data?.map((v) => v.toJson()), json);
  //   });
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
  final buildOutputDir = '$cmakeBuildDir/_deps/sentry-native-build/Debug/';

  if (!_builtVersionIsExpected(buildOutputDir)) {
    Directory(cmakeConfDir).createSync(recursive: true);
    File('$cmakeConfDir/CMakeLists.txt').writeAsStringSync('''
cmake_minimum_required(VERSION 3.14)
project(sentry-native-flutter-test)
add_subdirectory(../../../${platform.instance.operatingSystem} plugin)
add_library(\${CMAKE_PROJECT_NAME} INTERFACE)
target_link_libraries(\${CMAKE_PROJECT_NAME} INTERFACE \${sentry_flutter_bundled_libraries})
''');
    await _exec('cmake', ['-B', cmakeBuildDir, cmakeConfDir]);
    await _exec('cmake', ['--build', cmakeBuildDir]);
  }
  return buildOutputDir;
}

bool _builtVersionIsExpected(String buildOutputDir) {
  final buildCmake = File('$buildOutputDir/../sentry-config-version.cmake');
  if (!buildCmake.existsSync()) return false;

  if (!buildCmake
      .readAsStringSync()
      .contains('set(PACKAGE_VERSION "$_configuredSentryNativeVersion")')) {
    return false;
  }

  return File('$buildOutputDir/sentry.dll').existsSync();
}

late final _configuredSentryNativeVersion = File('sentry-native/CMakeCache.txt')
    .readAsLinesSync()
    .map((line) => line.startsWith('version=') ? line.substring(8) : null)
    .firstWhere((line) => line != null)!;
