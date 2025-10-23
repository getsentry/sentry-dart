import 'package:meta/meta.dart';
import '../sentry_options.dart';
import '../utils/type_safe_map_access.dart';
import 'access_aware_map.dart';

/// If a device is on portrait or landscape mode
enum SentryOrientation { portrait, landscape }

/// This describes the device that caused the event.
class SentryDevice {
  static const type = 'device';

  SentryDevice({
    this.name,
    this.family,
    this.model,
    this.modelId,
    this.arch,
    this.batteryLevel,
    this.orientation,
    this.manufacturer,
    this.brand,
    this.screenHeightPixels,
    this.screenWidthPixels,
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
    this.processorCount,
    this.cpuDescription,
    this.processorFrequency,
    this.deviceType,
    this.batteryStatus,
    this.deviceUniqueIdentifier,
    this.supportsVibration,
    this.supportsAccelerometer,
    this.supportsGyroscope,
    this.supportsAudio,
    this.supportsLocationService,
    this.unknown,
  }) : assert(
          batteryLevel == null || (batteryLevel >= 0 && batteryLevel <= 100),
        );

  /// The name of the device. This is typically a hostname.
  String? name;

  /// The family of the device.
  ///
  /// This is normally the common part of model names across generations.
  /// For instance `iPhone` would be a reasonable family,
  /// so would be `Samsung Galaxy`.
  String? family;

  /// The model name. This for instance can be `Samsung Galaxy S3`.
  String? model;

  /// An internal hardware revision to identify the device exactly.
  String? modelId;

  /// The CPU architecture.
  String? arch;

  /// If the device has a battery, this can be an floating point value
  /// defining the battery level (in the range 0-100).
  double? batteryLevel;

  /// Defines the orientation of a device.
  SentryOrientation? orientation;

  /// The manufacturer of the device.
  String? manufacturer;

  /// The brand of the device.
  String? brand;

  /// The screen height in pixels. (e.g.: `600`, `1080`).
  int? screenHeightPixels;

  /// The screen width in pixels. (e.g.: `800`, `1920`).
  int? screenWidthPixels;

  /// A floating point denoting the screen density.
  double? screenDensity;

  /// A decimal value reflecting the DPI (dots-per-inch) density.
  int? screenDpi;

  /// Whether the device was online or not.
  bool? online;

  /// Whether the device was charging or not.
  bool? charging;

  /// Whether the device was low on memory.
  bool? lowMemory;

  /// A flag indicating whether this device is a simulator or an actual device.
  bool? simulator;

  /// Total system memory available in bytes.
  int? memorySize;

  /// Free system memory in bytes.
  int? freeMemory;

  /// Memory usable for the app in bytes.
  int? usableMemory;

  /// Total device storage in bytes.
  int? storageSize;

  /// Free device storage in bytes.
  int? freeStorage;

  /// Total size of an attached external storage in bytes
  /// (e.g.: android SDK card).
  int? externalStorageSize;

  /// Free size of an attached external storage in bytes
  /// (e.g.: android SDK card).
  int? externalFreeStorage;

  /// When the system was booted
  DateTime? bootTime;

  /// Optional. Number of "logical processors". For example, `8`.
  int? processorCount;

  /// Optional. CPU description. For example, `Intel(R) Core(TM)2 Quad CPU Q6600 @ 2.40GHz`.
  String? cpuDescription;

  /// Optional. Processor frequency in MHz. Note that the actual CPU frequency
  /// might vary depending on current load and power conditions,
  /// especially on low-powered devices like phones and laptops.
  double? processorFrequency;

  /// Optional. Kind of device the application is running on.
  /// For example, `Unknown`, `Handheld`, `Console`, `Desktop`.
  String? deviceType;

  /// Optional. Status of the device's battery.
  /// For example, `Unknown`, `Charging`, `Discharging`, `NotCharging`, `Full`.
  String? batteryStatus;

  /// Optional. Unique device identifier.
  /// This value might only be used if [SentryOptions.sendDefaultPii]
  ///  is enabled.
  String? deviceUniqueIdentifier;

  /// Optional. Is vibration available on the device?
  bool? supportsVibration;

  /// Optional. Is accelerometer available on the device?
  bool? supportsAccelerometer;

  /// Optional. Is gyroscope available on the device?
  bool? supportsGyroscope;

  /// Optional. Is audio available on the device?
  bool? supportsAudio;

