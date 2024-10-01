import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

@internal
class SentryMaskingConfig {
  @visibleForTesting
  final List<SentryMaskingRule> rules;

  final int length;

  SentryMaskingConfig(List<SentryMaskingRule> rules)
      // Note: fixed-size list has performance benefits over growable list.
      : rules = List.of(rules, growable: false),
        length = rules.length;

  bool shouldMask<T extends Widget>(Element element, T widget) {
    for (int i = 0; i < length; i++) {
      if (rules[i].appliesTo(widget)) {
        switch (rules[i].shouldMask(element, widget)) {
          case MaskingDecision.mask:
            return true;
          case MaskingDecision.unmask:
            return false;
          case MaskingDecision.continueProcessing:
          // Continue to the next matching rule.
        }
      }
    }
    return false;
  }
}

enum MaskingDecision { mask, unmask, continueProcessing }

@internal
abstract class SentryMaskingRule<T extends Widget> {
  bool appliesTo(Widget widget) => widget is T;
  MaskingDecision shouldMask(Element element, T widget);

  const SentryMaskingRule();
}

@internal
class SentryMaskingCustomRule<T extends Widget> extends SentryMaskingRule<T> {
  final MaskingDecision Function(Element element, T widget) callback;

  const SentryMaskingCustomRule(this.callback);

  @override
  MaskingDecision shouldMask(Element element, T widget) =>
      callback(element, widget);

  @override
  String toString() => '$SentryMaskingCustomRule<$T>($callback)';
}

@internal
class SentryMaskingConstantRule<T extends Widget> extends SentryMaskingRule<T> {
  final MaskingDecision _value;
  const SentryMaskingConstantRule(this._value);

  @override
  MaskingDecision shouldMask(Element element, T widget) {
    // This rule only makes sense with true/false. Continue won't do anything.
    assert(_value == MaskingDecision.mask || _value == MaskingDecision.unmask);
    return _value;
  }

  @override
  String toString() =>
      '$SentryMaskingConstantRule<$T>(${_value == MaskingDecision.mask ? 'mask' : 'unmask'})';
}
