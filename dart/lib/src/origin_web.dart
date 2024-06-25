// We would lose compatibility with old dart versions by adding web to pubspec.
// ignore: depend_on_referenced_packages
import 'package:web/web.dart';

/// request origin, used for browser stacktrace
String get eventOrigin => '${window.location.origin}/';
