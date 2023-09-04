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

  test('removes security headers', () {
    final securityHeaders = [
      "X-FORWARDED-FOR",
      "AUTHORIZATION",
      "COOKIE",
      "SET-COOKIE",
      "X-API-KEY",
      "X-REAL-IP",
      "REMOTE-ADDR",
      "FORWARDED",
      "PROXY-AUTHORIZATION",
      "X-CSRF-TOKEN",
      "X-CSRFTOKEN",
      "X-XSRF-TOKEN"
    ];

    final headers = <String, String>{};
    for (final securityHeader in securityHeaders) {
      headers[securityHeader] = 'foo';
      headers[securityHeader.toLowerCase()] = 'bar';
      headers[securityHeader._capitalize()] = 'baz';
    }
    final sanitizedHeaders = HttpSanitizer.sanitizedHeaders(headers);
    expect(sanitizedHeaders, isNotNull);
    expect(sanitizedHeaders?.isEmpty, true);
  });

  test('handle throwing uri', () {
    final details = HttpSanitizer.sanitizeUrl('::Not valid URI::');
    expect(details, isNull);
  });

  test('keeps email address', () {
    final urlDetails = HttpSanitizer.sanitizeUrl(
        "https://staging.server.com/api/v4/auth/password/reset/email@example.com");
    expect(
        "https://staging.server.com/api/v4/auth/password/reset/email@example.com",
        urlDetails?.url);
    expect(urlDetails?.query, isNull);
    expect(urlDetails?.fragment, isNull);
  });
}

extension _StringExtension on String {
  String _capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
