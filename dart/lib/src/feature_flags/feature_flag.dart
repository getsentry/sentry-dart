import 'package:meta/meta.dart';

import 'evaluation_rule.dart';

@immutable
class FeatureFlag {
  final List<EvaluationRule> _evaluations;
  final String? group;

  List<EvaluationRule> get evaluations => List.unmodifiable(_evaluations);

  FeatureFlag(this._evaluations, this.group);

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    final group = json['group'];
    final evaluationsList = json['evaluation'] as List<dynamic>? ?? [];
    final evaluations = evaluationsList
        .map((e) => EvaluationRule.fromJson(e))
        .toList(growable: false);

    return FeatureFlag(evaluations, group);
  }
}
