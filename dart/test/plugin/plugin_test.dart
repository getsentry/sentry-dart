import 'dart:io';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:process/process.dart';
import 'package:test/test.dart';

import 'package:sentry/plugin/plugin.dart';
import 'package:sentry/plugin/src/cli/host_platform.dart';
import 'package:sentry/plugin/src/cli/setup.dart';
import 'package:sentry/plugin/src/utils/injector.dart';

void main() {
  final plugin = SentryDartPlugin();
  late MockProcessManager pm;
  late FileSystem fs;

  const cli = MockCLI.name;
  const orgAndProject = '--org o --project p';
  const project = 'project';
  const version = '1.1.0';
  const release = '$project@$version';
  const buildDir = '/subdir';

  setUp(() {
    // override dependencies for testing
    pm = MockProcessManager();
    injector.registerSingleton<ProcessManager>(() => pm, override: true);
    fs = MemoryFileSystem.test();
    fs.currentDirectory = fs.directory(buildDir)..createSync();
    injector.registerSingleton<FileSystem>(() => fs, override: true);
    injector.registerSingleton<CLISetup>(() => MockCLI(), override: true);
  });

  for (final url in const ['http://127.0.0.1', null]) {
    group('url: $url', () {
      final commonArgs =
          '${url == null ? '' : '--url http://127.0.0.1 '}--auth-token t';
      final commonCommands = [
        if (!Platform.isWindows) 'chmod +x $cli',
        '$cli help'
      ];

      Future<Iterable<String>> runWith(String config) async {
        // properly indent the configuration for the `sentry` section in the yaml
        if (url != null) {
          config = 'url: $url\n$config';
        }
        final configIndented =
            config.trim().split('\n').map((l) => '  ${l.trim()}').join('\n');

        fs.file('pubspec.yaml').writeAsStringSync('''
name: $project
version: $version

sentry:
  auth_token: t # TODO: support not specifying this, let sentry-cli use the value it can find in its configs
  project: p
  org: o
$configIndented
''');

        final exitCode = await plugin.run([]);
        expect(exitCode, 0);
        expect(pm.commandLog.take(commonCommands.length), commonCommands);
        return pm.commandLog.skip(commonCommands.length);
      }

      test('fails without args and pubspec', () async {
        final exitCode = await plugin.run([]);
        expect(exitCode, 1);
        expect(pm.commandLog, commonCommands);
      });

      test('works with pubspec', () async {
        final commandLog = await runWith('''
      upload_native_symbols: true
      include_native_sources: true
      upload_source_maps: true
      log_level: debug
    ''');
        final args = '$commonArgs --log-level debug';
        expect(commandLog, [
          '$cli $args upload-dif $orgAndProject --include-sources $buildDir',
          '$cli $args releases $orgAndProject new $release',
          '$cli $args releases $orgAndProject files $release upload-sourcemaps $buildDir/build/web --ext map --ext js',
          '$cli $args releases $orgAndProject files $release upload-sourcemaps $buildDir --ext dart',
          '$cli $args releases $orgAndProject set-commits $release --auto',
          '$cli $args releases $orgAndProject finalize $release'
        ]);
      });

      test('defaults', () async {
        final commandLog = await runWith('');
        expect(commandLog, [
          '$cli $commonArgs upload-dif $orgAndProject $buildDir',
          '$cli $commonArgs releases $orgAndProject new $release',
          '$cli $commonArgs releases $orgAndProject set-commits $release --auto',
          '$cli $commonArgs releases $orgAndProject finalize $release'
        ]);
      });

      group('commits', () {
        // https://docs.sentry.io/product/cli/releases/#sentry-cli-commit-integration
        for (final value in const [
          null, // test the implicit default
          'true',
          'auto',
          'repo_name@293ea41d67225d27a8c212f901637e771d73c0f7',
          'repo_name@293ea41d67225d27a8c212f901637e771d73c0f7..1e248e5e6c24b79a5c46a2e8be12cef0e41bd58d',
        ]) {
          test(value, () async {
            final commandLog =
                await runWith(value == null ? '' : 'commits: $value');
            final expectedArgs =
                (value == null || value == 'auto' || value == 'true')
                    ? '--auto'
                    : '--commit $value';
            expect(commandLog, [
              '$cli $commonArgs upload-dif $orgAndProject $buildDir',
              '$cli $commonArgs releases $orgAndProject new $release',
              '$cli $commonArgs releases $orgAndProject set-commits $release $expectedArgs',
              '$cli $commonArgs releases $orgAndProject finalize $release'
            ]);
          });
        }

        // if explicitly disabled
        test('false', () async {
          final commandLog = await runWith('commits: false');
          expect(commandLog, [
            '$cli $commonArgs upload-dif $orgAndProject $buildDir',
            '$cli $commonArgs releases $orgAndProject new $release',
            '$cli $commonArgs releases $orgAndProject finalize $release'
          ]);
        });
      });
    });
  }
}

class MockProcessManager implements ProcessManager {
  final commandLog = <String>[];

  @override
  bool canRun(executable, {String? workingDirectory}) => true;

  @override
  bool killPid(int pid, [ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  Future<ProcessResult> run(List<Object> command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      covariant Encoding? stdoutEncoding = systemEncoding,
      covariant Encoding? stderrEncoding = systemEncoding}) {
    return Future.value(runSync(command));
  }

  @override
  ProcessResult runSync(List<Object> command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      covariant Encoding? stdoutEncoding = systemEncoding,
      covariant Encoding? stderrEncoding = systemEncoding}) {
    commandLog.add(command.join(' '));
    return ProcessResult(-1, 0, null, null);
  }

  @override
  Future<Process> start(List<Object> command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      ProcessStartMode mode = ProcessStartMode.normal}) {
    throw UnimplementedError();
  }
}

class MockCLI implements CLISetup {
  static const name = 'mock-cli';

  @override
  Future<String> download(HostPlatform platform) => Future.value(name);
}
