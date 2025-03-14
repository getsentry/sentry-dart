import 'dart:io';

import '../../protocol.dart';
import '../../sentry_options.dart';

// Get total & free platform memory (in bytes) for linux and windows operating systems.
// Source: https://github.com/onepub-dev/system_info/blob/8a9bf6b8eb7c86a09b3c3df4bf6d7fa5a6b50732/lib/src/platform/memory.dart
class PlatformMemory {
  PlatformMemory(this.options) {
    if (options.platformChecker.platform.isWindows) {
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

  int? getTotalPhysicalMemory() {
    if (options.platform.isLinux) {
      return _getLinuxMemInfoValue('MemTotal');
    } else if (options.platform.isWindows) {
      if (useWindowsWmci) {
        return _getWindowsWmicValue('ComputerSystem', 'TotalPhysicalMemory');
      } else if (useWindowsPowerShell) {
        return _getWindowsPowershellMemoryValue('TotalPhysicalMemory');
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  int? getFreePhysicalMemory() {
    if (options.platform.isLinux) {
      return _getLinuxMemInfoValue('MemFree');
    } else if (options.platform.isWindows) {
      if (useWindowsWmci) {
        return _getWindowsWmicValue('OS', 'FreePhysicalMemory');
      } else if (useWindowsPowerShell) {
        return _getWindowsPowershellMemoryValue('FreePhysicalMemory');
      } else {
        return null;
      }
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
      if (options.automatedTestMode) {
        rethrow;
      }
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

  int? _getWindowsPowershellMemoryValue(String property) {
    final command = property == 'TotalPhysicalMemory'
        ? 'Get-CimInstance Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory'
        : 'Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty FreePhysicalMemory';

    final result = _exec('powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', command]);
    if (result == null) {
      return null;
    }

    final value = result.trim();
    final size = int.tryParse(value);
    if (size == null) {
      return null;
    }

    // FreePhysicalMemory is in KB, while TotalPhysicalMemory is in bytes
    return property == 'TotalPhysicalMemory' ? size : size * 1024;
  }
}

/// A cached version of [PlatformMemory] that reduces system calls by caching
/// values. Total memory is cached indefinitely, and free memory for the
/// configured duration (default 1 minute).
class CachedPlatformMemory {
  CachedPlatformMemory(SentryOptions options, {Duration? cacheDuration})
      : _cacheDuration = cacheDuration ?? const Duration(minutes: 1) {
    _delegate = PlatformMemory(options);
  }

  final Duration _cacheDuration;
  late final PlatformMemory _delegate;

  int? _cachedTotalPhysicalMemory;
  int? _cachedFreePhysicalMemory;
  DateTime? _lastCacheUpdate;

  void _refreshCachedFreePhysicalMemory() {
    final now = DateTime.now();
    if (_lastCacheUpdate != null &&
        now.difference(_lastCacheUpdate!) < _cacheDuration) {
      return;
    }
    _cachedFreePhysicalMemory = _delegate.getFreePhysicalMemory();
    _lastCacheUpdate = now;
  }

  int? getTotalPhysicalMemory() {
    _cachedTotalPhysicalMemory ??= _delegate.getTotalPhysicalMemory();
    return _cachedTotalPhysicalMemory;
  }

  int? getFreePhysicalMemory() {
    _refreshCachedFreePhysicalMemory();
    return _cachedFreePhysicalMemory;
  }
}
