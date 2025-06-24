class SentryTemplateString {
  SentryTemplateString(this.template, this.arguments);

  final String template;
  final List<dynamic> arguments;
  static final _regex = RegExp(r'%(?:%|s)');

  String format() {
    assert(arguments.isNotEmpty,
        'No arguments provided for template with placeholders.');

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

    assert(foundPlaceholders, 'No placeholders provided in template.');

    return string;
  }

  @override
  String toString() {
    return format();
  }
}
