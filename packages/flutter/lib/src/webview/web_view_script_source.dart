import 'dart:convert';

String buildWebViewScriptSource({
  required Set<String> allowedOriginRules,
  required String sentryTrace,
  required String? baggage,
}) =>
    '''
/* sentry-flutter-webview-trace */
(function () {
  try {
    if (window.top !== window || window.location.protocol !== 'https:') return;
    const allowed = ${_jsLiteral(allowedOriginRules.toList())};
    const location = window.location;
    const matches = allowed.some(function (rule) {
      if (rule.startsWith('https://*.')) {
        return location.host.endsWith(rule.slice('https://*'.length));
      }
      // Canonicalize IPv6 spellings to the compressed form used by the page.
      if (rule.startsWith('https://[')) return new URL(rule).origin === location.origin;
      return rule === location.origin;
    });
    if (!matches || document.querySelector('meta[name="sentry-trace"]')) return;
    const head = document.head || document.documentElement;
    if (!head) return;
    function write(name, value) {
      if (!value) return;
      const meta = document.createElement('meta');
      meta.setAttribute('name', name);
      meta.setAttribute('content', value);
      head.appendChild(meta);
    }
    write('sentry-trace', ${_jsLiteral(sentryTrace)});
    write('baggage', ${_jsLiteral(baggage)});
  } catch (_) {}
})();
true;
''';

String _jsLiteral(Object? value) => jsonEncode(value)
    .replaceAll('<', r'\u003c')
    .replaceAll('\u2028', r'\u2028')
    .replaceAll('\u2029', r'\u2029');
