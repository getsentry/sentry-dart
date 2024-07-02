import 'dart:io';

import '../../protocol.dart';
import '../../sentry_options.dart';

// Get total & free platform memory (in bytes) for linux and windows operating systems.
// Source: https://github.com/onepub-dev/system_info/blob/8a9bf6b8eb7c86a09b3c3df4bf6d7fa5a6b50732/lib/src/platform/memory.dart
class PlatformMemory {
  PlatformMemory(this.options);

  final SentryOptions options;

  int? getTotalPhysicalMemory() {
    if (options.platformChecker.platform.isLinux) {
      return _getLinuxMemInfoValue('MemTotal');
    } else if (options.platformChecker.platform.isWindows) {
      return _getWindowsWmicValue('ComputerSystem', 'TotalPhysicalMemory');
    } else {
      return null;
    }
  }

  int? getFreePhysicalMemory() {
    if (options.platformChecker.platform.isLinux) {
      return _getLinuxMemInfoValue('MemFree');
    } else if (options.platformChecker.platform.isWindows) {
      return _getWindowsWmicValue('OS', 'FreePhysicalMemory');
    } else {
      return null;
    }
  }

  int? _getWindowsWmicValue(String section, String key) {
    final os = _wmicGetValueAsMap(section, [key]);
    final totalPhysicalMemoryValue = os?[key];
    if (totalPhysicalMemoryValue == null) {
      return null;
    }
    final size = int.tryParse(totalPhysicalMemoryValue);
    if (size == null) {
      return null;
    }
    return size;
  }

  int? _getLinuxMemInfoValue(String key) {
    final meminfoList = _exec('cat', ['/proc/meminfo'])
            ?.trim()
            .replaceAll('\r\n', '\n')
            .split('\n') ??
        [];

    final meminfoMap = _listToMap(meminfoList, ':');
    final memsizeResults = meminfoMap[key]?.split(' ') ?? [];

    if (memsizeResults.isEmpty) {
      return null;
    }
    final memsizeResult = memsizeResults.first;

    final memsize = int.tryParse(memsizeResult);
    if (memsize == null) {
      return null;
    }
    return memsize;
  }

  String? _exec(String executable, List<String> arguments,
      {bool runInShell = false}) {
    try {
      final result =
          Process.runSync(executable, arguments, runInShell: runInShell);
      if (result.exitCode == 0) {
        return result.stdout.toString();
      }
    } catch (e) {
      options.logger(SentryLevel.warning, "Failed to run process: $e");
    }
    return null;
  }

  Map<String, String>? _wmicGetValueAsMap(String section, List<String> fields) {
    final arguments = <String>[section];
    arguments
      ..add('get')
      ..addAll(fields.join(', ').split(' '))
      ..add('/VALUE');

    final list =
        _exec('wmic', arguments)?.trim().replaceAll('\r\n', '\n').split('\n') ??
            [];

    return _listToMap(list, '=');
  }

  Map<String, String> _listToMap(List<String> list, String separator) {
    final map = <String, String>{};
    for (final string in list) {
      final index = string.indexOf(separator);
      if (index != -1) {
        final key = string.substring(0, index).trim();
        final value = string.substring(index + 1).trim();
        map[key] = value;
      }
    }
    return map;
  }
}
