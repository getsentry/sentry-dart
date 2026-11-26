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

  /// Builds a document-start script that propagates the current trace to
  /// [allowedHosts] and their subdomains.
  ///
  /// Use only hosts whose page scripts you trust. Supply internationalized
  /// names in ASCII (punycode) form. A host with an explicit port matches only
  /// that port, otherwise the default HTTPS port is used.
  ///
  /// A server-rendered `sentry-trace` meta tag placed before browser SDK
  /// initialization takes precedence over the Flutter trace and its baggage.
  ///
  /// Returns null when Sentry is disabled or no valid hosts were supplied.
  /// The script is a snapshot: build and install it again to propagate a
  /// different trace.
  static SentryWebViewScript? build({required List<String> allowedHosts}) {
    final hub = Sentry.currentHub;
    if (!hub.isEnabled) return null;

    try {
      hub.options.sdk.addIntegration('WebViewTracePropagation');
      final rules = <String>{
        for (final host in allowedHosts) ...?_originRules(host),
      };
      if (rules.isEmpty) {
        internalLogger.warning(
          'WebView trace propagation requires a valid host.',
        );
        return null;
      }

      final (trace, baggage) = _currentTrace(hub);
      final source = buildWebViewScriptSource(
        allowedOriginRules: rules,
        sentryTrace: trace.value,
        baggage: _pageBaggageHeader(baggage),
      );
      return SentryWebViewScript._(source, rules);
    } catch (error, stackTrace) {
      internalLogger.warning(
        'Could not build the WebView trace propagation script.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}

/// Returns the active span's trace, falling back to the scope's propagation
/// context when no span is active.
(SentryTraceHeader, SentryBaggage?) _currentTrace(Hub hub) {
  final span = hub.options.spanFactory.getSpan(hub);
  if (span != null) {
    final header = span.toBaggageHeader();
    return (
      span.toSentryTrace(),
      header == null ? null : SentryBaggage.fromHeader(header.value),
    );
  }

  final context = hub.scope.propagationContext;
  final trace = context.toSentryTrace();
  final cached =
      context.baggage ??
      (SentryBaggage({})..setValuesFromScope(hub.scope, hub.options));
  // Store the sample rand so later snapshots of this trace agree with it.
  final sampleRand = context.sampleRand ??= Random().nextDouble();
  final baggage = SentryBaggage(Map.of(cached.keyValues))
    ..setSampleRand(sampleRand.toString());
  if (context.sampled case final sampled?) {
    baggage.setSampled(sampled.toString());
  }
  return (trace, baggage);
}

/// Returns the [baggage] header restricted to [_pageBaggageKeys], or null when
/// nothing is left.
String? _pageBaggageHeader(SentryBaggage? baggage) {
  if (baggage == null) return null;
  final header = SentryBaggage({
    for (final MapEntry(:key, :value) in baggage.keyValues.entries)
      if (_pageBaggageKeys.contains(key)) key: value,
  }).toHeaderString();
  return header.isEmpty ? null : header;
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
final _invalidAuthorityChar = RegExp(r'[^a-z0-9.:\[\]-]');
final _digits = RegExp(r'^[0-9]+$');
final _label = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
final _numericLabel = RegExp(r'^(?:[0-9]+|0x[0-9a-f]*)$');

/// Returns the HTTPS origin rules for [input], or null when it is not a
/// usable host.
List<String>? _originRules(String input) {
  final authority = _normalizeAuthority(input);
  if (authority == null) return null;
  if (_splitPort(authority) case (final hostPart, final portSuffix)) {
    final host = _parseHost(hostPart);
    if (host == null) return null;
    return [
      'https://${host.name}$portSuffix',
      if (!host.isIp) 'https://*.${host.name}$portSuffix',
    ];
  }
  return null;
}

/// Strips the scheme, path and leading `*.` from [input] and lowercases it.
String? _normalizeAuthority(String input) {
  var authority = input.trim().replaceFirst(_scheme, '');
  final end = authority.indexOf(_endOfAuthority);
  if (end >= 0) authority = authority.substring(0, end);
  if (authority.codeUnits.any((c) => c > 0x7f)) return null;
  authority = authority.toLowerCase();
  if (authority.startsWith('*.')) authority = authority.substring(2);
  if (authority.isEmpty || authority.contains(_invalidAuthorityChar)) {
    return null;
  }
  // Bracket a bare IPv6 address so its last group is not read as a port.
  if (!authority.startsWith('[') && ':'.allMatches(authority).length > 1) {
    authority = '[$authority]';
  }
  return authority;
}

/// Splits [authority] into its host and port suffix. The suffix is empty for
/// the default HTTPS port. Returns null for an invalid port.
(String, String)? _splitPort(String authority) {
  final colon = authority.lastIndexOf(':');
  if (colon <= authority.lastIndexOf(']')) return (authority, '');
  final digits = authority.substring(colon + 1);
  final port = _digits.hasMatch(digits) ? int.tryParse(digits) : null;
  if (port == null || port < 1 || port > 65535) return null;
  return (authority.substring(0, colon), port == 443 ? '' : ':$port');
}

/// Returns [hostPart] in the form browsers report it, or null when it is not
/// a valid DNS name or canonical IP address.
({String name, bool isIp})? _parseHost(String hostPart) {
  final host = Uri.tryParse('https://$hostPart')?.host;
  if (host == null || host.isEmpty) return null;
  if (host.contains(':')) return (name: '[$host]', isIp: true);

  final name = host.endsWith('.') ? host.substring(0, host.length - 1) : host;
  final labels = name.split('.');
  if (name.length > 253 || !labels.every(_label.hasMatch)) return null;
  // Browsers also interpret abbreviated, octal and hex numeric hosts as IPs.
  // Accept only canonical dotted decimal so an entry cannot change address.
  if (_numericLabel.hasMatch(labels.last)) {
    return _isCanonicalIpv4(labels) ? (name: name, isIp: true) : null;
  }
  return (name: name, isIp: false);
}

bool _isCanonicalIpv4(List<String> labels) =>
    labels.length == 4 &&
    labels.every((label) {
      final octet = int.tryParse(label);
      return octet != null && octet <= 255 && label == '$octet';
    });
