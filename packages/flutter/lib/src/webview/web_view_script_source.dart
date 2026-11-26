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
      return meta;
    }
    const trace = write('sentry-trace', ${_jsLiteral(sentryTrace)});
    const baggage = write('baggage', ${_jsLiteral(baggage)});
    // At document start the HTML parser may still be about to insert server
    // metadata. Give it precedence before the page initializes the browser SDK.
    if (document.readyState === 'loading') {
      const observer = new MutationObserver(records => {
        for (const record of records) {
          for (const node of record.addedNodes) {
            if (node.nodeName === 'META' && node.name === 'sentry-trace' && node !== trace) {
              trace.remove();
              if (baggage) baggage.remove();
              observer.disconnect();
              return;
            }
          }
        }
      });
      observer.observe(head, { childList: true, subtree: true });
      document.addEventListener('DOMContentLoaded', () => observer.disconnect(), { once: true });
    }
  } catch (_) {}
})();
true;
''';

String _jsLiteral(Object? value) => jsonEncode(value)
    .replaceAll('<', r'\u003c')
    .replaceAll('\u2028', r'\u2028')
    .replaceAll('\u2029', r'\u2029');
