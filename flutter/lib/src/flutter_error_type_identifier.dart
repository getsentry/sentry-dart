import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../sentry_flutter.dart';

class FlutterExceptionTypeIdentifier implements ExceptionTypeIdentifier {
  @override
  String? identifyType(dynamic throwable) {
    if (throwable is FlutterError) return 'FlutterError';
    if (throwable is PlatformException) return 'PlatformException';
    if (throwable is MissingPluginException) return 'MissingPluginException';
    if (throwable is AssertionError) return 'AssertionError';
    if (throwable is NetworkImageLoadException)
      return 'NetworkImageLoadException';
    if (throwable is TickerCanceled) return 'TickerCanceled';

    // dart:io Exceptions
    if (!kIsWeb) {
      if (throwable is FileSystemException) return 'FileSystemException';
      if (throwable is HttpException) return 'HttpException';
      if (throwable is SocketException) return 'SocketException';
      if (throwable is HandshakeException) return 'HandshakeException';
      if (throwable is CertificateException) return 'CertificateException';
      // not adding TlsException and IOException because it's too generic
    }
    return null;
  }
}

bool isSubtype<S, T>() => <S>[] is List<T>;
