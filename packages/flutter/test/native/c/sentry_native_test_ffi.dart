import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/platform/platform.dart' as platform;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/isolate/isolate_worker.dart';
import 'package:sentry_flutter/src/native/c/binding.dart' as binding;
import 'package:sentry_flutter/src/native/c/sentry_native.dart';
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
void main() {
  final currentPlatform = platform.Platform();

  final repoRootDir = Directory.current.path.endsWith('/test')
      ? Directory.current.parent.path
      : Directory.current.path;

  // A native library remains loaded for the lifetime of this process.
  // CI invokes this suite once per backend; local runs default to Breakpad.
  final backendName =
      Platform.environment['SENTRY_TEST_NATIVE_BACKEND'] ?? 'default_';
  final backend = NativeBackend.values.byName(backendName);
  group(backend.name, () {
    late final NativeTestHelper helper;
    setUpAll(() async {
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

      helper = NativeTestHelper(
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
    });

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

    // Must run before any other test loads the library.
    test(
      'platform thread keeps a stack guarantee when the worker loads the library',
      () async {
        expect(
          _isModuleLoaded('sentry.dll'),
          isFalse,
          reason: 'needs a process that has not loaded sentry.dll yet',
        );
        expect(SentryNative.threadStackGuarantee(), 0);
        addTearDown(sut.close);

        await sut.init(MockHub());

        expect(sut.hasWorker, isTrue);
        expect(_isModuleLoaded('sentry.dll'), isTrue);
        expect(SentryNative.threadStackGuarantee(), 64 * 1024);
      },
      testOn: 'windows',
    );

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
      test('does not fetch Crashpad', () {
        expect(
          File(
            '${helper.cmakeBuildDir}/_deps/sentry-native-src/'
            'external/crashpad/CMakeLists.txt',
          ).existsSync(),
          isFalse,
        );
      });

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
      await sut.init(MockHub());
    });

    test('init runs in background and defers scope calls', () async {
      addTearDown(sut.close);
      final init = sut.init(MockHub());
      expect(init, isA<Future<void>>());

      final pendingTag = sut.setTag('fixture-key', 'fixture-value');
      expect(pendingTag, isA<Future<void>>());

      await init;
      await pendingTag;
    }, testOn: 'windows');

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
      await native.init(MockHub());

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

    test('scope calls after init run on the worker', () async {
      await sut.init(MockHub());
      expect(sut.hasWorker, isTrue);

      await sut.addBreadcrumb(Breadcrumb(message: 'fixture-message'));
      await sut.setUser(SentryUser(id: 'fixture-id'));
      await sut.setContexts('fixture-key', {'object': Object()});
      await sut.setExtra('fixture-key', 'fixture-value');
      await sut.removeExtra('fixture-key');
      await sut.removeContexts('fixture-key');
      await sut.setTag('fixture-key', 'fixture-value');
      await sut.removeTag('fixture-key');
      await sut.setUser(null);

      await sut.close();
      expect(sut.hasWorker, isFalse);
    }, testOn: 'windows');

    test('worker skips values it cannot convert, like the sync path', () async {
      addTearDown(sut.close);
      await sut.init(MockHub());
      expect(sut.hasWorker, isTrue);
      final port = ReceivePort();
      addTearDown(port.close);

      await sut.addBreadcrumb(Breadcrumb(data: {'port': port, 'n': 1}));
      await sut.setContexts('fixture-key', {
        'list': [port, 'fixture-value'],
      });
      await sut.setExtra('fixture-key', port);
    }, testOn: 'windows');

    group('init on the worker', () {
      late ReceivePort inbox;
      late ReceivePort responses;
      late List<Object?> received;
      late SpawnWorkerFn spawn;

      setUp(() {
        inbox = ReceivePort();
        responses = ReceivePort();
        received = [];
        spawn = SentryNative.spawnWorkerFn;
        SentryNative.spawnWorkerFn = (_, _) async =>
            Worker(inbox.sendPort, responses);
      });

      tearDown(() {
        SentryNative.spawnWorkerFn = spawn;
        inbox.close();
        responses.close();
      });

      void answer(Object? Function(Object? payload) respond) =>
          inbox.listen((message) {
            received.add(message);
            if (message case (final int id, final payload)) {
              responses.sendPort.send((id, respond(payload)));
            }
          });

      List<Object?> kinds() => [
        for (final m in received)
          switch (m) {
            (int _, (final String kind, int _)) => kind,
            (int _, (final String kind, List<Object?> _)) => kind,
            (int _, final String kind) => kind,
            _ => m,
          },
      ];

      Object? succeed(Object? payload) =>
          payload == 'load' || payload is (String, int) ? 0 : null;

      test('loads, inits, then runs scope calls made meanwhile', () async {
        answer(succeed);

        final init = sut.init(MockHub());
        final tag = sut.setTag('fixture-key', 'fixture-value');
        await init;
        await tag;
        expect(sut.hasWorker, isTrue);
        await sut.close();

        expect(kinds(), ['load', 'init', 'set_tag', 'close', '_shutdown_']);
        expect(sut.hasWorker, isFalse);
      });

      test('queues scope calls made before init without waiting', () async {
        answer(succeed);
        addTearDown(sut.close);

        expect(sut.setTag('fixture-key', 'fixture-value'), isNull);
        await sut.init(MockHub());
        await pumpEventQueue();

        expect(kinds(), ['load', 'init', 'set_tag']);
      });

      test('closes the worker when sentry_init fails', () async {
        answer((payload) => payload is (String, int) ? 1 : succeed(payload));

        await expectLater(sut.init(MockHub()), throwsStateError);
        await pumpEventQueue();

        expect(kinds(), ['load', 'init', '_shutdown_']);
        expect(sut.hasWorker, isFalse);
        expect(sut.close(), isNull);
      });

      test('closes the worker when loading the library fails', () async {
        answer((_) => RemoteError('fixture-error', ''));

        await expectLater(sut.init(MockHub()), throwsA(isA<RemoteError>()));
        await pumpEventQueue();

        expect(kinds(), ['load', '_shutdown_']);
        expect(sut.hasWorker, isFalse);
      });

      test(
        'inits on the calling isolate when the worker fails to start',
        () async {
          SentryNative.spawnWorkerFn = (_, _) async =>
              throw StateError('fixture-error');
          addTearDown(sut.close);

          await sut.init(MockHub());

          expect(sut.hasWorker, isFalse);
          expect(
            sut.setTag('fixture-key', 'fixture-value'),
            isNot(isA<Future<void>>()),
          );
        },
      );
    }, skip: Platform.isWindows ? false : 'Windows only');

    group('close with a worker', () {
      late ReceivePort inbox;
      late ReceivePort responses;
      late List<Object?> received;
      late Completer<void> shutdown;

      setUp(() {
        inbox = ReceivePort();
        responses = ReceivePort();
        received = [];
        shutdown = Completer<void>();
        sut.worker = Worker(inbox.sendPort, responses);
      });

      tearDown(() async {
        // Answers a close the test left pending, so it can't block later inits.
        responses.sendPort.send((0, null));
        await SentryNative.pendingWorkerClose;
        inbox.close();
        responses.close();
      });

      void listen({required bool answer}) => inbox.listen((message) {
        received.add(message);
        if (message == '_shutdown_') shutdown.complete();
        if (message case (final int id, _) when answer) {
          responses.sendPort.send((id, null));
        }
      });

      test('runs close on the worker after queued scope calls', () async {
        listen(answer: true);

        await sut.addBreadcrumb(Breadcrumb(message: 'fixture-message'));
        await sut.setTag('fixture-key', 'fixture-value');
        await sut.close();
        await shutdown.future;

        expect(received.map(_scopeMethod), [
          'fixture-message',
          'set_tag',
          (2, 'close'),
          '_shutdown_',
        ]);
        expect(sut.hasWorker, isFalse);
      });

      test('a scope call completes once the worker ran it', () async {
        listen(answer: false);
        var done = false;
        final tag = Future.value(
          sut.setTag('fixture-key', 'fixture-value'),
        ).then((_) => done = true);

        await pumpEventQueue();
        expect(done, isFalse);
        responses.sendPort.send((0, null));
        await tag;

        expect(done, isTrue);
      });

      test(
        'drops the oldest queued breadcrumbs beyond maxBreadcrumbs',
        () async {
          options.maxBreadcrumbs = 2;
          listen(answer: false);

          final calls = [
            for (var i = 0; i < 4; i++)
              sut.addBreadcrumb(Breadcrumb(message: '$i')),
            sut.setUser(null),
          ];
          for (var id = 0; id < 4; id++) {
            await pumpEventQueue();
            responses.sendPort.send((id, null));
          }
          await Future.wait(calls.whereType<Future<void>>());

          // '0' was already sent, so '1' made room for '3'.
          expect(received.map(_scopeMethod), ['0', '2', '3', 'remove_user']);
        },
      );

      test('stops waiting when the worker does not answer', () async {
        final timeout = SentryNative.workerCloseTimeout;
        SentryNative.workerCloseTimeout = Duration.zero;
        addTearDown(() => SentryNative.workerCloseTimeout = timeout);
        listen(answer: false);

        await sut.close();
        await shutdown.future;

        expect(received, [(0, 'close'), '_shutdown_']);
        expect(sut.hasWorker, isFalse);
      });

      test('drops scope calls and repeated closes while closing', () async {
        listen(answer: false);

        final close = sut.close();
        await sut.addBreadcrumb(Breadcrumb(message: 'fixture-message'));
        await sut.setTag('fixture-key', 'fixture-value');
        await sut.close();
        await shutdown.future;
        responses.sendPort.send((0, null));
        await close;

        expect(received, [(0, 'close'), '_shutdown_']);
      });

      test(
        'init after a stuck close returns and holds scope calls until it ends',
        () async {
          final timeout = SentryNative.workerCloseTimeout;
          SentryNative.workerCloseTimeout = Duration.zero;
          addTearDown(() => SentryNative.workerCloseTimeout = timeout);
          listen(answer: false);
          await sut.close();

          final next = createBinding(options) as SentryNative;
          addTearDown(next.close);
          await next.init(MockHub());
          expect(next.hasWorker, isFalse);

          var tagged = false;
          final tag = Future.value(
            next.setTag('fixture-key', 'fixture-value'),
          ).then((_) => tagged = true);
          await pumpEventQueue();
          expect(tagged, isFalse);

          responses.sendPort.send((0, null));
          await tag;
          expect(next.hasWorker, isTrue);
        },
        testOn: 'windows',
      );
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

        await sut.init(MockHub());

        expect(dbDir.existsSync(), isTrue);
      },
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

Object? _scopeMethod(Object? message) => switch (message) {
  (int _, ('add_breadcrumb', [final Map<String, dynamic> breadcrumb])) =>
    breadcrumb['message'],
  (int _, (final String method, List<Object?> _)) => method,
  _ => message,
};

bool _isModuleLoaded(String name) {
  final getModuleHandle = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<
        Pointer<Void> Function(Pointer<Utf16>),
        Pointer<Void> Function(Pointer<Utf16>)
      >('GetModuleHandleW');
  final cName = name.toNativeUtf16();
  try {
    return getModuleHandle(cName) != nullptr;
  } finally {
    malloc.free(cName);
  }
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
