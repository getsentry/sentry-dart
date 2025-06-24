class SentryTemplateString {
  SentryTemplateString(this.template);

  final String template;
  static final _regex = RegExp(r'%(?:%|s)');

  String format(List<dynamic> arguments) {
    assert(arguments.isNotEmpty);

    int argIndex = 0;
    var foundPlaceholders = false;
    final string = template.replaceAllMapped(_regex, (Match m) {
      final token = m[0];
      if (token == '%%') {
        // `%%` → literal `%`
        return '%';
      }
      foundPlaceholders = true;

      // `%s` → next argument or empty if none left
      if (argIndex < arguments.length) {
        final value = arguments[argIndex++];
        try {
          return value.toString();
        } catch (e) {
          // If toString() fails, return empty string
          return '';
        }
      }
      return '';
    });

    assert(foundPlaceholders, 'No placeholder strings found in template');

    return string;
  }
}
