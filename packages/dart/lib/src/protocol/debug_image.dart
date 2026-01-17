import 'package:meta/meta.dart';

import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

/// The list of debug images contains all dynamic libraries loaded into
/// the process and their memory addresses.
/// Instruction addresses in the Stack Trace are mapped into the list of debug
/// images in order to retrieve debug files for symbolication.
/// There are two kinds of debug images:
//
/// Native debug images with types macho, elf, and pe
/// Android debug images with type proguard
/// more details : https://develop.sentry.dev/sdk/event-payloads/debugmeta/
class DebugImage {
  String? uuid;

  /// Required. Type of the debug image.
  String type;

  // Name of the image. Sentry-cocoa only.
  String? name;

  /// Required. Identifier of the dynamic library or executable. It is the value of the LC_UUID load command in the Mach header, formatted as UUID.
  String? debugId;

  /// Required. Memory address, at which the image is mounted in the virtual address space of the process.
  /// Should be a string in hex representation prefixed with "0x".
  String? imageAddr;

  /// Optional. Preferred load address of the image in virtual memory, as declared in the headers of the image.
  /// When loading an image, the operating system may still choose to place it at a different address.
  String? imageVmAddr;

  /// Required. The size of the image in virtual memory. If missing, Sentry will assume that the image spans up to the next image, which might lead to invalid stack traces.
  int? imageSize;

  /// OptionalName or absolute path to the dSYM file containing debug information for this image. This value might be required to retrieve debug files from certain symbol servers.
  String? debugFile;

  /// Optional. The absolute path to the dynamic library or executable. This helps to locate the file if it is missing on Sentry.
  String? codeFile;

  /// Optional Architecture of the module. If missing, this will be backfilled by Sentry.
  String? arch;

  /// Optional. Identifier of the dynamic library or executable. It is the value of the LC_UUID load command in the Mach header, formatted as UUID. Can be empty for Mach images, as it is equivalent to the debug identifier.
  String? codeId;

  /// MachO CPU subtype identifier.
  int? cpuSubtype;

  /// MachO CPU type identifier.
  int? cpuType;

  @internal
  final Map<String, dynamic>? unknown;

  DebugImage({
    required this.type,
    this.name,
    this.imageAddr,
    this.imageVmAddr,
    this.debugId,
    this.debugFile,
    this.imageSize,
    this.uuid,
    this.codeFile,
    this.arch,
    this.codeId,
    this.cpuType,
    this.cpuSubtype,
    this.unknown,
  });

  /// Deserializes a [DebugImage] from JSON [Map].
  factory DebugImage.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return DebugImage(
      type: json.getValueOrNull('type')!,
      name: json.getValueOrNull('name'),
      imageAddr: json.getValueOrNull('image_addr'),
      imageVmAddr: json.getValueOrNull('image_vmaddr'),
      debugId: json.getValueOrNull('debug_id'),
      debugFile: json.getValueOrNull('debug_file'),
      imageSize: json.getValueOrNull('image_size'),
      uuid: json.getValueOrNull('uuid'),
      codeFile: json.getValueOrNull('code_file'),
      arch: json.getValueOrNull('arch'),
      codeId: json.getValueOrNull('code_id'),
      cpuType: json.getValueOrNull('cpu_type'),
      cpuSubtype: json.getValueOrNull('cpu_subtype'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'type': type,
      if (uuid != null) 'uuid': uuid,
      if (debugId != null) 'debug_id': debugId,
      if (name != null) 'name': name,
      if (debugFile != null) 'debug_file': debugFile,
      if (codeFile != null) 'code_file': codeFile,
      if (imageAddr != null) 'image_addr': imageAddr,
      if (imageVmAddr != null) 'image_vmaddr': imageVmAddr,
      if (imageSize != null) 'image_size': imageSize,
      if (arch != null) 'arch': arch,
      if (codeId != null) 'code_id': codeId,
      if (cpuType != null) 'cpu_type': cpuType,
      if (cpuSubtype != null) 'cpu_subtype': cpuSubtype,
    };
  }

  @Deprecated('Assign values directly to the instance.')
  DebugImage copyWith({
    String? uuid,
    String? name,
    String? type,
    String? debugId,
    String? debugFile,
    String? codeFile,
    String? imageAddr,
    String? imageVmAddr,
    int? imageSize,
    String? arch,
    String? codeId,
    int? cpuType,
    int? cpuSubtype,
  }) =>
      DebugImage(
        uuid: uuid ?? this.uuid,
        name: name ?? this.name,
        type: type ?? this.type,
        debugId: debugId ?? this.debugId,
        debugFile: debugFile ?? this.debugFile,
        codeFile: codeFile ?? this.codeFile,
        imageAddr: imageAddr ?? this.imageAddr,
        imageVmAddr: imageVmAddr ?? this.imageVmAddr,
        imageSize: imageSize ?? this.imageSize,
        arch: arch ?? this.arch,
        codeId: codeId ?? this.codeId,
        cpuType: cpuType ?? this.cpuType,
        cpuSubtype: cpuSubtype ?? this.cpuSubtype,
        unknown: unknown,
      );
}
