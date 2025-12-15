import 'package:meta/meta.dart';

abstract class TelemetryItem {
  @internal
  Map<String, dynamic> toJson();
}
