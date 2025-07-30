import 'package:meta/meta.dart';

@internal
bool isMatchingRegexPattern(String value, List<String> regexPattern,
    {bool caseSensitive = false}) {
  final combinedRegexPattern = regexPattern.join('|');
  final regExp = RegExp(combinedRegexPattern, caseSensitive: caseSensitive);
  return regExp.hasMatch(value);
}
