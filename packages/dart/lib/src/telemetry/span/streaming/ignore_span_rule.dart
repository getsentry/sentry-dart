import 'package:meta/meta.dart';

sealed class IgnoreSpanRule {
  const IgnoreSpanRule();

  factory IgnoreSpanRule.nameContains(Pattern pattern) = _NameContains;
  factory IgnoreSpanRule.nameEquals(String value) = _NameEquals;
  factory IgnoreSpanRule.nameStartsWith(Pattern pattern) = _NameStartsWith;
  factory IgnoreSpanRule.nameEndsWith(String value) = _NameEndsWith;

  @internal
  bool appliesToName(String name);
}

class _NameContains extends IgnoreSpanRule {
  final Pattern pattern;

  const _NameContains(this.pattern);

  @override
  bool appliesToName(String name) => name.contains(pattern);
}

class _NameEquals extends IgnoreSpanRule {
  final String value;

  const _NameEquals(this.value);

  @override
  bool appliesToName(String name) => name == value;
}

class _NameStartsWith extends IgnoreSpanRule {
  final Pattern pattern;

  const _NameStartsWith(this.pattern);

  @override
  bool appliesToName(String name) => name.startsWith(pattern);
}

class _NameEndsWith extends IgnoreSpanRule {
  final String value;

  const _NameEndsWith(this.value);

  @override
  bool appliesToName(String name) => name.endsWith(value);
}

// TODO(later): add support for ignoring spans based on attributes
