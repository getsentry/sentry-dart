import '../sentry_options.dart';
import '../protocol/sentry_device.dart';
import 'dart:io';
import 'package:meta/meta.dart';

@internal
SentryDevice getSentryDevice(SentryDevice? device, SentryOptions options) {
  device ??= SentryDevice();
  return device
    ..name =
        device.name ?? (options.sendDefaultPii ? Platform.localHostname : null)
    ..processorCount = device.processorCount ?? Platform.numberOfProcessors
    ..memorySize = device.memorySize
    ..freeMemory = device.freeMemory;
}
