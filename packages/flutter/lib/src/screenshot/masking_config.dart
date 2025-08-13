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

  const SentryMaskingRule({required this.name, required this.description});

  final String name;

  final String description;

  String get _ruleType;

  @override
  String toString() => '$_ruleType<$name>($description)';
}

@internal
class SentryMaskingCustomRule<T extends Widget> extends SentryMaskingRule<T> {
  @override
  String get _ruleType => 'SentryMaskingCustomRule';

  final SentryMaskingDecision Function(Element element, T widget) callback;

  const SentryMaskingCustomRule({
    required this.callback,
    required super.name,
    required super.description,
  });

  @override
  SentryMaskingDecision shouldMask(Element element, T widget) =>
      callback(element, widget);
}

@internal
class SentryMaskingConstantRule<T extends Widget> extends SentryMaskingRule<T> {
  @override
  String get _ruleType => 'SentryMaskingConstantRule';

  final SentryMaskingDecision _value;

  const SentryMaskingConstantRule(
      {required bool mask, required super.name, String? description})
      : _value =
            mask ? SentryMaskingDecision.mask : SentryMaskingDecision.unmask,
        super(description: description ?? (mask ? 'mask' : 'unmask'));

  @override
  SentryMaskingDecision shouldMask(Element element, T widget) => _value;
}
