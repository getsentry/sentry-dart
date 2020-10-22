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

class Gpu {
  /// The name of the graphics device.
  final String name;

  /// The PCI identifier of the graphics device.
  final int id;

  /// The PCI vendor identifier of the graphics device.
  final int vendorId;

  /// The vendor name as reported by the graphics device.
  final String vendorName;

  /// The total GPU memory available in Megabytes.
  final int memorySize;

  /// The device low-level API type.
  final String apiType;

  /// Whether the GPU has multi-threaded rendering or not.
  final bool multiThreadedRendering;

  /// The Version of the graphics device.
  final String version;

  /// The Non-Power-Of-Two-Support support.
  final String npotSupport;

  const Gpu({
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
}
