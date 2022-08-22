import 'package:meta/meta.dart';
import 'evaluation_type.dart';

@immutable
class EvaluationRule {
  final EvaluationType type;
  final double? percentage;
  final bool? result;
  final Map<String, dynamic> _tags;

  Map<String, dynamic> get tags => Map.unmodifiable(_tags);

  EvaluationRule(this.type, this.percentage, this.result, this._tags);

  factory EvaluationRule.fromJson(Map<String, dynamic> json) {
    return EvaluationRule(
      (json['type'] as String).toEvaluationType(),
      json['percentage'] as double?,
      json['result'] as bool?,
      Map<String, dynamic>.from(json['tags'] as Map),
    );
  }
}
