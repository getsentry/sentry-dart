enum EvaluationType {
  match,
  rollout,
  none,
}

extension EvaluationTypeEx on String {
  EvaluationType toEvaluationType() {
    switch (this) {
      case 'match':
        return EvaluationType.match;
      case 'rollout':
        return EvaluationType.rollout;
      default:
        return EvaluationType.none;
    }
  }
}
