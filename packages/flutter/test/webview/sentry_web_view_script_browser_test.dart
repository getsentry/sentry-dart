// ignore_for_file: invalid_use_of_internal_member

@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/webview/web_view_script_source.dart';

import '../mocks.dart';

@JS('Function')
external JSFunction _pageHarness(JSString body);

// Chrome supplies the URL parser and DOM. Each invocation gets a fresh document
// and a window with the requested location and frame relationship.
Map<String, dynamic> runPage(
  String source, {
  String url = 'https://app.example.com',
  bool iframe = false,
  bool existingTrace = false,
}) {
  final result =
      _pageHarness(
            '''
    const doc = document.implementation.createHTMLDocument();
    const page = {location: new URL(${jsonEncode(url)})};
    page.top = ${iframe ? '{}' : 'page'};
    if ($existingTrace) {
      const meta = doc.createElement('meta');
      meta.name = 'sentry-trace';
      meta.content = 'server-trace';
      doc.head.appendChild(meta);
    }
    (function(window, document) { $source })(page, doc);
    return JSON.stringify(Object.fromEntries(
      Array.from(doc.querySelectorAll('meta[name]'), m => [m.name, m.content])));
  '''
                .toJS,
          ).callAsFunction()
          as JSString;
  return jsonDecode(result.toDart) as Map<String, dynamic>;
}

void main() {
  group('WebView document-start script', () {
    late SentryFlutterOptions options;
    setUp(() async {
      options = defaultTestOptions();
      await Sentry.init((o) {
        o.release = 'release-1';
        o.environment = 'test';
      }, options: options);
    });
    tearDown(Sentry.close);

    String build() => SentryWebViewScript.build(
      allowedHosts: ['example.com', 'localhost:8443'],
    )!.source;

    test('writes only trace and sampling metadata on a trusted page', () async {
      final hub = Sentry.currentHub;
      await hub.scope.setUser(SentryUser(id: 'private-id'));
      final context = hub.scope.propagationContext;
      for (final rotate in [false, false, true]) {
        if (rotate) hub.generateNewTrace();
        final tags = runPage(build());
        expect(tags.keys, unorderedEquals(['sentry-trace', 'baggage']));
        expect(tags['sentry-trace'], startsWith('${context.traceId}-'));
        expect(SentryBaggage.fromHeader(tags['baggage'] as String).keyValues, {
          'sentry-trace_id': context.traceId.toString(),
          'sentry-public_key': options.parsedDsn.publicKey,
          'sentry-release': 'release-1',
          'sentry-environment': 'test',
          if (options.effectiveOrgId != null)
            'sentry-org_id': options.effectiveOrgId,
          'sentry-sample_rand': context.sampleRand.toString(),
        });
        expect(runPage(build())['baggage'], tags['baggage']);
      }
    });

    test('restricts propagation to the configured HTTPS origins', () {
      final source = build();
      for (final url in [
        'https://example.com',
        'https://A.B.Example.Com',
        'https://localhost:8443',
      ]) {
        expect(
          runPage(source, url: url),
          contains('sentry-trace'),
          reason: url,
        );
      }
      for (final url in [
        'https://untrusted.test',
        'https://otherexample.com',
        'http://example.com',
        'https://example.com:444',
        'https://localhost',
        'about:blank',
      ]) {
        expect(runPage(source, url: url), isEmpty, reason: url);
      }
    });

    test('canonicalizes IPv6 origins and keeps their port', () {
      final script = SentryWebViewScript.build(
        allowedHosts: ['[0:0:0:0:0:0:0:1]:8443'],
      )!;
      expect(
        runPage(script.source, url: 'https://[::1]:8443'),
        contains('sentry-trace'),
      );
      expect(runPage(script.source, url: 'https://[::1]'), isEmpty);
    });

    test('skips frames and leaves existing trace metadata intact', () {
      final source = build();
      expect(runPage(source, iframe: true), isEmpty);
      expect(runPage(source, existingTrace: true), {
        'sentry-trace': 'server-trace',
      });
    });

    for (final hasServerBaggage in [false, true]) {
      test(
        'prefers parser-inserted server trace (baggage: $hasServerBaggage)',
        () async {
          // Chrome parses srcdoc in a frame. Give the propagation script the
          // location and frame relationship of a trusted top-level WebView.
          final html =
              '''<html><head><script>
          const page = {location: new URL('https://app.example.com')};
          page.top = page;
          (function(window) { ${build()} })(page);
        </script>
        <meta name="sentry-trace" content="server-trace">
        ${hasServerBaggage ? '<meta name="baggage" content="server-baggage">' : ''}
        <script>
          window.atInit = ['sentry-trace', 'baggage'].map(
            name => document.querySelector('meta[name="' + name + '"]')?.content ?? null);
        </script></head></html>''';
          final result =
              _pageHarness(
                    '''
          const frame = document.createElement('iframe');
          frame.srcdoc = ${jsonEncode(html)};
          return new Promise(resolve => {
            frame.onload = () => {
              resolve(JSON.stringify(frame.contentWindow.atInit));
              frame.remove();
            };
            document.body.appendChild(frame);
          });
        '''
                        .toJS,
                  ).callAsFunction()
                  as JSPromise<JSString>;
          expect(jsonDecode((await result.toDart).toDart), [
            'server-trace',
            hasServerBaggage ? 'server-baggage' : null,
          ]);
        },
      );
    }

    test('an unresolvable hostname leaves other allowed origins usable', () {
      final script = SentryWebViewScript.build(
        allowedHosts: ['xn--a.example', 'example.com'],
      )!;
      expect(runPage(script.source), contains('sentry-trace'));
    });

    test('skips empty baggage', () {
      final source = buildWebViewScriptSource(
        allowedOriginRules: {'https://app.example.com'},
        sentryTrace: 'trace',
        baggage: null,
      );
      expect(runPage(source), {'sentry-trace': 'trace'});
    });

    test('round-trips arbitrary header text as inert meta content', () {
      final random = Random(4218);
      const alphabet = [
        'a',
        '"',
        "'",
        '<',
        '>',
        '\\',
        '\n',
        '\u2028',
        '\u2029',
        '😀',
        '&',
      ];
      for (var i = 0; i < 64; i++) {
        final value = List.generate(
          24,
          (_) => alphabet[random.nextInt(alphabet.length)],
        ).join();
        final source = buildWebViewScriptSource(
          allowedOriginRules: {
            'https://unused.example/$value',
            'https://app.example.com',
          },
          sentryTrace: value,
          baggage: value,
        );
        expect(source, isNot(contains('<')));
        expect(source, isNot(contains('\u2028')));
        expect(source, isNot(contains('\u2029')));
        expect(runPage(source), {'sentry-trace': value, 'baggage': value});
      }
    });
  });
}
