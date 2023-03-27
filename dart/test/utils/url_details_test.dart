import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('does not crash on null span', () {
    final urlDetails =
        UrlDetails(url: "https://sentry.io/api", query: "q=1", fragment: "top");
    urlDetails.applyToSpan(null);
  });

  test('applies all to span', () {
    final urlDetails =
        UrlDetails(url: "https://sentry.io/api", query: "q=1", fragment: "top");
    final span = MockSpan();
    urlDetails.applyToSpan(span);

    verify(span.setData("url", "https://sentry.io/api"));
    verify(span.setData("http.query", "q=1"));
    verify(span.setData("http.fragment", "top"));
  });

  test('applies only url to span', () {
    final urlDetails = UrlDetails(url: "https://sentry.io/api");
    final span = MockSpan();
    urlDetails.applyToSpan(span);

    verify(span.setData("url", "https://sentry.io/api"));
    verifyNoMoreInteractions(span);
  });

  test('applies only query to span', () {
    final urlDetails = UrlDetails(query: "q=1");
    final span = MockSpan();
    urlDetails.applyToSpan(span);

    verify(span.setData("http.query", "q=1"));
    verifyNoMoreInteractions(span);
  });

  test('applies only fragment to span', () {
    final urlDetails = UrlDetails(fragment: "top");
    final span = MockSpan();
    urlDetails.applyToSpan(span);

    verify(span.setData("http.fragment", "top"));
    verifyNoMoreInteractions(span);
  });

  test('applies details to request', () {
    final url = "https://sentry.io/api?q=1#top";
    final request = SentryRequest(url: url).sanitized();

    expect(request.url, "https://sentry.io/api");
    expect(request.queryString, "q=1");
    expect(request.fragment, "top");
  });

  test('applies details without fragment and url to request', () {
    final request = SentryRequest(url: 'https://sentry.io/api').sanitized();

    expect(request.url, "https://sentry.io/api");
    expect(request.queryString, isNull);
    expect(request.fragment, isNull);
  });

  test('removes cookies from request', () {
    final request =
        SentryRequest(url: 'https://sentry.io/api', cookies: 'foo=bar')
            .sanitized();
    expect(request.cookies, isNull);
  });

  test('returns fallback for null URL', () {
    final urlDetails = UrlDetails(url: null);
    expect(urlDetails.urlOrFallback, "unknown");
  });
}

class MockSpan extends Mock implements SentrySpan {}
