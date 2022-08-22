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
}
