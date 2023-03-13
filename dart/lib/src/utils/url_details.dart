import '../../sentry.dart';

class UrlDetails {
  UrlDetails(this.url, this.query, this.fragment);

  final String? url;
  final String? query;
  final String? fragment;

  late final urlOrFallback = url ?? 'unknown';

  void applyToSpan(SentrySpan? span) {
    if (span == null) {
      return;
    }
    if (query != null) {
      span.setData("http.query", query);
    }
    if (fragment != null) {
      span.setData("http.fragment", fragment);
    }
  }
}

extension SentryRequestWithUriDetails on SentryRequest {
  SentryRequest withUriDetails(UrlDetails urlDetails) {
    return copyWith(
        url: urlDetails.url,
        queryString: urlDetails.query,
        fragment: urlDetails.fragment);
  }
}
