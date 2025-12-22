import 'dart:io';

import '../../debug_logger.dart';
import '../../sentry_options.dart';

// Get total & free platform memory (in bytes) for linux and windows operating systems.
// Source: https://github.com/onepub-dev/system_info/blob/8a9bf6b8eb7c86a09b3c3df4bf6d7fa5a6b50732/lib/src/platform/memory.dart
class PlatformMemory {
  PlatformMemory(this.options) {
    if (options.platform.isWindows) {
      // Check for WMIC (deprecated in newer Windows versions)
      // https://techcommunity.microsoft.com/blog/windows-itpro-blog/wmi-command-line-wmic-utility-deprecation-next-steps/4039242
      useWindowsWmci =
          File('C:\\Windows\\System32\\wbem\\wmic.exe').existsSync();
      if (!useWindowsWmci) {
        useWindowsPowerShell = File(
                'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe')
            .existsSync();
      } else {
        useWindowsPowerShell = false;
      }
    } else {
      useWindowsWmci = false;
      useWindowsPowerShell = false;
    }
  }

  final SentryOptions options;
  late final bool useWindowsWmci;
  late final bool useWindowsPowerShell;

  Future<int?> getTotalPhysicalMemory() async {
    if (options.platform.isLinux) {
      return _getLinuxMemInfoValue('MemTotal');
    } else if (options.platform.isWindows) {
      if (useWindowsWmci) {
        return _getWindowsWmicValue('ComputerSystem', 'TotalPhysicalMemory');
      } else if (useWindowsPowerShell) {
        return _getWindowsPowershellTotalMemoryValue();
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  Future<int?> _getWindowsWmicValue(String section, String key) async {
    final os = await _wmicGetValueAsMap(section, [key]);
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

  Future<int?> _getLinuxMemInfoValue(String key) async {
    final result = await _exec('cat', ['/proc/meminfo']);
    final meminfoList =
        result?.trim().replaceAll('\r\n', '\n').split('\n') ?? [];

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

  Future<String?> _exec(String executable, List<String> arguments,
      {bool runInShell = false}) async {
    try {
      final result =
          await Process.run(executable, arguments, runInShell: runInShell);
      if (result.exitCode == 0) {
        return result.stdout.toString();
      }
    } catch (e) {
      debugLogger.warning("Failed to run process: $e", category: 'enricher');
      if (options.automatedTestMode) {
        rethrow;
      }
    }
    return null;
  }

  Future<Map<String, String>?> _wmicGetValueAsMap(
      String section, List<String> fields) async {
    final arguments = <String>[section];
    arguments
      ..add('get')
      ..addAll(fields.join(', ').split(' '))
      ..add('/VALUE');

    final result = await _exec('wmic', arguments);
    final list = result?.trim().replaceAll('\r\n', '\n').split('\n') ?? [];

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

  Future<int?> _getWindowsPowershellTotalMemoryValue() async {
    final command =
        'Get-CimInstance Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory';

    final result = await _exec('powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', command]);
    if (result == null) {
      return null;
    }

    final value = result.trim();
    final size = int.tryParse(value);
    if (size == null) {
      return null;
    }

    return size;
  }
}
