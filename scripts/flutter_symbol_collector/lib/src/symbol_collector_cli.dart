import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:platform/platform.dart';
import 'package:posix/posix.dart' as posix;

class SymbolCollectorCli {
  late final Logger _log = Logger.root;
  late bool _isExecutable;

  // https://github.com/getsentry/symbol-collector/releases
  @visibleForTesting
  static const version = '1.12.0';

  @visibleForTesting
  late final String cli;

  @visibleForTesting
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
    archive.single.writeContent(stream);
    stream.flush();

    await tempDir.create();
    final executableFile = await tempDir.childFile(executableName).create();
    self.cli = executableFile.path;

    executableFile.writeAsBytes(stream.getBytes(), flush: true);
    self._log.fine(
        'Symbol-collector CLI extracted to ${executableFile.path}: ${await executableFile.length()} bytes');
    self._isExecutable = platform.isWindows;
    return self;
  }

  void _makeExecutable() {
    if (!_isExecutable) {
      _isExecutable = true;
      if (LocalPlatform().operatingSystem == platform.operatingSystem) {
        if (platform.isLinux || platform.isMacOS) {
          _log.fine('Making Symbol-collector CLI executable (chmod +x)');

          posix.chmod(cli, '0666');
        }
      } else {
        _log.warning(
            'Symbol-collector CLI has been run with a platform that is not the current OS platform.'
            'This should only be done in tests because we can\'t execute the downloaded program');
      }
    }
  }

  Future<String> getVersion() => _execute(['--version', '-h']);

  Future<String> _execute(List<String> arguments) async {
    var result = await Process.run(cli, arguments);
    if (result.exitCode != 0) {
      _log.shout(
          'Symbol-collector CLI failed to execute $arguments with exit code ${result.exitCode}.');
      _log.shout('Stderr: ${result.stderr}');
      _log.shout('Stdout: ${result.stdout}');
    }
    return result.stdout;
  }
}
