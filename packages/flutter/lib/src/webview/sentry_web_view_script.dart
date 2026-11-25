// ignore_for_file: invalid_use_of_internal_member

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import '../utils/internal_logger.dart';
import 'web_view_script_source.dart';

/// A snapshot of the current Dart trace for a WebView running the browser SDK.
@immutable
final class SentryWebViewScript {
  SentryWebViewScript._(this.source, Set<String> rules)
    : allowedOriginRules = Set.unmodifiable(rules);

  /// JavaScript to install at document start, before the page initializes Sentry.
  final String source;

  /// HTTPS origin rules to pass to the WebView when registering [source].
  final Set<String> allowedOriginRules;

  /// Builds a document-start script for [allowedHosts] and their subdomains.
  /// Use only hosts whose page scripts you trust. Supply internationalized
  /// names in ASCII (punycode) form. An explicit port limits the origin to
  /// that port, otherwise the default HTTPS port is used.
  ///
  /// Returns null when Sentry is disabled or no valid hosts were supplied.
  /// Build and replace the script again to propagate a different trace.
  static SentryWebViewScript? build({required List<String> allowedHosts}) {
    final hub = Sentry.currentHub;
    if (!hub.isEnabled) return null;

    try {
      hub.options.sdk.addIntegration('WebViewTracePropagation');
      final rules = <String>{};
      for (final host in allowedHosts) {
        _addOriginRules(host, rules);
      }
      if (rules.isEmpty) {
        internalLogger.warning(
          'WebView trace propagation requires a valid host.',
        );
        return null;
      }

      final span = hub.options.spanFactory.getSpan(hub);
      final context = hub.scope.propagationContext;
      final trace = span?.toSentryTrace() ?? context.toSentryTrace();
      final SentryBaggage? baggage;
      if (span == null) {
        final cached =
            context.baggage ??
            (SentryBaggage({})..setValuesFromScope(hub.scope, hub.options));
        final sampleRand = context.sampleRand ??= Random().nextDouble();
        baggage = SentryBaggage(Map.of(cached.keyValues))
          ..setSampleRand(sampleRand.toString());
      } else {
        final header = span.toBaggageHeader();
        baggage = header == null
            ? null
            : SentryBaggage.fromHeader(header.value);
      }

      final filtered = SentryBaggage({
        for (final entry
            in baggage?.keyValues.entries ?? const <MapEntry<String, String>>[])
          if (_pageBaggageKeys.contains(entry.key)) entry.key: entry.value,
      }).toHeaderString();
      final script = buildWebViewScriptSource(
        allowedOriginRules: rules,
        sentryTrace: trace.value,
        baggage: filtered.isEmpty ? null : filtered,
      );
      return SentryWebViewScript._(script, rules);
    } catch (_) {
      internalLogger.warning(
        'Could not build the WebView trace propagation script.',
      );
      return null;
    }
  }
}

// Only expose fields that describe the trace and its sampling context.
const _pageBaggageKeys = {
  'sentry-trace_id',
  'sentry-public_key',
  'sentry-release',
  'sentry-environment',
  'sentry-org_id',
  'sentry-sampled',
  'sentry-sample_rate',
  'sentry-sample_rand',
};

final _scheme = RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false);
final _endOfAuthority = RegExp(r'[/#?]');
final _label = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
final _numericLabel = RegExp(r'^(?:[0-9]+|0x[0-9a-f]*)$');

void _addOriginRules(String input, Set<String> rules) {
  var authority = input.trim().replaceFirst(_scheme, '');
  final end = authority.indexOf(_endOfAuthority);
  if (end >= 0) authority = authority.substring(0, end);
  if (authority.codeUnits.any((c) => c > 0x7f)) return;
  authority = authority.toLowerCase();
  if (authority.startsWith('*.')) authority = authority.substring(2);
  if (authority.isEmpty || authority.contains(RegExp(r'[^a-z0-9.:\[\]-]'))) {
    return;
  }
  if (!authority.startsWith('[') && ':'.allMatches(authority).length > 1) {
    authority = '[$authority]';
  }
  var portSuffix = '';
  final colon = authority.lastIndexOf(':');
  if (colon > authority.lastIndexOf(']')) {
    final number = authority.substring(colon + 1);
    if (!RegExp(r'^[0-9]+$').hasMatch(number)) return;
    final port = int.tryParse(number);
    if (port == null || port < 1 || port > 65535) return;
    if (port != 443) portSuffix = ':$port';
    authority = authority.substring(0, colon);
  }
  final uri = Uri.tryParse('https://$authority');
  if (uri == null || uri.host.isEmpty) return;
  var host = uri.host;
  final ipv6 = host.contains(':');
  var isIp = ipv6;
  if (ipv6) {
    host = '[$host]';
  } else {
    if (host.endsWith('.')) host = host.substring(0, host.length - 1);
    final labels = host.split('.');
    if (host.length > 253 || !labels.every(_label.hasMatch)) return;
    // Browsers also interpret abbreviated, octal and hex numeric hosts as IPs.
    // Accept only canonical dotted decimal so an entry cannot change address.
    if (_numericLabel.hasMatch(labels.last)) {
      if (labels.length != 4 ||
          !labels.every((part) {
            final octet = int.tryParse(part);
            return octet != null &&
                octet >= 0 &&
                octet <= 255 &&
                part == octet.toString();
          })) {
        return;
      }
      isIp = true;
    }
  }
  rules.add('https://$host$portSuffix');
  if (!isIp) rules.add('https://*.$host$portSuffix');
}
