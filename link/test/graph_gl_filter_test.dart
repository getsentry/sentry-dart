import 'package:sentry/sentry.dart';
import 'package:sentry_link/sentry_link.dart';
import 'package:test/test.dart';

void main() {
  test('GraphQL urls should be filtered', () {
    final result = graphQlFilter()(
      Breadcrumb.http(
          url: Uri.parse('https://example.org/graphql'), method: 'get'),
      Hint(),
    );
    expect(result, null);
  });

  test('non GraphQL urls should not be filtered', () {
    final result = graphQlFilter()(
      Breadcrumb.http(url: Uri.parse('https://example.org/'), method: 'get'),
      Hint(),
    );
    expect(result, isNotNull);
  });
}
