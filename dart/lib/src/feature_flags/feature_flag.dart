import 'package:meta/meta.dart';

import 'evaluation.dart';

@immutable
class FeatureFlag {
  final String name;
  final Map<String, dynamic> _tags;
  final List<Evaluation> _evaluations;

  Map<String, dynamic> get tags => Map.unmodifiable(_tags);

  List<Evaluation> get evaluations => List.unmodifiable(_evaluations);

  FeatureFlag(this.name, this._tags, this._evaluations);

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    final evaluationsList = json['evaluation'] as List<dynamic>? ?? [];
    final evaluations = evaluationsList
        .map((e) => Evaluation.fromJson(e))
        .toList(growable: false);

    return FeatureFlag(
      json['name'] as String,
      Map<String, dynamic>.from(json['tags'] as Map),
      evaluations,
    );
  }
}
