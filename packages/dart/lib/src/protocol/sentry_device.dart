import 'package:meta/meta.dart';
import '../constants.dart';
import '../sentry_options.dart';
import 'access_aware_map.dart';
import 'sentry_attribute.dart';

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
  factory SentryDevice.fromJson(Map<String, Object?> data) {
    final json = AccessAwareMap(data);
    return SentryDevice(
      name: json.readString('name'),
      family: json.readString('family'),
      model: json.readString('model'),
      modelId: json.readString('model_id'),
      arch: json.readString('arch'),
      batteryLevel: json.readDouble('battery_level', min: 0, max: 100),
      orientation: switch (json.readString('orientation')) {
        'portrait' => SentryOrientation.portrait,
        'landscape' => SentryOrientation.landscape,
        _ => null,
      },
      manufacturer: json.readString('manufacturer'),
      brand: json.readString('brand'),
      screenHeightPixels: json.readInt('screen_height_pixels'),
      screenWidthPixels: json.readInt('screen_width_pixels'),
      screenDensity: json.readDouble('screen_density'),
      screenDpi: json.readInt('screen_dpi'),
      online: json.readBool('online'),
      charging: json.readBool('charging'),
      lowMemory: json.readBool('low_memory'),
      simulator: json.readBool('simulator'),
      memorySize: json.readInt('memory_size'),
      freeMemory: json.readInt('free_memory'),
      usableMemory: json.readInt('usable_memory'),
      storageSize: json.readInt('storage_size'),
      freeStorage: json.readInt('free_storage'),
      externalStorageSize: json.readInt('external_storage_size'),
      externalFreeStorage: json.readInt('external_free_storage'),
      bootTime: json.readDateTime('boot_time'),
      processorCount: json.readInt('processor_count'),
      cpuDescription: json.readString('cpu_description'),
      processorFrequency: json.readDouble('processor_frequency'),
      deviceType: json.readString('device_type'),
      batteryStatus: json.readString('battery_status'),
      deviceUniqueIdentifier: json.readString('device_unique_identifier'),
      supportsVibration: json.readBool('supports_vibration'),
      supportsAccelerometer: json.readBool('supports_accelerometer'),
      supportsGyroscope: json.readBool('supports_gyroscope'),
      supportsAudio: json.readBool('supports_audio'),
      supportsLocationService: json.readBool('supports_location_service'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'name': ?name,
      'family': ?family,
      'model': ?model,
      'model_id': ?modelId,
      'arch': ?arch,
      'battery_level': ?batteryLevel,
      'orientation': ?orientation?.name,
      'manufacturer': ?manufacturer,
      'brand': ?brand,
      'screen_width_pixels': ?screenWidthPixels,
      'screen_height_pixels': ?screenHeightPixels,
      'screen_density': ?screenDensity,
      'screen_dpi': ?screenDpi,
      'online': ?online,
      'charging': ?charging,
      'low_memory': ?lowMemory,
      'simulator': ?simulator,
      'memory_size': ?memorySize,
      'free_memory': ?freeMemory,
      'usable_memory': ?usableMemory,
      'storage_size': ?storageSize,
      'free_storage': ?freeStorage,
      'external_storage_size': ?externalStorageSize,
      'external_free_storage': ?externalFreeStorage,
      'boot_time': ?bootTime?.toIso8601String(),
      'processor_count': ?processorCount,
      'cpu_description': ?cpuDescription,
      'processor_frequency': ?processorFrequency,
      'device_type': ?deviceType,
      'battery_status': ?batteryStatus,
      'device_unique_identifier': ?deviceUniqueIdentifier,
      'supports_vibration': ?supportsVibration,
      'supports_accelerometer': ?supportsAccelerometer,
      'supports_gyroscope': ?supportsGyroscope,
      'supports_audio': ?supportsAudio,
      'supports_location_service': ?supportsLocationService,
    };
  }

  /// A map of stable semantic span attributes derived from this device.
  ///
  /// Only fields with a defined stable key in [SemanticAttributesConstants]
  /// are included. Intended for span v2 attributes; error and transaction
  /// payloads continue to use [toJson].
  @internal
  Map<String, SentryAttribute> toAttributes() {
    final attributes = <String, SentryAttribute>{};
    final name = this.name;
    if (name != null) {
      attributes[SemanticAttributesConstants.deviceName] =
          SentryAttribute.string(name);
    }
    final family = this.family;
    if (family != null) {
      attributes[SemanticAttributesConstants.deviceFamily] =
          SentryAttribute.string(family);
    }
    final model = this.model;
    if (model != null) {
      attributes[SemanticAttributesConstants.deviceModel] =
          SentryAttribute.string(model);
    }
    final modelId = this.modelId;
    if (modelId != null) {
      attributes[SemanticAttributesConstants.deviceModelId] =
          SentryAttribute.string(modelId);
    }
    final batteryLevel = this.batteryLevel;
    if (batteryLevel != null) {
      attributes[SemanticAttributesConstants.deviceBatteryLevel] =
          SentryAttribute.double(batteryLevel);
    }
    final orientation = this.orientation;
    if (orientation != null) {
      attributes[SemanticAttributesConstants.deviceOrientation] =
          SentryAttribute.string(orientation.name);
    }
    final manufacturer = this.manufacturer;
    if (manufacturer != null) {
      attributes[SemanticAttributesConstants.deviceManufacturer] =
          SentryAttribute.string(manufacturer);
    }
    final brand = this.brand;
    if (brand != null) {
      attributes[SemanticAttributesConstants.deviceBrand] =
          SentryAttribute.string(brand);
    }
    final screenHeightPixels = this.screenHeightPixels;
    if (screenHeightPixels != null) {
      attributes[SemanticAttributesConstants.deviceScreenHeightPixels] =
          SentryAttribute.int(screenHeightPixels);
    }
    final screenWidthPixels = this.screenWidthPixels;
    if (screenWidthPixels != null) {
      attributes[SemanticAttributesConstants.deviceScreenWidthPixels] =
          SentryAttribute.int(screenWidthPixels);
    }
    final screenDensity = this.screenDensity;
    if (screenDensity != null) {
      attributes[SemanticAttributesConstants.deviceScreenDensity] =
          SentryAttribute.double(screenDensity);
    }
    final screenDpi = this.screenDpi;
    if (screenDpi != null) {
      attributes[SemanticAttributesConstants.deviceScreenDpi] =
          SentryAttribute.int(screenDpi);
    }
    final online = this.online;
    if (online != null) {
      attributes[SemanticAttributesConstants.deviceOnline] =
          SentryAttribute.bool(online);
    }
    final charging = this.charging;
    if (charging != null) {
      attributes[SemanticAttributesConstants.deviceCharging] =
          SentryAttribute.bool(charging);
    }
    final lowMemory = this.lowMemory;
    if (lowMemory != null) {
      attributes[SemanticAttributesConstants.deviceLowMemory] =
          SentryAttribute.bool(lowMemory);
    }
    final simulator = this.simulator;
    if (simulator != null) {
      attributes[SemanticAttributesConstants.deviceSimulator] =
          SentryAttribute.bool(simulator);
    }
    final memorySize = this.memorySize;
    if (memorySize != null) {
      attributes[SemanticAttributesConstants.deviceMemorySize] =
          SentryAttribute.int(memorySize);
    }
    final freeMemory = this.freeMemory;
    if (freeMemory != null) {
      attributes[SemanticAttributesConstants.deviceFreeMemory] =
          SentryAttribute.int(freeMemory);
    }
    final usableMemory = this.usableMemory;
    if (usableMemory != null) {
      attributes[SemanticAttributesConstants.deviceUsableMemory] =
          SentryAttribute.int(usableMemory);
    }
    final storageSize = this.storageSize;
    if (storageSize != null) {
      attributes[SemanticAttributesConstants.deviceStorageSize] =
          SentryAttribute.int(storageSize);
    }
    final freeStorage = this.freeStorage;
    if (freeStorage != null) {
      attributes[SemanticAttributesConstants.deviceFreeStorage] =
          SentryAttribute.int(freeStorage);
    }
    final externalStorageSize = this.externalStorageSize;
    if (externalStorageSize != null) {
      attributes[SemanticAttributesConstants.deviceExternalStorageSize] =
          SentryAttribute.int(externalStorageSize);
    }
    final externalFreeStorage = this.externalFreeStorage;
    if (externalFreeStorage != null) {
      attributes[SemanticAttributesConstants.deviceExternalFreeStorage] =
          SentryAttribute.int(externalFreeStorage);
    }
    final bootTime = this.bootTime;
    if (bootTime != null) {
      attributes[SemanticAttributesConstants.deviceBootTime] =
          SentryAttribute.string(bootTime.toIso8601String());
    }
    final processorCount = this.processorCount;
    if (processorCount != null) {
      attributes[SemanticAttributesConstants.deviceProcessorCount] =
          SentryAttribute.int(processorCount);
    }
    final cpuDescription = this.cpuDescription;
    if (cpuDescription != null) {
      attributes[SemanticAttributesConstants.deviceCpuDescription] =
          SentryAttribute.string(cpuDescription);
    }
    final processorFrequency = this.processorFrequency;
    if (processorFrequency != null) {
      attributes[SemanticAttributesConstants.deviceProcessorFrequency] =
          SentryAttribute.double(processorFrequency);
    }
    final deviceUniqueIdentifier = this.deviceUniqueIdentifier;
    if (deviceUniqueIdentifier != null) {
      attributes[SemanticAttributesConstants.deviceId] = SentryAttribute.string(
        deviceUniqueIdentifier,
      );
    }
    return attributes;
  }
}
