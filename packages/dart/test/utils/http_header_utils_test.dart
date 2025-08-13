import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('get content length lower case', () {
    final headers = {
      'content-length': ['12']
    };
    expect(HttpHeaderUtils.getContentLength(headers), 12);
  });

  test('get content length camel case', () {
    final headers = {
      'Content-Length': ['12']
    };
    expect(HttpHeaderUtils.getContentLength(headers), 12);
  });
}
