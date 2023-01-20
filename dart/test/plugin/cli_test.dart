import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

import 'package:sentry/plugin/src/utils/injector.dart';
import 'package:sentry/plugin/src/cli/_sources.dart';
import 'package:sentry/plugin/src/cli/host_platform.dart';
import 'package:sentry/plugin/src/cli/setup.dart';

void main() {
  final sources = currentCLISources;
  final platforms = HostPlatform.values;

  for (var platform in platforms) {
    test(platform.name, () async {
      final fs = MemoryFileSystem.test();
      injector.registerSingleton<FileSystem>(() => fs, override: true);
      final cliSetup = CLISetup(sources);
      final file = await cliSetup.download(platform);
      final suffix = platform.name.startsWith('windows') ? '.exe' : '';
      expect(file, '.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli$suffix');
      expect(fs.file(file).existsSync(), isTrue);
    });
  }
}
