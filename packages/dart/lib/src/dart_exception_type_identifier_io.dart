import 'dart:io';

import 'package:meta/meta.dart';

@internal
String? identifyPlatformSpecificException(dynamic throwable) {
  if (throwable is FileSystemException) return 'FileSystemException';
  if (throwable is HttpException) return 'HttpException';
  if (throwable is SocketException) return 'SocketException';
  if (throwable is HandshakeException) return 'HandshakeException';
  if (throwable is CertificateException) return 'CertificateException';
  if (throwable is TlsException) return 'TlsException';
  return null;
}
