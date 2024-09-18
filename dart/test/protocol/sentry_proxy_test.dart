import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final proxy = SentryProxy(
    host: 'localhost',
    port: 8080,
    type: SentryProxyType.http,
    user: 'admin',
    pass: '0000',
  );

  final proxyJson = <String, dynamic>{
    'host': 'localhost',
    'port': 8080,
    'type': 'HTTP',
    'user': 'admin',
    'pass': '0000',
  };

  group('toPacString', () {
    test('returns "DIRECT" for ProxyType.direct', () {
      SentryProxy proxy = SentryProxy(type: SentryProxyType.direct);
      expect(proxy.toPacString(), equals('DIRECT'));
    });

    test('returns "PROXY host:port" for ProxyType.http with host and port', () {
      SentryProxy proxy = SentryProxy(
          type: SentryProxyType.http, host: 'localhost', port: 8080);
      expect(proxy.toPacString(), equals('PROXY localhost:8080'));
    });

    test('returns "PROXY host" for ProxyType.http with host only', () {
      SentryProxy proxy =
          SentryProxy(type: SentryProxyType.http, host: 'localhost');
      expect(proxy.toPacString(), equals('PROXY localhost'));
    });

    test('returns "SOCKS host:port" for ProxyType.socks with host and port',
        () {
      SentryProxy proxy = SentryProxy(
          type: SentryProxyType.socks, host: 'localhost', port: 8080);
      expect(proxy.toPacString(), equals('SOCKS localhost:8080'));
    });

    test('returns "SOCKS host" for ProxyType.socks with host only', () {
      SentryProxy proxy =
          SentryProxy(type: SentryProxyType.socks, host: 'localhost');
      expect(proxy.toPacString(), equals('SOCKS localhost'));
    });

    test('falls back to "DIRECT" if http is missing host', () {
      SentryProxy proxy = SentryProxy(type: SentryProxyType.http);
      expect(proxy.toPacString(), equals('DIRECT'));
    });

    test('falls back to "DIRECT" if socks is missing host', () {
      SentryProxy proxy = SentryProxy(type: SentryProxyType.socks);
      expect(proxy.toPacString(), equals('DIRECT'));
    });
  });

  group('json', () {
    test('toJson', () {
      final json = proxy.toJson();

      expect(
        DeepCollectionEquality().equals(proxyJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = proxy;

      final copy = data.copyWith();

      expect(data.toJson(), copy.toJson());
    });

    test('copyWith takes new values', () {
      final data = proxy;

      final copy = data.copyWith(
        host: 'localhost-2',
        port: 9001,
        type: SentryProxyType.socks,
        user: 'user',
        pass: '1234',
      );

      expect('localhost-2', copy.host);
      expect(9001, copy.port);
      expect(SentryProxyType.socks, copy.type);
      expect('user', copy.user);
      expect('1234', copy.pass);
    });
  });
}
