import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;

import '../utils/injector.dart';
import '../utils/log.dart';
import 'host_platform.dart';
import 'sources.dart';

class CLISetup {
  final /*CLISources*/ Map<HostPlatform, CLISource> _sources;
  final _directory = '.dart_tool/pub/bin/sentry_dart_plugin';

  CLISetup(this._sources);

  Future<String> download(HostPlatform platform) async {
    final dir = injector.get<FileSystem>().directory(_directory);
    await dir.create(recursive: true);
    final file = dir.childFile('sentry-cli${platform.executableExtension}');

    final source = _sources[platform]!;

    if (!await _check(source, file)) {
      await _download(source, file);
    }

    return file.path;
  }

  Future<void> _download(CLISource source, File file) async {
    Log.info(
        "Downloading sentry-cli from ${source.downloadUrl} to ${file.path}");

    final client = http.Client();
    try {
      final response =
          await client.send(http.Request('GET', source.downloadUrl));
      final sink = file.openWrite();
      await sink.addStream(response.stream);
      await sink.close();
    } finally {
      client.close();
    }

    if (await _check(source, file)) {
      Log.info("Sentry CLI downloaded successfully.");
    } else {
      Log.error(
          "Failed to download Sentry CLI: downloaded file doesn't match the expected checksum.");
    }
  }

  Future<bool> _check(CLISource source, File file) async {
    if (!await file.exists()) {
      return false;
    }

    final calculated = await _hash(file);
    final expected = source.hash;
    if (calculated != expected) {
      Log.warn(
          "Sentry CLI checksum mismatch on ${file.path} - expected $expected but got $calculated");
      return false;
    }

    Log.info(
        "Downloaded Sentry CLI binary checksum verification passed successfully (hash: $calculated).");
    return true;
  }

  Future<String> _hash(File file) async {
    var output = AccumulatorSink<Digest>();
    var input = sha256.startChunkedConversion(output);
    final stream = file.openRead();
    await for (final chunk in stream) {
      input.add(chunk);
    }
    input.close();
    return output.events.single.toString();
  }
}
