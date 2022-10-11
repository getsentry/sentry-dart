import 'package:meta/meta.dart';
import 'sentry_operating_system.dart';
import 'sentry_culture.dart';
import '../sentry_options.dart';

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
    this.timezone,
    this.language,
    this.theme,
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
  }) : assert(
          batteryLevel == null || (batteryLevel >= 0 && batteryLevel <= 100),
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
  /// This field is deprecated, please use [screenHeightPixels]
  /// and [screenWidthPixels] instead.
  @Deprecated(
    'Scheduled for removal in v7.0.0. '
    'Use SentryDevice.screenHeightPixels and SentryDevice.screenWidthPixels instead',
  )
  final String? screenResolution;

  /// The screen height in pixels. (e.g.: `600`, `1080`).
  final int? screenHeightPixels;

  /// The screen width in pixels. (e.g.: `800`, `1920`).
  final int? screenWidthPixels;

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
  /// This field is deprecated, please use [SentryCulture.timezone] instead.
  @Deprecated(
    'Scheduled for removal in v7.0.0. '
    'Use SentryCulture.timezone instead',
  )
  final String? timezone;

  /// The language of the device, e.g.: `en_US`.
  /// This field is deprecated, please use [SentryCulture.locale] instead.
  @Deprecated(
    'Scheduled for removal in v7.0.0. '
    'Use SentryCulture.locale instead',
  )
  final String? language;

  /// The theme of the device. Typically `light` or `dark`
  /// Deprecated: Use [SentryOperatingSystem.theme] instead.
  @Deprecated(
    'Scheduled for removal in v7.0.0. '
    'Use SentryOperatingSystem.theme instead',
  )
  final String? theme;

  /// Optional. Number of "logical processors". For example, `8`.
  final int? processorCount;

  /// Optional. CPU description. For example, `Intel(R) Core(TM)2 Quad CPU Q6600 @ 2.40GHz`.
  final String? cpuDescription;

  /// Optional. Processor frequency in MHz. Note that the actual CPU frequency
  /// might vary depending on current load and power conditions,
  /// especially on low-powered devices like phones and laptops.
  final double? processorFrequency;

  /// Optional. Kind of device the application is running on.
  /// For example, `Unknown`, `Handheld`, `Console`, `Desktop`.
  final String? deviceType;

  /// Optional. Status of the device's battery.
  /// For example, `Unknown`, `Charging`, `Discharging`, `NotCharging`, `Full`.
  final String? batteryStatus;

  /// Optional. Unique device identifier.
  /// This value might only be used if [SentryOptions.sendDefaultPii]
  ///  is enabled.
  final String? deviceUniqueIdentifier;

  /// Optional. Is vibration available on the device?
  final bool? supportsVibration;

  /// Optional. Is accelerometer available on the device?
  final bool? supportsAccelerometer;

  /// Optional. Is gyroscope available on the device?
  final bool? supportsGyroscope;

  /// Optional. Is audio available on the device?
  final bool? supportsAudio;

  /// Optional. Is the device capable of reporting its location?
  final bool? supportsLocationService;

  /// Deserializes a [SentryDevice] from JSON [Map].
  factory SentryDevice.fromJson(Map<String, dynamic> data) => SentryDevice(
        name: data['name'],
        family: data['family'],
        model: data['model'],
        modelId: data['model_id'],
        arch: data['arch'],
        batteryLevel: data['battery_level'],
        orientation: data['orientation'] == 'portrait'
            ? SentryOrientation.portrait
            : data['orientation'] == 'landscape'
                ? SentryOrientation.landscape
                : null,
        manufacturer: data['manufacturer'],
        brand: data['brand'],
        screenResolution: data['screen_resolution'],
        screenHeightPixels: data['screen_height_pixels']?.toInt(),
        screenWidthPixels: data['screen_width_pixels']?.toInt(),
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
        language: data['language'],
        theme: data['theme'],
        processorCount: data['processor_count'],
        cpuDescription: data['cpu_description'],
        processorFrequency: data['processor_frequency'],
        deviceType: data['device_type'],
        batteryStatus: data['battery_status'],
        deviceUniqueIdentifier: data['device_unique_identifier'],
        supportsVibration: data['supports_vibration'],
        supportsAccelerometer: data['supports_accelerometer'],
        supportsGyroscope: data['supports_gyroscope'],
        supportsAudio: data['supports_audio'],
        supportsLocationService: data['supports_location_service'],
      );

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
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
    return <String, dynamic>{
      if (name != null) 'name': name,
      if (family != null) 'family': family,
      if (model != null) 'model': model,
      if (modelId != null) 'model_id': modelId,
      if (arch != null) 'arch': arch,
      if (batteryLevel != null) 'battery_level': batteryLevel,
      if (orientation != null) 'orientation': orientation,
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
      // ignore: deprecated_member_use_from_same_package
      if (screenResolution != null) 'screen_resolution': screenResolution,
      // ignore: deprecated_member_use_from_same_package
      if (timezone != null) 'timezone': timezone,
      // ignore: deprecated_member_use_from_same_package
      if (language != null) 'language': language,
      // ignore: deprecated_member_use_from_same_package
      if (theme != null) 'theme': theme,
    };
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
        // ignore: deprecated_member_use_from_same_package
        screenResolution: screenResolution,
        // ignore: deprecated_member_use_from_same_package
        timezone: timezone,
        // ignore: deprecated_member_use_from_same_package
        theme: theme,
        // ignore: deprecated_member_use_from_same_package
        language: language,
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
    String? timezone,
    String? language,
    String? theme,
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
        // ignore: deprecated_member_use_from_same_package
        screenResolution: screenResolution ?? this.screenResolution,
        // ignore: deprecated_member_use_from_same_package
        timezone: timezone ?? this.timezone,
        // ignore: deprecated_member_use_from_same_package
        language: language ?? this.language,
        // ignore: deprecated_member_use_from_same_package
        theme: theme ?? this.theme,
      );
}
