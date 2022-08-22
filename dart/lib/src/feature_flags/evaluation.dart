import 'package:meta/meta.dart';

@immutable
class Evaluation {
  final String type;
  final double? percentage;
  final bool? result;
  final Map<String, dynamic> _tags;

  Map<String, dynamic> get tags => Map.unmodifiable(_tags);

  Evaluation(this.type, this.percentage, this.result, this._tags);

  factory Evaluation.fromJson(Map<String, dynamic> json) {
    return Evaluation(
      json['type'] as String,
      json['percentage'] as double?,
      json['result'] as bool?,
      Map<String, dynamic>.from(json['tags'] as Map),
    );
  }
}
