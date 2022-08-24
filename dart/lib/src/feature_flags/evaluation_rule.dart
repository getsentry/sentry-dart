import 'package:meta/meta.dart';
import 'evaluation_type.dart';

@immutable
class EvaluationRule {
  final EvaluationType type;
  final double? percentage;
  final dynamic result;
  final Map<String, String> _tags;
  final Map<String, dynamic>? _payload;

  Map<String, String> get tags => Map.unmodifiable(_tags);

  Map<String, dynamic>? get payload =>
      _payload != null ? Map.unmodifiable(_payload!) : null;

  EvaluationRule(
    this.type,
    this.percentage,
    this.result,
    this._tags,
    this._payload,
  );

  factory EvaluationRule.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    final tags = json['tags'];

    return EvaluationRule(
      (json['type'] as String).toEvaluationType(),
      json['percentage'] as double?,
      json['result'],
      tags != null ? Map.from(tags) : {},
      payload != null ? Map<String, dynamic>.from(payload) : null,
    );
  }
}
