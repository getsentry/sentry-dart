import 'package:meta/meta.dart';

/// If a device is on portrait or landscape mode
enum SentryOrientation { portrait, landscape }

/// This describes the device that caused the event.
@immutable
class SentryDevice {
  static const type = 'device';

  const SentryDevice({
    this.name,
    this.family,
    this.model,
    this.modelId,
    this.arch,
    this.batteryLevel,
    this.orientation,
    this.manufacturer,
    this.brand,
    this.screenResolution,
    this.screenDensity,
    this.screenDpi,
    this.online,
    this.charging,
    this.lowMemory,
    this.simulator,
    this.memorySize,
    this.freeMemory,
    this.usableMemory,
    this.storageSize,
    this.freeStorage,
    this.externalStorageSize,
    this.externalFreeStorage,
    this.bootTime,
    this.timezone,
  }) : assert(
          batteryLevel == null || (batteryLevel >= 0 && batteryLevel <= 100),
        );

  factory SentryDevice.fromJson(Map<String, dynamic> data) => SentryDevice(
        name: data['name'],
        family: data['family'],
        model: data['model'],
        modelId: data['model_id'],
        arch: data['arch'],
        batteryLevel: data['battery_level'],
        orientation: data['orientation'],
        manufacturer: data['manufacturer'],
        brand: data['brand'],
        screenResolution: data['screen_resolution'],
        screenDensity: data['screen_density'],
        screenDpi: data['screen_dpi'],
        online: data['online'],
        charging: data['charging'],
        lowMemory: data['low_memory'],
        simulator: data['simulator'],
        memorySize: data['memory_size'],
        freeMemory: data['free_memory'],
        usableMemory: data['usable_memory'],
        storageSize: data['storage_size'],
        freeStorage: data['free_storage'],
        externalStorageSize: data['external_storage_size'],
        externalFreeStorage: data['external_free_storage'],
        bootTime: data['boot_time'] != null
            ? DateTime.tryParse(data['boot_time'])
            : null,
        timezone: data['timezone'],
      );

  /// The name of the device. This is typically a hostname.
  final String? name;

  /// The family of the device.
  ///
  /// This is normally the common part of model names across generations.
  /// For instance `iPhone` would be a reasonable family,
  /// so would be `Samsung Galaxy`.
  final String? family;

  /// The model name. This for instance can be `Samsung Galaxy S3`.
  final String? model;

  /// An internal hardware revision to identify the device exactly.
  final String? modelId;

  /// The CPU architecture.
  final String? arch;

  /// If the device has a battery, this can be an floating point value
  /// defining the battery level (in the range 0-100).
  final double? batteryLevel;

  /// Defines the orientation of a device.
  final SentryOrientation? orientation;

  /// The manufacturer of the device.
  final String? manufacturer;

  /// The brand of the device.
  final String? brand;

  /// The screen resolution. (e.g.: `800x600`, `3040x1444`).
  final String? screenResolution;

  /// A floating point denoting the screen density.
  final double? screenDensity;

  /// A decimal value reflecting the DPI (dots-per-inch) density.
  final int? screenDpi;

  /// Whether the device was online or not.
  final bool? online;

  /// Whether the device was charging or not.
  final bool? charging;

  /// Whether the device was low on memory.
  final bool? lowMemory;

  /// A flag indicating whether this device is a simulator or an actual device.
  final bool? simulator;

  /// Total system memory available in bytes.
  final int? memorySize;

  /// Free system memory in bytes.
  final int? freeMemory;

  /// Memory usable for the app in bytes.
  final int? usableMemory;

  /// Total device storage in bytes.
  final int? storageSize;

  /// Free device storage in bytes.
  final int? freeStorage;

  /// Total size of an attached external storage in bytes
  /// (e.g.: android SDK card).
  final int? externalStorageSize;

  /// Free size of an attached external storage in bytes
  /// (e.g.: android SDK card).
  final int? externalFreeStorage;

  /// When the system was booted
  final DateTime? bootTime;

  /// The timezone of the device, e.g.: `Europe/Vienna`.
  final String? timezone;

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    String? orientation;

    switch (this.orientation) {
      case SentryOrientation.portrait:
        orientation = 'portait';
        break;
      case SentryOrientation.landscape:
        orientation = 'landscape';
        break;
      case null:
        orientation = null;
        break;
    }

    if (name != null) {
      json['name'] = name;
    }

    if (family != null) {
      json['family'] = family;
    }

    if (model != null) {
      json['model'] = model;
    }

