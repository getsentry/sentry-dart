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
class SentryGpu {
  static const type = 'gpu';

  /// The name of the graphics device.
  String? name;

  /// The PCI identifier of the graphics device.
  int? id;

  /// The PCI vendor identifier of the graphics device.
  String? vendorId;

  /// The vendor name as reported by the graphics device.
  String? vendorName;

  /// The total GPU memory available in Megabytes.
  int? memorySize;

  /// The device low-level API type.
  String? apiType;

  /// Whether the GPU has multi-threaded rendering or not.
  bool? multiThreadedRendering;

  /// The Version of the graphics device.
  String? version;

  /// The Non-Power-Of-Two-Support support.
  String? npotSupport;

  /// Approximate "shader capability" level of the graphics device.
  /// For Example:
  /// Shader Model 2.0, OpenGL ES 3.0, Metal / OpenGL ES 3.1, 27 (unknown)
  String? graphicsShaderLevel;

  /// Largest size of a texture that is supported by the graphics hardware.
  /// For Example: 16384
  int? maxTextureSize;

  /// Whether compute shaders are available on the device.
  bool? supportsComputeShaders;

  /// Whether GPU draw call instancing is supported.
  bool? supportsDrawCallInstancing;

  /// Whether geometry shaders are available on the device.
  bool? supportsGeometryShaders;

  /// Whether ray tracing is available on the device.
  bool? supportsRayTracing;

  @internal
  final Map<String, dynamic>? unknown;

  SentryGpu({
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
  factory SentryGpu.fromJson(Map<String, Object?> data) {
    final json = AccessAwareMap(data);
    return SentryGpu(
      name: json.readString('name'),
      id: json.readInt('id'),
      vendorId: json.readString('vendor_id'),
      vendorName: json.readString('vendor_name'),
      memorySize: json.readInt('memory_size'),
      apiType: json.readString('api_type'),
      multiThreadedRendering: json.readBool('multi_threaded_rendering'),
      version: json.readString('version'),
      npotSupport: json.readString('npot_support'),
      graphicsShaderLevel: json.readString('graphics_shader_level'),
      maxTextureSize: json.readInt('max_texture_size'),
      supportsComputeShaders: json.readBool('supports_compute_shaders'),
      supportsDrawCallInstancing: json.readBool(
        'supports_draw_call_instancing',
      ),
      supportsGeometryShaders: json.readBool('supports_geometry_shaders'),
      supportsRayTracing: json.readBool('supports_ray_tracing'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'name': ?name,
      'id': ?id,
      'vendor_id': ?vendorId,
      'vendor_name': ?vendorName,
      'memory_size': ?memorySize,
      'api_type': ?apiType,
      'multi_threaded_rendering': ?multiThreadedRendering,
      'version': ?version,
      'npot_support': ?npotSupport,
      'graphics_shader_level': ?graphicsShaderLevel,
      'max_texture_size': ?maxTextureSize,
      'supports_compute_shaders': ?supportsComputeShaders,
      'supports_draw_call_instancing': ?supportsDrawCallInstancing,
      'supports_geometry_shaders': ?supportsGeometryShaders,
      'supports_ray_tracing': ?supportsRayTracing,
    };
  }
}
