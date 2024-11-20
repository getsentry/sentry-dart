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

import 'access_aware_map.dart';

/// GPU context describes the GPU of the device.
@immutable
class SentryGpu {
  static const type = 'gpu';

  /// The name of the graphics device.
  final String? name;

  /// The PCI identifier of the graphics device.
  final int? id;

  /// The PCI vendor identifier of the graphics device.
  final String? vendorId;

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

  /// Approximate "shader capability" level of the graphics device.
  /// For Example:
  /// Shader Model 2.0, OpenGL ES 3.0, Metal / OpenGL ES 3.1, 27 (unknown)
  final String? graphicsShaderLevel;

  /// Largest size of a texture that is supported by the graphics hardware.
  /// For Example: 16384
  final int? maxTextureSize;

  /// Whether compute shaders are available on the device.
  final bool? supportsComputeShaders;

  /// Whether GPU draw call instancing is supported.
  final bool? supportsDrawCallInstancing;

  /// Whether geometry shaders are available on the device.
  final bool? supportsGeometryShaders;

  /// Whether ray tracing is available on the device.
  final bool? supportsRayTracing;

  @internal
  final Map<String, dynamic>? unknown;

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
    this.graphicsShaderLevel,
    this.maxTextureSize,
    this.supportsComputeShaders,
    this.supportsDrawCallInstancing,
    this.supportsGeometryShaders,
    this.supportsRayTracing,
    this.unknown,
  });

  /// Deserializes a [SentryGpu] from JSON [Map].
  factory SentryGpu.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SentryGpu(
      name: json['name'],
      id: json['id'],
      vendorId: json['vendor_id'],
      vendorName: json['vendor_name'],
      memorySize: json['memory_size'],
      apiType: json['api_type'],
      multiThreadedRendering: json['multi_threaded_rendering'],
      version: json['version'],
      npotSupport: json['npot_support'],
      graphicsShaderLevel: json['graphics_shader_level'],
      maxTextureSize: json['max_texture_size'],
      supportsComputeShaders: json['supports_compute_shaders'],
      supportsDrawCallInstancing: json['supports_draw_call_instancing'],
      supportsGeometryShaders: json['supports_geometry_shaders'],
      supportsRayTracing: json['supports_ray_tracing'],
      unknown: json.notAccessed(),
    );
  }

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
        graphicsShaderLevel: graphicsShaderLevel,
        maxTextureSize: maxTextureSize,
        supportsComputeShaders: supportsComputeShaders,
        supportsDrawCallInstancing: supportsDrawCallInstancing,
        supportsGeometryShaders: supportsGeometryShaders,
        supportsRayTracing: supportsRayTracing,
        unknown: unknown,
      );

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      if (name != null) 'name': name,
      if (id != null) 'id': id,
      if (vendorId != null) 'vendor_id': vendorId,
      if (vendorName != null) 'vendor_name': vendorName,
      if (memorySize != null) 'memory_size': memorySize,
      if (apiType != null) 'api_type': apiType,
      if (multiThreadedRendering != null)
        'multi_threaded_rendering': multiThreadedRendering,
      if (version != null) 'version': version,
      if (npotSupport != null) 'npot_support': npotSupport,
      if (graphicsShaderLevel != null)
        'graphics_shader_level': graphicsShaderLevel,
      if (maxTextureSize != null) 'max_texture_size': maxTextureSize,
      if (supportsComputeShaders != null)
        'supports_compute_shaders': supportsComputeShaders,
      if (supportsDrawCallInstancing != null)
        'supports_draw_call_instancing': supportsDrawCallInstancing,
      if (supportsGeometryShaders != null)
        'supports_geometry_shaders': supportsGeometryShaders,
      if (supportsRayTracing != null)
        'supports_ray_tracing': supportsRayTracing,
    };
  }

  SentryGpu copyWith({
    String? name,
    int? id,
    String? vendorId,
    String? vendorName,
    int? memorySize,
    String? apiType,
    bool? multiThreadedRendering,
    String? version,
    String? npotSupport,
    String? graphicsShaderLevel,
    int? maxTextureSize,
    bool? supportsComputeShaders,
    bool? supportsDrawCallInstancing,
    bool? supportsGeometryShaders,
    bool? supportsRayTracing,
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
        graphicsShaderLevel: graphicsShaderLevel ?? this.graphicsShaderLevel,
        maxTextureSize: maxTextureSize ?? this.maxTextureSize,
        supportsComputeShaders:
            supportsComputeShaders ?? this.supportsComputeShaders,
        supportsDrawCallInstancing:
            supportsDrawCallInstancing ?? this.supportsDrawCallInstancing,
        supportsGeometryShaders:
            supportsGeometryShaders ?? this.supportsGeometryShaders,
        supportsRayTracing: supportsRayTracing ?? this.supportsRayTracing,
        unknown: unknown,
      );
}
