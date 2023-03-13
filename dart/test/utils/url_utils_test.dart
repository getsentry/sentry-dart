
import 'package:sentry/src/utils/url_sanitizer.dart';
import 'package:test/test.dart';

void main() {

  test('returns null for null', () {
    expect(UrlUtils.parse(null), isNull);
  });

  test('strips user info with user and password from http', () {
    final sanitizedUri = UrlUtils.parse(
        "http://user:password@sentry.io?q=1&s=2&token=secret#top"
    );
    expect(sanitizedUri?.url, "http://[Filtered]:[Filtered]@sentry.io");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('strips user info with user and password from https', () {
    final sanitizedUri = UrlUtils.parse(
        "https://user:password@sentry.io?q=1&s=2&token=secret#top"
    );
    expect(sanitizedUri?.url, "https://[Filtered]:[Filtered]@sentry.io");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('splits url', () {
    final sanitizedUri = UrlUtils.parse(
        "https://sentry.io?q=1&s=2&token=secret#top"
    );
    expect(sanitizedUri?.url, "https://sentry.io");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('splits relative url', () {
    final sanitizedUri = UrlUtils.parse(
        "/users/1?q=1&s=2&token=secret#top"
    );
    expect(sanitizedUri?.url, "/users/1");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('splits relative root url', () {
    final sanitizedUri = UrlUtils.parse(
        "/?q=1&s=2&token=secret#top"
    );
    expect(sanitizedUri?.url, "/");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('splits url with just query and fragment', () {
    final sanitizedUri = UrlUtils.parse(
        "/?q=1&s=2&token=secret#top"
    );
    expect(sanitizedUri?.url, "/");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('splits relative url with query only', () {
    final sanitizedUri = UrlUtils.parse(
        "/users/1?q=1&s=2&token=secret"
    );
    expect(sanitizedUri?.url, "/users/1");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, isNull);
  });

  test('splits relative url with fragment only', () {
    final sanitizedUri = UrlUtils.parse(
        "/users/1#top"
    );
    expect(sanitizedUri?.url, "/users/1");
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, "top");
  });

  test('strips user info with user and password without query', () {
    final sanitizedUri = UrlUtils.parse(
        "https://user:password@sentry.io#top"
    );
    expect(sanitizedUri?.url, "https://[Filtered]:[Filtered]@sentry.io");
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, "top");
  });

  test('splits without query', () {
    final sanitizedUri = UrlUtils.parse(
        "https://sentry.io#top"
    );
    expect(sanitizedUri?.url, "https://sentry.io");
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, "top");
  });

  test('strips user info with user and password without fragment', () {
    final sanitizedUri = UrlUtils.parse(
        "https://user:password@sentry.io?q=1&s=2&token=secret"
    );
    expect(sanitizedUri?.url, "https://[Filtered]:[Filtered]@sentry.io");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, isNull);
  });

  test('strips user info with user and password without query or fragment', () {
    final sanitizedUri = UrlUtils.parse(
        "https://user:password@sentry.io"
    );
    expect(sanitizedUri?.url, "https://[Filtered]:[Filtered]@sentry.io");
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, isNull);
  });

  test('splits url without query or fragment and no authority', () {
    final sanitizedUri = UrlUtils.parse(
        "https://sentry.io"
    );
    expect(sanitizedUri?.url, "https://sentry.io");
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, isNull);
  });

  test('strips user info with user only', () {
    final sanitizedUri = UrlUtils.parse(
        "https://user@sentry.io?q=1&s=2&token=secret#top"
    );
    expect(sanitizedUri?.url, "https://[Filtered]@sentry.io");
    expect(sanitizedUri?.query, "q=1&s=2&token=secret");
    expect(sanitizedUri?.fragment, "top");
  });

  test('no details extracted with query after fragment', () {
    final sanitizedUri = UrlUtils.parse(
        "https://user:password@sentry.io#fragment?q=1&s=2&token=secret"
    );
    expect(sanitizedUri?.url, isNull);
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, isNull);
  });

  test('no details extracted with query after fragment without authority', () {
    final sanitizedUri = UrlUtils.parse(
        "https://sentry.io#fragment?q=1&s=2&token=secret"
    );
    expect(sanitizedUri?.url, isNull);
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, isNull);
  });

  test('no details extracted from malformed url', () {
    final sanitizedUri = UrlUtils.parse(
        "htps://user@sentry.io#fragment?q=1&s=2&token=secret"
    );
    expect(sanitizedUri?.url, isNull);
    expect(sanitizedUri?.query, isNull);
    expect(sanitizedUri?.fragment, isNull);
  });

}
