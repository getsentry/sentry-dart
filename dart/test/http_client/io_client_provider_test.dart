@TestOn('vm')
library dart_test;

import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/io_client_provider.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('getClient', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('http proxy should call findProxyResult', () async {
      fixture.options.proxy = SentryProxy(
        type: SentryProxyType.http,
        host: 'localhost',
        port: 8080,
      );

      final sut = fixture.getSut();
      sut.getClient(fixture.options);

      expect(fixture.mockHttpClient.findProxyResult,
          equals(fixture.options.proxy?.toPacString()));
    });

    test('direct proxy should call findProxyResult', () async {
      fixture.options.proxy = SentryProxy(type: SentryProxyType.direct);

      final sut = fixture.getSut();
      sut.getClient(fixture.options);

      expect(fixture.mockHttpClient.findProxyResult,
          equals(fixture.options.proxy?.toPacString()));
    });

    test('socks proxy should not call findProxyResult', () async {
      fixture.options.proxy = SentryProxy(
          type: SentryProxyType.socks, host: 'localhost', port: 8080);

      final sut = fixture.getSut();
      sut.getClient(fixture.options);

      expect(fixture.mockHttpClient.findProxyResult, isNull);
    });

    test('authenticated proxy http should call addProxyCredentials', () async {
      fixture.options.proxy = SentryProxy(
        type: SentryProxyType.http,
        host: 'localhost',
        port: 8080,
        user: 'admin',
        pass: '0000',
      );

      final sut = fixture.getSut();

      sut.getClient(fixture.options);

      expect(fixture.mockHttpClient.addProxyCredentialsHost,
          fixture.options.proxy?.host);
      expect(fixture.mockHttpClient.addProxyCredentialsPort,
          fixture.options.proxy?.port);
      expect(fixture.mockHttpClient.addProxyCredentialsRealm, '');
      expect(fixture.mockUser, fixture.options.proxy?.user);
      expect(fixture.mockPass, fixture.options.proxy?.pass);
      expect(fixture.mockHttpClient.addProxyCredentialsBasic, isNotNull);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  final mockHttpClient = MockHttpClient();

  String? mockUser;
  String? mockPass;

  IoClientProvider getSut() {
    return IoClientProvider(
      () {
        return mockHttpClient;
      },
      (user, pass) {
        mockUser = user;
        mockPass = pass;
        return HttpClientBasicCredentials(user, pass);
      },
    );
  }
}

class MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = false;

  @override
  Duration? connectionTimeout;

  @override
  Duration idleTimeout = Duration(seconds: 1);

  @override
  int? maxConnectionsPerHost;

  @override
  String? userAgent;

  @override
  void addCredentials(
      Uri url, String realm, HttpClientCredentials credentials) {
    // TODO: implement addCredentials
  }

  String? addProxyCredentialsHost;
  int? addProxyCredentialsPort;
  String? addProxyCredentialsRealm;
  HttpClientBasicCredentials? addProxyCredentialsBasic;

  @override
  void addProxyCredentials(
      String host, int port, String realm, HttpClientCredentials credentials) {
    addProxyCredentialsHost = host;
    addProxyCredentialsPort = port;
    addProxyCredentialsRealm = realm;
    if (credentials is HttpClientBasicCredentials) {
      addProxyCredentialsBasic = credentials;
    }
  }

  @override
  set authenticate(
      Future<bool> Function(Uri url, String scheme, String? realm)? f) {
    // TODO: implement authenticate
  }

  @override
  set authenticateProxy(
      Future<bool> Function(
              String host, int port, String scheme, String? realm)?
          f) {
    // TODO: implement authenticateProxy
  }

  @override
  set badCertificateCallback(
      bool Function(X509Certificate cert, String host, int port)? callback) {
    // TODO: implement badCertificateCallback
  }

  @override
  void close({bool force = false}) {
    // TODO: implement close
  }

  @override
  set connectionFactory(
      Future<ConnectionTask<Socket>> Function(
              Uri url, String? proxyHost, int? proxyPort)?
          f) {
    // TODO: implement connectionFactory
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) {
    // TODO: implement deleteUrl
    throw UnimplementedError();
  }

  String? findProxyResult;

  @override
  set findProxy(String Function(Uri url)? f) {
    findProxyResult = f!(Uri(scheme: "http", host: "localhost", port: 8080));
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    // TODO: implement getUrl
    throw UnimplementedError();
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) {
    // TODO: implement head
    throw UnimplementedError();
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) {
    // TODO: implement headUrl
    throw UnimplementedError();
  }

  @override
  set keyLog(Function(String line)? callback) {
    // TODO: implement keyLog
  }

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    // TODO: implement open
    throw UnimplementedError();
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    // TODO: implement openUrl
    throw UnimplementedError();
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) {
    // TODO: implement patch
    throw UnimplementedError();
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) {
    // TODO: implement patchUrl
    throw UnimplementedError();
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) {
    // TODO: implement post
    throw UnimplementedError();
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    // TODO: implement postUrl
    throw UnimplementedError();
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) {
    // TODO: implement put
    throw UnimplementedError();
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) {
    // TODO: implement putUrl
    throw UnimplementedError();
  }
}
