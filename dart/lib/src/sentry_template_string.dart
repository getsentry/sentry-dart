class SentryTemplateString {
  SentryTemplateString(this.template);

  final String template;

  String format(List<dynamic> arguments) {
    assert(arguments.isNotEmpty);

    final result = StringBuffer();
    int argIndex = 0;
    int templateIndex = 0;

    while (templateIndex < template.length) {
      if (templateIndex + 1 < template.length &&
          template[templateIndex] == '%' &&
          template[templateIndex + 1] == '%') {
        // Found %% - escape sequence, output single %
        result.write('%');
        // Skip %%
        templateIndex += 2;
      } else if (templateIndex + 1 < template.length &&
          template[templateIndex] == '%' &&
          template[templateIndex + 1] == 's') {
        // Found %s placeholder
        if (argIndex < arguments.length) {
          // Convert argument to string
          final arg = arguments[argIndex];
          result.write(_convertToString(arg));
          argIndex++;
        } else {
          // Not enough arguments, replace with empty string
          result.write('');
        }
        // Skip %s
        templateIndex += 2;
      } else {
        // Regular character, copy as is
        result.write(template[templateIndex]);
        templateIndex++;
      }
    }
    return result.toString();
  }

  String _convertToString(dynamic value) {
    if (value is String) {
      return value;
    } else {
      try {
        return value.toString();
      } catch (e) {
        // If toString() fails, return empty string
        return '';
      }
    }
  }
}
