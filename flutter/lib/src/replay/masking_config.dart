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

  SentryMaskingDecision shouldMask<T extends Widget>(
      Element element, T widget) {
    for (int i = 0; i < length; i++) {
      if (rules[i].appliesTo(widget)) {
        // We use a switch here to get lints if more values are added.
        switch (rules[i].shouldMask(element, widget)) {
          case SentryMaskingDecision.mask:
            return SentryMaskingDecision.mask;
          case SentryMaskingDecision.unmask:
            return SentryMaskingDecision.unmask;
          case SentryMaskingDecision.continueProcessing:
          // Continue to the next matching rule.
        }
      }
    }
    return SentryMaskingDecision.continueProcessing;
  }
}

@experimental
enum SentryMaskingDecision {
  /// Mask the widget and its children
  mask,

  /// Leave the widget visible, including its children (no more rules will
  /// be checked for children).
  unmask,

  /// Don't make a decision - continue checking other rules and children.
  continueProcessing
}

@internal
abstract class SentryMaskingRule<T extends Widget> {
  @pragma('vm:prefer-inline')
  bool appliesTo(Widget widget) => widget is T;
  SentryMaskingDecision shouldMask(Element element, T widget);

  const SentryMaskingRule();
}

@internal
class SentryMaskingCustomRule<T extends Widget> extends SentryMaskingRule<T> {
  final SentryMaskingDecision Function(Element element, T widget) callback;

  const SentryMaskingCustomRule(this.callback);

  @override
  SentryMaskingDecision shouldMask(Element element, T widget) =>
      callback(element, widget);

  @override
  String toString() => '$SentryMaskingCustomRule<$T>($callback)';
}

@internal
class SentryMaskingConstantRule<T extends Widget> extends SentryMaskingRule<T> {
  final SentryMaskingDecision _value;
  const SentryMaskingConstantRule(this._value);

  @override
  SentryMaskingDecision shouldMask(Element element, T widget) {
    // This rule only makes sense with true/false. Continue won't do anything.
    assert(_value == SentryMaskingDecision.mask ||
        _value == SentryMaskingDecision.unmask);
    return _value;
  }

  @override
  String toString() =>
      '$SentryMaskingConstantRule<$T>(${_value == SentryMaskingDecision.mask ? 'mask' : 'unmask'})';
}
