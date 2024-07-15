import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../sentry_flutter.dart';

class FlutterErrorIdentifier implements ErrorTypeIdentifier {
  @override
  String? getTypeName(dynamic error) {
    if (error is FlutterError) return 'FlutterError';
    if (error is PlatformException) return 'PlatformException';
    if (error is MissingPluginException) return 'MissingPluginException';
    if (error is AssertionError) return 'AssertionError';
    if (error is NetworkImageLoadException) return 'NetworkImageLoadException';
    if (error is TickerCanceled) return 'TickerCanceled';
    return null;
  }
}
