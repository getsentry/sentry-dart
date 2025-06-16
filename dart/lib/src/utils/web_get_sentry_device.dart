import '../sentry_options.dart';
import '../protocol/sentry_device.dart';
import 'package:web/web.dart' as web show window, Window;
import 'package:meta/meta.dart';

@internal
SentryDevice getSentryDevice(SentryDevice? device, SentryOptions options) {
  final window = web.window;
  device ??= SentryDevice();
  return device
    ..online = device.online ?? window.navigator.onLine
    ..memorySize = device.memorySize ?? _getMemorySize(window)
    ..orientation = device.orientation ?? _getScreenOrientation(window)
    ..screenHeightPixels =
        device.screenHeightPixels ?? window.screen.availHeight
    ..screenWidthPixels = device.screenWidthPixels ?? window.screen.availWidth
    ..screenDensity =
        device.screenDensity ?? window.devicePixelRatio.toDouble();
}

int? _getMemorySize(web.Window window) {
  // https://developer.mozilla.org/en-US/docs/Web/API/Navigator/deviceMemory
  // ignore: invalid_null_aware_operator
  final size = window.navigator.deviceMemory?.toDouble();
  final memoryByteSize = size != null ? size * 1024 * 1024 * 1024 : null;
  return memoryByteSize?.toInt();
}

SentryOrientation? _getScreenOrientation(web.Window window) {
  // https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation
  final screenOrientation = window.screen.orientation;
  if (screenOrientation.type.startsWith('portrait')) {
    return SentryOrientation.portrait;
  }
  if (screenOrientation.type.startsWith('landscape')) {
    return SentryOrientation.landscape;
  }
  return null;
}