    if (modelId != null) {
      json['model_id'] = modelId;
    }

    if (arch != null) {
      json['arch'] = arch;
    }

    if (batteryLevel != null) {
      json['battery_level'] = batteryLevel;
    }

    if (orientation != null) {
      json['orientation'] = orientation;
    }

    if (manufacturer != null) {
      json['manufacturer'] = manufacturer;
    }

    if (brand != null) {
      json['brand'] = brand;
    }

    if (screenResolution != null) {
      json['screen_resolution'] = screenResolution;
    }

    if (screenDensity != null) {
      json['screen_density'] = screenDensity;
    }

    if (screenDpi != null) {
      json['screen_dpi'] = screenDpi;
    }

    if (online != null) {
      json['online'] = online;
    }

    if (charging != null) {
      json['charging'] = charging;
    }

    if (lowMemory != null) {
      json['low_memory'] = lowMemory;
    }

    if (simulator != null) {
      json['simulator'] = simulator;
    }

    if (memorySize != null) {
      json['memory_size'] = memorySize;
    }

    if (freeMemory != null) {
      json['free_memory'] = freeMemory;
    }

    if (usableMemory != null) {
      json['usable_memory'] = usableMemory;
    }

    if (storageSize != null) {
      json['storage_size'] = storageSize;
    }

    if (freeStorage != null) {
      json['free_storage'] = freeStorage;
    }

    if (externalStorageSize != null) {
      json['external_storage_size'] = externalStorageSize;
    }

    if (externalFreeStorage != null) {
      json['external_free_storage'] = externalFreeStorage;
    }

    if (bootTime != null) {
      json['boot_time'] = bootTime!.toIso8601String();
    }

    if (timezone != null) {
      json['timezone'] = timezone;
    }

    return json;
  }

  SentryDevice clone() => SentryDevice(
        name: name,
        family: family,
        model: model,
        modelId: modelId,
        arch: arch,
        batteryLevel: batteryLevel,
        orientation: orientation,
        manufacturer: manufacturer,
        brand: brand,
        screenResolution: screenResolution,
        screenDensity: screenDensity,
        screenDpi: screenDpi,
        online: online,
        charging: charging,
        lowMemory: lowMemory,
        simulator: simulator,
        memorySize: memorySize,
        freeMemory: freeMemory,
        usableMemory: usableMemory,
        storageSize: storageSize,
        freeStorage: freeStorage,
        externalStorageSize: externalStorageSize,
        externalFreeStorage: externalFreeStorage,
        bootTime: bootTime,
        timezone: timezone,
      );

  SentryDevice copyWith({
    String? name,
    String? family,
    String? model,
    String? modelId,
    String? arch,
    double? batteryLevel,
    SentryOrientation? orientation,
    String? manufacturer,
    String? brand,
    String? screenResolution,
    double? screenDensity,
    int? screenDpi,
    bool? online,
    bool? charging,
    bool? lowMemory,
    bool? simulator,
    int? memorySize,
    int? freeMemory,
    int? usableMemory,
    int? storageSize,
    int? freeStorage,
    int? externalStorageSize,
    int? externalFreeStorage,
    DateTime? bootTime,
    String? timezone,
  }) =>
      SentryDevice(
        name: name ?? this.name,
        family: family ?? this.family,
        model: model ?? this.model,
        modelId: modelId ?? this.modelId,
        arch: arch ?? this.arch,
        batteryLevel: batteryLevel ?? this.batteryLevel,
        orientation: orientation ?? this.orientation,
        manufacturer: manufacturer ?? this.manufacturer,
        brand: brand ?? this.brand,
        screenResolution: screenResolution ?? this.screenResolution,
        screenDensity: screenDensity ?? this.screenDensity,
        screenDpi: screenDpi ?? this.screenDpi,
        online: online ?? this.online,
        charging: charging ?? this.charging,
        lowMemory: lowMemory ?? this.lowMemory,
        simulator: simulator ?? this.simulator,
        memorySize: memorySize ?? this.memorySize,
        freeMemory: freeMemory ?? this.freeMemory,
        usableMemory: usableMemory ?? this.usableMemory,
        storageSize: storageSize ?? this.storageSize,
        freeStorage: freeStorage ?? this.freeStorage,
        externalStorageSize: externalStorageSize ?? this.externalStorageSize,
        externalFreeStorage: externalFreeStorage ?? this.externalFreeStorage,
        bootTime: bootTime ?? this.bootTime,
        timezone: timezone ?? this.timezone,
      );
}
