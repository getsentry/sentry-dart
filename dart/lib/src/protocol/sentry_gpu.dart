// https://develop.sentry.dev/sdk/event-payloads/contexts/#gpu-context
// Example:
// "gpu": {
//   "name": "AMD Radeon Pro 560",
//   "vendor_name": "Apple",
//   "memory_size": 4096,
//   "api_type": "Metal",
//   "multi_threaded_rendering": true,
//   "version": "Metal",
//   "npot_support": "Full"
// }

import 'package:meta/meta.dart';

/// GPU context describes the GPU of the device.
@immutable
class SentryGpu {
  static const type = 'gpu';

  /// The name of the graphics device.
  final String? name;

  /// The PCI identifier of the graphics device.
  final int? id;

  /// The PCI vendor identifier of the graphics device.
  final int? vendorId;

  /// The vendor name as reported by the graphics device.
  final String? vendorName;

  /// The total GPU memory available in Megabytes.
  final int? memorySize;

  /// The device low-level API type.
  final String? apiType;

  /// Whether the GPU has multi-threaded rendering or not.
  final bool? multiThreadedRendering;

  /// The Version of the graphics device.
  final String? version;

  /// The Non-Power-Of-Two-Support support.
  final String? npotSupport;

  const SentryGpu({
    this.name,
    this.id,
    this.vendorId,
    this.vendorName,
    this.memorySize,
    this.apiType,
    this.multiThreadedRendering,
    this.version,
    this.npotSupport,
  });

  /// Deserializes a [SentryGpu] from JSON [Map].
  factory SentryGpu.fromJson(Map<String, dynamic> data) => SentryGpu(
        name: data['name'],
        id: data['id'],
        vendorId: data['vendor_id'],
        vendorName: data['vendor_name'],
        memorySize: data['memory_size'],
        apiType: data['api_type'],
        multiThreadedRendering: data['multi_threaded_rendering'],
        version: data['version'],
        npotSupport: data['npot_support'],
      );

  SentryGpu clone() => SentryGpu(
        name: name,
        id: id,
        vendorId: vendorId,
        vendorName: vendorName,
        memorySize: memorySize,
        apiType: apiType,
        multiThreadedRendering: multiThreadedRendering,
        version: version,
        npotSupport: npotSupport,
      );

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (name != null) {
      json['name'] = name;
    }

    if (id != null) {
      json['id'] = id;
    }

    if (vendorId != null) {
      json['vendor_id'] = vendorId;
    }

    if (vendorName != null) {
      json['vendor_name'] = vendorName;
    }

    if (memorySize != null) {
      json['memory_size'] = memorySize;
    }

    if (apiType != null) {
      json['api_type'] = apiType;
    }

    if (multiThreadedRendering != null) {
      json['multi_threaded_rendering'] = multiThreadedRendering;
    }

    if (version != null) {
      json['version'] = version;
    }

    if (npotSupport != null) {
      json['npot_support'] = npotSupport;
    }

    return json;
  }

  SentryGpu copyWith({
    String? name,
    int? id,
    int? vendorId,
    String? vendorName,
    int? memorySize,
    String? apiType,
    bool? multiThreadedRendering,
    String? version,
    String? npotSupport,
  }) =>
      SentryGpu(
        name: name ?? this.name,
        id: id ?? this.id,
        vendorId: vendorId ?? this.vendorId,
        vendorName: vendorName ?? this.vendorName,
        memorySize: memorySize ?? this.memorySize,
        apiType: apiType ?? this.apiType,
        multiThreadedRendering:
            multiThreadedRendering ?? this.multiThreadedRendering,
        version: version ?? this.version,
        npotSupport: npotSupport ?? this.npotSupport,
      );
}