  /// Optional. Is the device capable of reporting its location?
  bool? supportsLocationService;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryDevice] from JSON [Map].
  factory SentryDevice.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SentryDevice(
      name: json.getValueOrNull('name'),
      family: json.getValueOrNull('family'),
      model: json.getValueOrNull('model'),
      modelId: json.getValueOrNull('model_id'),
      arch: json.getValueOrNull('arch'),
      batteryLevel: json.getValueOrNull('battery_level'),
      orientation: switch (json.getValueOrNull('orientation')) {
        'portrait' => SentryOrientation.portrait,
        'landscape' => SentryOrientation.landscape,
        _ => null,
      },
      manufacturer: json.getValueOrNull('manufacturer'),
      brand: json.getValueOrNull('brand'),
      screenHeightPixels: json.getValueOrNull('screen_height_pixels'),
      screenWidthPixels: json.getValueOrNull('screen_width_pixels'),
      screenDensity: json.getValueOrNull('screen_density'),
      screenDpi: json.getValueOrNull('screen_dpi'),
      online: json.getValueOrNull('online'),
      charging: json.getValueOrNull('charging'),
      lowMemory: json.getValueOrNull('low_memory'),
      simulator: json.getValueOrNull('simulator'),
      memorySize: json.getValueOrNull('memory_size'),
      freeMemory: json.getValueOrNull('free_memory'),
      usableMemory: json.getValueOrNull('usable_memory'),
      storageSize: json.getValueOrNull('storage_size'),
      freeStorage: json.getValueOrNull('free_storage'),
      externalStorageSize: json.getValueOrNull('external_storage_size'),
      externalFreeStorage: json.getValueOrNull('external_free_storage'),
      bootTime: json.getValueOrNull('boot_time'),
      processorCount: json.getValueOrNull('processor_count'),
      cpuDescription: json.getValueOrNull('cpu_description'),
      processorFrequency: json.getValueOrNull('processor_frequency'),
      deviceType: json.getValueOrNull('device_type'),
      batteryStatus: json.getValueOrNull('battery_status'),
      deviceUniqueIdentifier: json.getValueOrNull('device_unique_identifier'),
      supportsVibration: json.getValueOrNull('supports_vibration'),
      supportsAccelerometer: json.getValueOrNull('supports_accelerometer'),
      supportsGyroscope: json.getValueOrNull('supports_gyroscope'),
      supportsAudio: json.getValueOrNull('supports_audio'),
      supportsLocationService: json.getValueOrNull('supports_location_service'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      if (name != null) 'name': name,
      if (family != null) 'family': family,
      if (model != null) 'model': model,
      if (modelId != null) 'model_id': modelId,
      if (arch != null) 'arch': arch,
      if (batteryLevel != null) 'battery_level': batteryLevel,
      if (orientation != null) 'orientation': orientation!.name,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (brand != null) 'brand': brand,
      if (screenWidthPixels != null) 'screen_width_pixels': screenWidthPixels,
      if (screenHeightPixels != null)
        'screen_height_pixels': screenHeightPixels,
      if (screenDensity != null) 'screen_density': screenDensity,
      if (screenDpi != null) 'screen_dpi': screenDpi,
      if (online != null) 'online': online,
      if (charging != null) 'charging': charging,
      if (lowMemory != null) 'low_memory': lowMemory,
      if (simulator != null) 'simulator': simulator,
      if (memorySize != null) 'memory_size': memorySize,
      if (freeMemory != null) 'free_memory': freeMemory,
      if (usableMemory != null) 'usable_memory': usableMemory,
      if (storageSize != null) 'storage_size': storageSize,
      if (freeStorage != null) 'free_storage': freeStorage,
      if (externalStorageSize != null)
        'external_storage_size': externalStorageSize,
      if (externalFreeStorage != null)
        'external_free_storage': externalFreeStorage,
      if (bootTime != null) 'boot_time': bootTime!.toIso8601String(),
      if (processorCount != null) 'processor_count': processorCount,
      if (cpuDescription != null) 'cpu_description': cpuDescription,
      if (processorFrequency != null) 'processor_frequency': processorFrequency,
      if (deviceType != null) 'device_type': deviceType,
      if (batteryStatus != null) 'battery_status': batteryStatus,
      if (deviceUniqueIdentifier != null)
        'device_unique_identifier': deviceUniqueIdentifier,
      if (supportsVibration != null) 'supports_vibration': supportsVibration,
      if (supportsAccelerometer != null)
        'supports_accelerometer': supportsAccelerometer,
      if (supportsGyroscope != null) 'supports_gyroscope': supportsGyroscope,
      if (supportsAudio != null) 'supports_audio': supportsAudio,
      if (supportsLocationService != null)
        'supports_location_service': supportsLocationService,
    };
  }

  @Deprecated('Will be removed in a future version.')
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
        screenHeightPixels: screenHeightPixels,
        screenWidthPixels: screenWidthPixels,
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
        processorCount: processorCount,
        cpuDescription: cpuDescription,
        processorFrequency: processorFrequency,
        deviceType: deviceType,
        batteryStatus: batteryStatus,
        deviceUniqueIdentifier: deviceUniqueIdentifier,
        supportsVibration: supportsVibration,
        supportsAccelerometer: supportsAccelerometer,
        supportsGyroscope: supportsGyroscope,
        supportsAudio: supportsAudio,
        supportsLocationService: supportsLocationService,
        unknown: unknown,
      );

  @Deprecated('Assign values directly to the instance.')
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
    int? screenHeightPixels,
    int? screenWidthPixels,
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
    int? processorCount,
    String? cpuDescription,
    double? processorFrequency,
    String? deviceType,
    String? batteryStatus,
    String? deviceUniqueIdentifier,
    bool? supportsVibration,
    bool? supportsAccelerometer,
    bool? supportsGyroscope,
    bool? supportsAudio,
    bool? supportsLocationService,
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
        screenHeightPixels: screenHeightPixels ?? this.screenHeightPixels,
        screenWidthPixels: screenWidthPixels ?? this.screenWidthPixels,
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
        processorCount: processorCount ?? this.processorCount,
        cpuDescription: cpuDescription ?? this.cpuDescription,
        processorFrequency: processorFrequency ?? this.processorFrequency,
        deviceType: deviceType ?? this.deviceType,
        batteryStatus: batteryStatus ?? this.batteryStatus,
        deviceUniqueIdentifier:
            deviceUniqueIdentifier ?? this.deviceUniqueIdentifier,
        supportsVibration: supportsVibration ?? this.supportsVibration,
        supportsAccelerometer:
            supportsAccelerometer ?? this.supportsAccelerometer,
        supportsGyroscope: supportsGyroscope ?? this.supportsGyroscope,
        supportsAudio: supportsAudio ?? this.supportsAudio,
        supportsLocationService:
            supportsLocationService ?? this.supportsLocationService,
        unknown: unknown,
      );
}
