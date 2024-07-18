import 'dart:html';
import 'package:meta/meta.dart';

@internal
String? identifyPlatformSpecificException(dynamic throwable) {
  if (throwable is NullWindowException) return 'NullWindowException';
  return null;
}
