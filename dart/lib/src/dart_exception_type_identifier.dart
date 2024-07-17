import 'dart:io';

import 'package:http/http.dart';
import 'dart:async';

import '../sentry.dart';

class DartExceptionTypeIdentifier implements ExceptionTypeIdentifier {
  @override
  String? identifyType(dynamic throwable) {
    // dart:core
    if (throwable is ArgumentError) return 'ArgumentError';
    if (throwable is AssertionError) return 'AssertionError';
    if (throwable is ConcurrentModificationError)
      return 'ConcurrentModificationError';
    if (throwable is FormatException) return 'FormatException';
    if (throwable is IndexError) return 'IndexError';
    if (throwable is NoSuchMethodError) return 'NoSuchMethodError';
    if (throwable is OutOfMemoryError) return 'OutOfMemoryError';
    if (throwable is RangeError) return 'RangeError';
    if (throwable is StackOverflowError) return 'StackOverflowError';
    if (throwable is StateError) return 'StateError';
    if (throwable is TypeError) return 'TypeError';
    if (throwable is UnimplementedError) return 'UnimplementedError';
    if (throwable is UnsupportedError) return 'UnsupportedError';
    // not adding Exception or Error because it's too generic

    // dart:async
    if (throwable is TimeoutException) return 'TimeoutException';
    if (throwable is AsyncError) return 'FutureTimeout';
    if (throwable is DeferredLoadException) return 'DeferredLoadException';
    // not adding ParallelWaitError because it's not supported in dart 2.17.0

    // dart:io
    if (throwable is FileSystemException) return 'FileSystemException';
    if (throwable is HttpException) return 'HttpException';
    if (throwable is SocketException) return 'SocketException';
    if (throwable is HandshakeException) return 'HandshakeException';
    if (throwable is CertificateException) return 'CertificateException';
    if (throwable is TlsException) return 'TlsException';
    // not adding IOException because it's too generic

    // dart http package
    if (throwable is ClientException) return 'ClientException';

    return null;
  }
}
