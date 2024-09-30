import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

@internal
class SentryMaskingConfig {
  final List<SentryMaskingRule> rules;
  final int length;

  SentryMaskingConfig(List<SentryMaskingRule> rules)
      // Note: fixed-size list has performance benefits over growable list.
      : rules = List.of(rules, growable: false),
        length = rules.length;

  bool shouldMask<T extends Widget>(Element element, T widget) {
    for (int i = 0; i < length; i++) {
      if (rules[i].appliesTo(widget) && rules[i].shouldMask(element, widget)) {
        return true;
      }
    }
    return false;
  }
}

@internal
abstract class SentryMaskingRule<T extends Widget> {
  bool appliesTo(Widget widget) => widget is T;
  bool shouldMask(Element element, T widget);

  const SentryMaskingRule();
}

@internal
class SentryMaskingCustomRule<T extends Widget> extends SentryMaskingRule<T> {
  final bool Function(Element element, T widget) callback;

  const SentryMaskingCustomRule(this.callback);

  @override
  bool shouldMask(Element element, T widget) => callback(element, widget);
}

@internal
class SentryMaskingConstantRule<T extends Widget> extends SentryMaskingRule<T> {
  final bool _value;
  const SentryMaskingConstantRule(this._value);

  @override
  bool shouldMask(Element element, T widget) => _value;
}
