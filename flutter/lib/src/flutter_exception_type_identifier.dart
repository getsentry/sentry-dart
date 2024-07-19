import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../sentry_flutter.dart';

class FlutterExceptionTypeIdentifier implements ExceptionTypeIdentifier {
  @override
  String? identifyType(dynamic throwable) {
    // FlutterError check should run before AssertionError check because
    // it's a subclass of AssertionError
    if (throwable is FlutterError) return 'FlutterError';
    if (throwable is PlatformException) return 'PlatformException';
    if (throwable is MissingPluginException) return 'MissingPluginException';
    if (throwable is NetworkImageLoadException) {
      return 'NetworkImageLoadException';
    }
    if (throwable is TickerCanceled) return 'TickerCanceled';
    return null;
  }
}
