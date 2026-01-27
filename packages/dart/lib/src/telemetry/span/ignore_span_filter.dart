import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../protocol/sentry_attribute.dart';

/// A filter that determines which spans should be ignored and not sent to Sentry.
///
/// Used with [SentryOptions.ignoreSpans] to filter out spans.
///
/// Note: The filter is applied at span start time, so it can only filter by name and any initial attributes.
///
/// Example:
/// ```dart
/// Sentry.init((options) {
///   options.ignoreSpans = [
///     // Ignore spans by name
///     IgnoreSpanFilter.name(NameMatcher.contains('health')),
///     IgnoreSpanFilter.name(NameMatcher.regexp(RegExp(r'^GET /api/\d+$'))),
///
///     // Ignore spans by name and attributes (simple exact matching)
///     IgnoreSpanFilter.where(
///       name: NameMatcher.contains('/healthz'),
///       attributes: {
///         'http.method': 'GET',
///         'http.status_code': 200,
///       },
///     ),
///
///     // Ignore spans by attributes only
///     IgnoreSpanFilter.where(
///       attributes: {'http.method': 'GET'},
///     ),
///
///     // Advanced: use AttrMatcher for contains/regexp matching
///     IgnoreSpanFilter.where(
///       attributes: {'http.url': AttrMatcher.contains('/api/')},
///     ),
///   ];
/// });
/// ```
@immutable
sealed class IgnoreSpanFilter {
  const IgnoreSpanFilter();

  /// Creates a filter that matches spans by name only.
  const factory IgnoreSpanFilter.name(NameMatcher matcher) = IgnoreSpanByName;

  /// Creates a filter that matches spans by name and/or attributes.
  ///
  /// At least one of [name] or [attributes] must be provided.
  ///
  /// Attribute values can be:
  /// - Raw values (String, int, bool, etc.) for exact matching
  /// - [AttrMatcher] for advanced matching (contains, regexp)
  factory IgnoreSpanFilter.where({
    NameMatcher? name,
    Map<String, Object>? attributes,
  }) {
    if (name == null && (attributes == null || attributes.isEmpty)) {
      throw ArgumentError(
          'At least one of name or attributes must be provided');
    }
    return IgnoreSpanByWhere._(name, attributes ?? const {});
  }
}

/// A filter that matches spans by name only.
final class IgnoreSpanByName extends IgnoreSpanFilter {
  /// The matcher to apply to the span name.
  final NameMatcher matcher;

  const IgnoreSpanByName(this.matcher);
}

/// A filter that matches spans by name and/or attributes.
final class IgnoreSpanByWhere extends IgnoreSpanFilter {
  /// The matcher to apply to the span name, or null to match any name.
  final NameMatcher? name;

  /// The attribute matchers to apply. All must match for the filter to match.
  /// Values can be raw values (for exact matching) or [AttrMatcher] instances.
  final Map<String, Object> attributes;

  const IgnoreSpanByWhere._(this.name, this.attributes);
}

/// A matcher for span names.
@immutable
sealed class NameMatcher {
  const NameMatcher();

  /// Matches if the span name contains the given [value] as a substring.
  const factory NameMatcher.contains(String value) = NameMatcherContains;

  /// Matches if the span name matches the given [regexp] pattern.
  const factory NameMatcher.regexp(RegExp regexp) = NameMatcherRegexp;
}

/// A name matcher that checks if the span name contains a substring.
final class NameMatcherContains extends NameMatcher {
  final String value;
  const NameMatcherContains(this.value);
}

/// A name matcher that checks if the span name equals the given value.
final class NameMatcherEquals extends NameMatcher {
  final String value;
  const NameMatcherEquals(this.value);
}

/// A name matcher that checks if the span name matches a regex pattern.
final class NameMatcherRegexp extends NameMatcher {
  final RegExp regexp;
  const NameMatcherRegexp(this.regexp);
}

/// A matcher for advanced attribute matching (contains, regexp).
///
/// For simple exact matching, just use the raw value directly.
@immutable
sealed class AttrMatcher {
  const AttrMatcher();

  /// Matches if the attribute value (as a string) contains the given [value].
  const factory AttrMatcher.contains(String value) = AttrMatcherContains;

  /// Matches if the attribute value (as a string) matches the given [regexp].
  const factory AttrMatcher.regexp(RegExp regexp) = AttrMatcherRegexp;
}

/// An attribute matcher that checks if a string attribute contains a substring.
final class AttrMatcherContains extends AttrMatcher {
  final String value;
  const AttrMatcherContains(this.value);
}

/// An attribute matcher that checks if a string attribute matches a regex.
final class AttrMatcherRegexp extends AttrMatcher {
  final RegExp regexp;
  const AttrMatcherRegexp(this.regexp);
}

// --- Internal matching utilities ---

/// Checks if the given span should be ignored based on the provided filters.
@internal
bool isSpanIgnored(
  String spanName,
  Map<String, SentryAttribute> attributes,
  List<IgnoreSpanFilter> filters,
) {
  for (final filter in filters) {
    if (_matchesFilter(spanName, attributes, filter)) {
      return true;
    }
  }
  return false;
}

bool _matchesFilter(
  String spanName,
  Map<String, SentryAttribute> attributes,
  IgnoreSpanFilter filter,
) {
  switch (filter) {
    case IgnoreSpanByName(:final matcher):
      return _matchesName(spanName, matcher);
    case IgnoreSpanByWhere(:final name, attributes: final attrMatchers):
      if (name != null && !_matchesName(spanName, name)) {
        return false;
      }
      return _matchesAttributes(attributes, attrMatchers);
  }
}

bool _matchesName(String spanName, NameMatcher matcher) {
  switch (matcher) {
    case NameMatcherContains(:final value):
      return spanName.contains(value);
    case NameMatcherRegexp(:final regexp):
      return regexp.hasMatch(spanName);
  }
}

bool _matchesAttributes(
  Map<String, SentryAttribute> attributes,
  Map<String, Object> matchers,
) {
  for (final entry in matchers.entries) {
    final attribute = attributes[entry.key];
    if (attribute == null) {
      return false;
    }
    if (!_matchesAttribute(attribute.value, entry.value)) {
      return false;
    }
  }
  return true;
}

bool _matchesAttribute(dynamic attributeValue, Object matcher) {
  switch (matcher) {
    case AttrMatcherContains(:final value):
      return attributeValue is String && attributeValue.contains(value);
    case AttrMatcherRegexp(:final regexp):
      return attributeValue is String && regexp.hasMatch(attributeValue);
    default:
      // Raw value - exact match
      return _deepEquals(attributeValue, matcher);
  }
}

bool _deepEquals(dynamic a, dynamic b) {
  if (a is List && b is List) {
    return const ListEquality<dynamic>().equals(a, b);
  }
  return a == b;
}
