import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith keeps unchanged', () {
    final data = _generate();

    final copy = data.copyWith();

    expect(
      MapEquality().equals(data.toJson(), copy.toJson()),
      true,
    );
  });

  test('copyWith takes new values', () {
    final data = _generate();

    final copy = data.copyWith(
      url: 'url1',
      method: 'method1',
      queryString: 'queryString1',
      cookies: 'cookies1',
      data: {'key1': 'value1'},
    );

    expect('url1', copy.url);
    expect('method1', copy.method);
    expect('queryString1', copy.queryString);
    expect('cookies1', copy.cookies);
    expect({'key1': 'value1'}, copy.data);
  });
}

SentryRequest _generate() => SentryRequest(
      url: 'url',
      method: 'method',
      queryString: 'queryString',
      cookies: 'cookies',
      data: {'key': 'value'},
    );
