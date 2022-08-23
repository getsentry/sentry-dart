import 'package:meta/meta.dart';

import 'evaluation_rule.dart';

@immutable
class FeatureFlag {
  // final Map<String, dynamic> _tags;
  final List<EvaluationRule> _evaluations;
  final String kind;

  // Map<String, dynamic> get tags => Map.unmodifiable(_tags);

  List<EvaluationRule> get evaluations => List.unmodifiable(_evaluations);

  FeatureFlag(this.kind, this._evaluations);

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    final evaluationsList = json['evaluation'] as List<dynamic>? ?? [];
    final evaluations = evaluationsList
        .map((e) => EvaluationRule.fromJson(e))
        .toList(growable: false);

    return FeatureFlag(
      kind,
      evaluations,
    );
  }
}
