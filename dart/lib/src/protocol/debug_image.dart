import 'package:meta/meta.dart';

/// The list of debug images contains all dynamic libraries loaded into
/// the process and their memory addresses.
/// Instruction addresses in the Stack Trace are mapped into the list of debug
/// images in order to retrieve debug files for symbolication.
/// There are two kinds of debug images:
//
/// Native debug images with types macho, elf, and pe
/// Android debug images with type proguard
/// more details : https://develop.sentry.dev/sdk/event-payloads/debugmeta/
@immutable
class DebugImage {
  final String? uuid;

  /// Required. Type of the debug image. Must be "macho".
  final String type;

  /// Required. Identifier of the dynamic library or executable. It is the value of the LC_UUID load command in the Mach header, formatted as UUID.
  final String? debugId;

  /// Required. Memory address, at which the image is mounted in the virtual address space of the process.
  /// Should be a string in hex representation prefixed with "0x".
  final String? imageAddr;

  /// Required. The size of the image in virtual memory. If missing, Sentry will assume that the image spans up to the next image, which might lead to invalid stack traces.
  final int? imageSize;

  /// OptionalName or absolute path to the dSYM file containing debug information for this image. This value might be required to retrieve debug files from certain symbol servers.
  final String? debugFile;

  /// Optional. The absolute path to the dynamic library or executable. This helps to locate the file if it is missing on Sentry.
  final String? codeFile;

  /// Optional Architecture of the module. If missing, this will be backfilled by Sentry.
  final String? arch;

  /// Optional. Identifier of the dynamic library or executable. It is the value of the LC_UUID load command in the Mach header, formatted as UUID. Can be empty for Mach images, as it is equivalent to the debug identifier.
  final String? codeId;

  const DebugImage({
    required this.type,
    this.imageAddr,
    this.debugId,
    this.debugFile,
    this.imageSize,
    this.uuid,
    this.codeFile,
    this.arch,
    this.codeId,
  });

  /// Deserializes a [DebugImage] from JSON [Map].
  factory DebugImage.fromJson(Map<String, dynamic> json) {
    return DebugImage(
      type: json['type'],
      imageAddr: json['image_addr'],
      debugId: json['debug_id'],
      debugFile: json['debug_file'],
      imageSize: json['image_size'],
      uuid: json['uuid'],
      codeFile: json['code_file'],
      arch: json['arch'],
      codeId: json['code_id'],
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (uuid != null) {
      json['uuid'] = uuid;
    }

    json['type'] = type;

    if (debugId != null) {
      json['debug_id'] = debugId;
    }

    if (debugFile != null) {
      json['debug_file'] = debugFile;
    }

    if (codeFile != null) {
      json['code_file'] = codeFile;
    }

    if (imageAddr != null) {
      json['image_addr'] = imageAddr;
    }

    if (imageSize != null) {
      json['image_size'] = imageSize;
    }

    if (arch != null) {
      json['arch'] = arch;
    }

    if (codeId != null) {
      json['code_id'] = codeId;
    }

    return json;
  }

  DebugImage copyWith({
    String? uuid,
    String? type,
    String? debugId,
    String? debugFile,
    String? codeFile,
    String? imageAddr,
    int? imageSize,
    String? arch,
    String? codeId,
  }) =>
      DebugImage(
        uuid: uuid ?? this.uuid,
        type: type ?? this.type,
        debugId: debugId ?? this.debugId,
        debugFile: debugFile ?? this.debugFile,
        codeFile: codeFile ?? this.codeFile,
        imageAddr: imageAddr ?? this.imageAddr,
        imageSize: imageSize ?? this.imageSize,
        arch: arch ?? this.arch,
        codeId: codeId ?? this.codeId,
      );
}
