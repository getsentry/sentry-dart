import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/utils/url_details.dart';
import 'package:test/test.dart';

void main() {
  test('does not crash on null span', () {
    final urlDetails = UrlDetails("https://sentry.io/api", "q=1", "top");
    urlDetails.applyToSpan(null);
  });

  test('applies query and fragment to span', () {
    final urlDetails = UrlDetails("https://sentry.io/api", "q=1", "top");
    final span = MockSpan();
    urlDetails.applyToSpan(span);

    verify(span.setData("http.query", "q=1"));
    verify(span.setData("http.fragment", "top"));
  });

  test('applies query to span', () {
    final urlDetails = UrlDetails("https://sentry.io/api", "q=1", null);
    final span = MockSpan();
    urlDetails.applyToSpan(span);

    verify(span.setData("http.query", "q=1"));
    verifyNoMoreInteractions(span);
  });

  test('applies fragment to span', () {
    final urlDetails = UrlDetails("https://sentry.io/api", null, "top");
    final span = MockSpan();
    urlDetails.applyToSpan(span);

    verify(span.setData("http.fragment", "top"));
    verifyNoMoreInteractions(span);
  });

  test('applies details to request', () {
    final urlDetails = UrlDetails("https://sentry.io/api", "q=1", "top");
    final request = SentryRequest().withUriDetails(urlDetails);

    expect(request.url, "https://sentry.io/api");
    expect(request.queryString, "q=1");
    expect(request.fragment, "top");
  });

  test('applies details without fragment and url to request', () {
    final urlDetails = UrlDetails("https://sentry.io/api", null, null);
    final request = SentryRequest().withUriDetails(urlDetails);

    expect(request.url, "https://sentry.io/api");
    expect(request.queryString, isNull);
    expect(request.fragment, isNull);
  });

  test('returns fallback for null URL', () {
    final urlDetails = UrlDetails(null, null, null);
    expect(urlDetails.urlOrFallback, "unknown");
  });
}

class MockSpan extends Mock implements SentrySpan {}
