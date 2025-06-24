class SentryTemplateString {
  SentryTemplateString(this.template);

  final String template;

  String format(List<dynamic> arguments) {
    assert(arguments.isNotEmpty);

    int argIndex = 0;
    return template.replaceAllMapped(RegExp(r'%(?:%|s)'), (Match m) {
      final token = m[0];
      if (token == '%%') {
        // `%%` → literal `%`
        return '%';
      }
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
  }
}
