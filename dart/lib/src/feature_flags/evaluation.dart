class Evaluation {
  final String type;
  final double? percentage;
  final bool result;
  final Map<String, dynamic> _tags;

  Map<String, dynamic> get tags => Map.unmodifiable(_tags);

  Evaluation(this.type, this.percentage, this.result, this._tags);
}
