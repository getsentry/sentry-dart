import 'dart:convert';

/// Builds the document-start script that writes [sentryTrace] and [baggage]
/// meta tags on top-level pages matching [allowedOriginRules].
String buildWebViewScriptSource({
  required Set<String> allowedOriginRules,
  required String sentryTrace,
  required String? baggage,
}) =>
    // The leading marker lets the native installer find and replace Sentry's
    // script among the app's own user scripts.
    '''
/* sentry-flutter-webview-trace */
(function () {
  try {
    const location = window.location;
    if (window.top !== window || location.protocol !== 'https:') return;
    const allowed = ${_jsLiteral(allowedOriginRules.toList())};
    const matches = allowed.some((rule) => {
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
    const write = (name, value) => {
      if (!value) return null;
      const meta = document.createElement('meta');
      meta.setAttribute('name', name);
      meta.setAttribute('content', value);
      head.appendChild(meta);
      return meta;
    };
    const trace = write('sentry-trace', ${_jsLiteral(sentryTrace)});
    const baggage = write('baggage', ${_jsLiteral(baggage)});
    // At document start the HTML parser may still be about to insert server
    // metadata. Give it precedence before the page initializes the browser SDK.
    if (document.readyState === 'loading') {
      const observer = new MutationObserver((records) => {
        for (const record of records) {
          for (const node of record.addedNodes) {
            if (node.nodeName === 'META' && node.name === 'sentry-trace' && node !== trace) {
              trace.remove();
              baggage?.remove();
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

/// Encodes [value] as a JavaScript literal that cannot close a `<script>`
/// element or break a line.
String _jsLiteral(Object? value) => jsonEncode(value)
    .replaceAll('<', r'\u003c')
    .replaceAll('\u2028', r'\u2028')
    .replaceAll('\u2029', r'\u2029');
