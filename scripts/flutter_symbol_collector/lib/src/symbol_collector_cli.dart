import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:platform/platform.dart';
import 'package:posix/posix.dart' as posix;
import 'package:path/path.dart' as path;

import 'flutter_version.dart';

class SymbolCollectorCli {
  late final Logger _log = Logger.root;
  late bool _isExecutable;

  // https://github.com/getsentry/symbol-collector/releases
  @internal
  static const version = '1.18.0';

  @internal
  late final String cli;

  @internal
  static Platform platform = LocalPlatform();

  SymbolCollectorCli._();

  // Downloads the CLI to the given temporary directory and prepares it for use.
  static Future<SymbolCollectorCli> setup(Directory tempDir) async {
    late final String platformIdentifier;
    final executableName = 'symbol-collector';

    if (platform.isLinux) {
      platformIdentifier = 'linux-x64';
    } else if (platform.isMacOS) {
      platformIdentifier = 'osx-x64';
    } else {
      throw UnsupportedError(
          'Cannot run symbol-collector CLI on this platform - there\'s no binary available at this time.');
    }

    final self = SymbolCollectorCli._();

    self._log.fine(
        'Downloading symbol-collector CLI v$version for $platformIdentifier');
    final zipData = await http.readBytes(Uri.parse(
        'https://github.com/getsentry/symbol-collector/releases/download/$version/symbolcollector-console-$platformIdentifier.zip'));
    self._log.fine(
        'Download successful, received ${zipData.length} bytes; extracting the archive');

    final archive = ZipDecoder().decodeBytes(zipData);
    final stream = OutputStream();
    archive.single.writeContent(stream, freeMemory: true);
    stream.flush();

    await tempDir.create();
    final executableFile = await tempDir.childFile(executableName).create();
    self.cli = executableFile.path;

    await executableFile.writeAsBytes(stream.getBytes(), flush: true);
    self._log.fine(
        'Symbol-collector CLI extracted to ${executableFile.path}: ${await executableFile.length()} bytes');
    self._isExecutable = platform.isWindows;
    return self;
  }

  void _ensureIsExecutable() {
    if (!_isExecutable) {
      if (LocalPlatform().operatingSystem == platform.operatingSystem) {
        if (platform.isLinux || platform.isMacOS) {
          _log.fine('Making Symbol-collector CLI executable (chmod +x)');

          posix.chmod(cli, '0700');
        }
        _isExecutable = true;
      } else {
        _log.warning(
            'Symbol-collector CLI has been run with a platform that is not the current OS platform.'
            'This should only be done in tests because we can\'t execute the downloaded program');
      }
    }
  }

  Future<String> getVersion() => _execute(['--version', '-h']);

  Future<bool> upload(
      Directory dir, Platform symbolsPlatform, FlutterVersion flutterVersion,
      {bool dryRun = false}) async {
    final type = symbolsPlatform.operatingSystem;
    try {
      await _execute([
        '--upload',
        'directory',
        '--path',
        dir.path,
        '--batch-type',
        type,
        '--bundle-id',
        'flutter-${flutterVersion.tagName}-$type',
        '--server-endpoint',
        'https://symbol-collector.services.sentry.io/',
      ]);
    } catch (e) {
      _log.warning('Failed to upload symbols from ${dir.path}', e);
      return false;
    }
    return true;
  }

  Future<String> _execute(List<String> arguments) async {
    _ensureIsExecutable();

    _log.fine('Executing ${path.basename(cli)} ${arguments.join(' ')}');
    final process = await Process.start(cli, arguments);

    final output = StringBuffer();
    handleOutput(Level level, String message) {
      message.trimRight().split('\n').forEach((s) => _log.log(level, '   $s'));
      output.write(message);
    }

    final pipes = [
      process.stdout
          .transform(utf8.decoder)
          .forEach((s) => handleOutput(Level.FINER, s)),
      process.stderr
          .transform(utf8.decoder)
          .forEach((s) => handleOutput(Level.SEVERE, s))
    ];

    final exitCode = await process.exitCode;
    await Future.wait(pipes);
    final strOutput = output.toString().trimRight();
    if (exitCode != 0) {
      throw Exception('Symbol-collector CLI failed with exit code $exitCode.');
    } else if (strOutput.contains('Exception:')) {
      // see https://github.com/getsentry/symbol-collector/issues/167
      throw Exception('Symbol-collector CLI failed with an exception.');
    }

    return strOutput;
  }
}
