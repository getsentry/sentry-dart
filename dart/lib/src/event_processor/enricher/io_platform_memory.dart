import 'dart:io';

// Get total & free platform memory (in bytes) for linux and windows operating systems.
// Source: https://github.com/onepub-dev/system_info/blob/8a9bf6b8eb7c86a09b3c3df4bf6d7fa5a6b50732/lib/src/platform/memory.dart
class PlatformMemory {
  PlatformMemory(this.operatingSystem);

  final String operatingSystem;

  int? getTotalPhysicalMemory() {
    switch (operatingSystem) {
      case 'linux':
        return _getLinuxMemInfoValue('MemTotal');
      case 'windows':
        return _getWindowsWmicValue('ComputerSystem', 'TotalPhysicalMemory');
      default:
        return null;
    }
  }

  int? getFreePhysicalMemory() {
    switch (operatingSystem) {
      case 'linux':
        return _getLinuxMemInfoValue('MemFree');
      case 'windows':
        return _getWindowsWmicValue('OS', 'FreePhysicalMemory');
      default:
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
      //
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
