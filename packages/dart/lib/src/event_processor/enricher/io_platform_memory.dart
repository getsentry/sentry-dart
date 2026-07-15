import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../../protocol.dart';
import '../../sentry_options.dart';

// Reads total physical memory for Linux and Windows.
//
// Linux parses `/proc/meminfo` (value in kB). Windows reads it directly from
// the kernel via `GlobalMemoryStatusEx` (bytes) instead of shelling out to the
// deprecated `wmic.exe` (or PowerShell as a fallback), which is being removed
// from recent Windows installs:
// https://techcommunity.microsoft.com/blog/windows-itpro-blog/wmi-command-line-wmic-utility-deprecation-next-steps/4039242
class PlatformMemory {
  PlatformMemory(this.options);

  final SentryOptions options;

  Future<int?> getTotalPhysicalMemory() async {
    if (options.platform.isLinux) {
      return _getLinuxMemInfoValue('MemTotal');
    } else if (options.platform.isWindows) {
      return _getWindowsTotalPhysicalMemory();
    } else {
      return null;
    }
  }

  int? _getWindowsTotalPhysicalMemory() {
    final statusPointer = calloc<_MemoryStatusEx>();
    try {
      statusPointer.ref.dwLength = sizeOf<_MemoryStatusEx>();
      // kernel32 is always mapped into the process, so resolve the symbol from
      // the process itself rather than acquiring a fresh module handle.
      final globalMemoryStatusEx = DynamicLibrary.process().lookupFunction<
          _GlobalMemoryStatusExNative,
          _GlobalMemoryStatusExDart>('GlobalMemoryStatusEx');

      if (globalMemoryStatusEx(statusPointer) == 0) {
        return null;
      }
      return statusPointer.ref.ullTotalPhys;
    } catch (e) {
      options.log(
          SentryLevel.warning, "Failed to read total physical memory: $e");
      if (options.automatedTestMode) {
        rethrow;
      }
      return null;
    } finally {
      calloc.free(statusPointer);
    }
  }

  // Linux path derived from
  // https://github.com/onepub-dev/system_info/blob/master/lib/src/platform/memory.dart
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

  Future<String?> _exec(String executable, List<String> arguments) async {
    try {
      final result = await Process.run(executable, arguments);
      if (result.exitCode == 0) {
        return result.stdout.toString();
      }
    } catch (e) {
      options.log(SentryLevel.warning, "Failed to run process: $e");
      if (options.automatedTestMode) {
        rethrow;
      }
    }
    return null;
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

// https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-globalmemorystatusex
typedef _GlobalMemoryStatusExNative = Int32 Function(Pointer<_MemoryStatusEx>);
typedef _GlobalMemoryStatusExDart = int Function(Pointer<_MemoryStatusEx>);

// https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/ns-sysinfoapi-memorystatusex
final class _MemoryStatusEx extends Struct {
  @Uint32()
  external int dwLength;
  @Uint32()
  external int dwMemoryLoad;
  @Uint64()
  external int ullTotalPhys;
  @Uint64()
  external int ullAvailPhys;
  @Uint64()
  external int ullTotalPageFile;
  @Uint64()
  external int ullAvailPageFile;
  @Uint64()
  external int ullTotalVirtual;
  @Uint64()
  external int ullAvailVirtual;
  @Uint64()
  external int ullAvailExtendedVirtual;
}
