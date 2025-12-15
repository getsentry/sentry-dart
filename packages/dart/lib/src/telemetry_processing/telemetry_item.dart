import 'package:meta/meta.dart';

enum TelemetryType {
  log,
  span,
  unknown,
}

abstract class TelemetryItem {
  @internal
  TelemetryType get type;

  @internal
  Map<String, dynamic> toJson();
}
