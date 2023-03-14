import 'package:sentry/src/utils/http_sanitizer.dart';
import 'package:test/test.dart';

void main() {
  test('returns null for null', () {
    expect(HttpSanitizer.sanitizeUrl(null), isNull);
  });

  test('strips user info with user and password from http', () {
    final sanitizedUri = HttpSanitizer.sanitizeUrl(
        "http://user:password@sentry.io?q=1&s=2&token=secret#top");
    expect(sanitizedUri?.url, "http://[Filtered]:[Filtered]@sentry.io");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('strips user info with user and password from https', () {
    final sanitizedUri = HttpSanitizer.sanitizeUrl(
        "https://user:password@sentry.io?q=1&s=2&token=secret#top");
    expect(sanitizedUri?.url, "https://[Filtered]:[Filtered]@sentry.io");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('splits url', () {
    final sanitizedUri =
        HttpSanitizer.sanitizeUrl("https://sentry.io?q=1&s=2&token=secret#top");
    expect(sanitizedUri?.url, "https://sentry.io");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('splits relative url', () {
    final sanitizedUri =
        HttpSanitizer.sanitizeUrl("/users/1?q=1&s=2&token=secret#top");
    expect(sanitizedUri?.url, "/users/1");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('splits relative root url', () {
    final sanitizedUri =
        HttpSanitizer.sanitizeUrl("/?q=1&s=2&token=secret#top");
    expect(sanitizedUri?.url, "/");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('splits url with just query and fragment', () {
    final sanitizedUri =
        HttpSanitizer.sanitizeUrl("/?q=1&s=2&token=secret#top");
    expect(sanitizedUri?.url, "/");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('splits relative url with query only', () {
    final sanitizedUri =
        HttpSanitizer.sanitizeUrl("/users/1?q=1&s=2&token=secret");
    expect(sanitizedUri?.url, "/users/1");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, isNull);
  });

  test('splits relative url with fragment only', () {
    final sanitizedUri = HttpSanitizer.sanitizeUrl("/users/1#top");
    expect(sanitizedUri?.url, "/users/1");
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, "top");
  });

  test('strips user info with user and password without query', () {
    final sanitizedUri =
        HttpSanitizer.sanitizeUrl("https://user:password@sentry.io#top");
    expect(sanitizedUri?.url, "https://[Filtered]:[Filtered]@sentry.io");
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, "top");
  });

  test('splits without query', () {
    final sanitizedUri = HttpSanitizer.sanitizeUrl("https://sentry.io#top");
    expect(sanitizedUri?.url, "https://sentry.io");
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, "top");
  });

  test('strips user info with user and password without fragment', () {
    final sanitizedUri = HttpSanitizer.sanitizeUrl(
        "https://user:password@sentry.io?q=1&s=2&token=secret");
    expect(sanitizedUri?.url, "https://[Filtered]:[Filtered]@sentry.io");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, isNull);
  });

  test('strips user info with user and password without query or fragment', () {
    final sanitizedUri =
        HttpSanitizer.sanitizeUrl("https://user:password@sentry.io");
    expect(sanitizedUri?.url, "https://[Filtered]:[Filtered]@sentry.io");
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, isNull);
  });

  test('splits url without query or fragment and no authority', () {
    final sanitizedUri = HttpSanitizer.sanitizeUrl("https://sentry.io");
    expect(sanitizedUri?.url, "https://sentry.io");
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, isNull);
  });

  test('strips user info with user only', () {
    final sanitizedUri = HttpSanitizer.sanitizeUrl(
        "https://user@sentry.io?q=1&s=2&token=secret#top");
    expect(sanitizedUri?.url, "https://[Filtered]@sentry.io");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('no details extracted with query after fragment', () {
    final sanitizedUri = HttpSanitizer.sanitizeUrl(
        "https://user:password@sentry.io#fragment?q=1&s=2&token=secret");
    expect(sanitizedUri?.url, isNull);
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, isNull);
  });

  test('no details extracted with query after fragment without authority', () {
    final sanitizedUri = HttpSanitizer.sanitizeUrl(
        "https://sentry.io#fragment?q=1&s=2&token=secret");
    expect(sanitizedUri?.url, isNull);
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, isNull);
  });

  test('no details extracted from malformed url', () {
    final sanitizedUri = HttpSanitizer.sanitizeUrl(
        "htps://user@sentry.io#fragment?q=1&s=2&token=secret");
    expect(sanitizedUri?.url, isNull);
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, isNull);
  });

  test('removes auth headers', () {
    final sanitizedHeaders = HttpSanitizer.sanitizedHeaders(
        {'authorization': 'foo', 'Authorization': 'foo'});
    expect(sanitizedHeaders, isNotNull);
    expect(sanitizedHeaders?['authorization'], isNull);
    expect(sanitizedHeaders?['Authorization'], isNull);
    expect(sanitizedHeaders?.containsKey('authorization'), false);
    expect(sanitizedHeaders?.containsKey('Authorization'), false);
  });

  test('removes Cookies headers', () {
    final sanitizedHeaders = HttpSanitizer.sanitizedHeaders(
        {'Cookies': 'om', 'cookies': 'nom', 'Cookie': 'om', 'cookie': 'nom'});
    expect(sanitizedHeaders, isNotNull);
    expect(sanitizedHeaders?['Cookies'], isNull);
    expect(sanitizedHeaders?['cookies'], isNull);
    expect(sanitizedHeaders?['Cookie'], isNull);
    expect(sanitizedHeaders?['cookie'], isNull);
    expect(sanitizedHeaders?.containsKey('Cookies'), false);
    expect(sanitizedHeaders?.containsKey('cookies'), false);
    expect(sanitizedHeaders?.containsKey('Cookie'), false);
    expect(sanitizedHeaders?.containsKey('cookie'), false);
  });
}
