import 'package:meta/meta.dart';

@internal
class NativeFrames {
  NativeFrames(this.totalFrames, this.slowFrames, this.frozenFrames);

  int totalFrames;
  int slowFrames;
  int frozenFrames;

  factory NativeFrames.fromJson(Map<String, dynamic> json) {
    return NativeFrames(
      json['totalFrames'] as int,
      json['slowFrames'] as int,
      json['frozenFrames'] as int,
    );
  }
}
