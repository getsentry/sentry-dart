import 'package:http/http.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_supabase/src/sentry_supabase_request.dart';
import 'package:test/test.dart';
import 'dart:convert';

void main() {
  // Create mock SentryOptions for testing
  late SentryOptions mockOptions;

  setUp(() {
    mockOptions = SentryOptions()
      ..sendDefaultPii = true
      ..maxRequestBodySize = MaxRequestBodySize.always;
  });

  group('SentrySupabaseRequest', () {
    group('only consider "rest/v1" as the base path', () {
      test('ignores non-rest/v1 paths', () {
        final request =
            Request('GET', Uri.parse('https://example.com/foo/v1/users'));
        final supabaseRequest = SentrySupabaseRequest.fromRequest(
          request,
          options: mockOptions,
        );
        expect(supabaseRequest, isNull);
      });
    });
    group('generateSqlQuery', () {
      group('SELECT operations', () {
        test('basic SELECT', () {
          final request =
              Request('GET', Uri.parse('https://example.com/rest/v1/users'));
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'SELECT * FROM "users"',
          );
        });
      });

      group('INSERT operations', () {
        test('INSERT with body data', () {
          final request = Request(
            'POST',
            Uri.parse('https://example.com/rest/v1/users'),
          )..body = jsonEncode({'name': 'John', 'email': 'john@example.com'});
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'INSERT INTO "users" ("name", "email") VALUES (?, ?)',
          );
        });

        test('INSERT with single column', () {
          final request =
              Request('POST', Uri.parse('https://example.com/rest/v1/users'))
                ..body = jsonEncode({'id': 42});
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'INSERT INTO "users" ("id") VALUES (?)',
          );
        });
      });

      group('UPSERT operations', () {
        test('UPSERT with body data', () {
          final request = Request(
            'POST',
            Uri.parse('https://example.com/rest/v1/users'),
          )..body = jsonEncode({'name': 'John', 'email': 'john@example.com'});
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'INSERT INTO "users" ("name", "email") VALUES (?, ?)',
          );
        });
      });

      group('UPDATE operations', () {
        test('UPDATE with body and WHERE clause', () {
          final request = Request(
            'PATCH',
            Uri.parse('https://example.com/rest/v1/users?id=eq.42'),
          )..body = jsonEncode({'name': 'Jane', 'email': 'jane@example.com'});
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'UPDATE "users" SET "name" = ?, "email" = ? WHERE id = ?',
          );
        });

        test('UPDATE with single column', () {
          final request = Request(
            'PATCH',
            Uri.parse('https://example.com/rest/v1/users?id=eq.42'),
          )..body = jsonEncode({'status': 'active'});
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'UPDATE "users" SET "status" = ? WHERE id = ?',
          );
        });

        test('UPDATE without WHERE clause', () {
          final request =
              Request('PATCH', Uri.parse('https://example.com/rest/v1/users'))
                ..body = jsonEncode({'status': 'inactive'});
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'UPDATE "users" SET "status" = ?',
          );
        });
      });

      group('DELETE operations', () {
        test('DELETE with WHERE clause', () {
          final request = Request(
            'DELETE',
            Uri.parse('https://example.com/rest/v1/users?id=eq.42'),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE id = ?',
          );
        });

        test('DELETE without WHERE clause', () {
          final request =
              Request('DELETE', Uri.parse('https://example.com/rest/v1/users'));
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users"',
          );
        });
      });

      group('UNKNOWN operations', () {
        test('unsupported HTTP method', () {
          final request = Request(
            'OPTIONS',
            Uri.parse('https://example.com/rest/v1/users'),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'UNKNOWN OPERATION ON "users"',
          );
        });
      });
    });

    group('WHERE clause generation', () {
      group('equality operators', () {
        test('eq (equals)', () {
          final request = Request(
            'DELETE',
            Uri.parse('https://example.com/rest/v1/users?id=eq.42'),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE id = ?',
          );
        });

        test('neq (not equals)', () {
          final request = Request(
            'DELETE',
            Uri.parse(
              'https://example.com/rest/v1/users?status=neq.inactive',
            ),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE status != ?',
          );
        });
      });

      group('comparison operators', () {
        test('gt (greater than)', () {
          final request = Request(
            'DELETE',
            Uri.parse('https://example.com/rest/v1/users?age=gt.18'),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE age > ?',
          );
        });

        test('gte (greater than or equal)', () {
          final request = Request(
            'DELETE',
            Uri.parse('https://example.com/rest/v1/users?age=gte.21'),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE age >= ?',
          );
        });

        test('lt (less than)', () {
          final request = Request(
            'DELETE',
            Uri.parse('https://example.com/rest/v1/users?age=lt.65'),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE age < ?',
          );
        });

        test('lte (less than or equal)', () {
          final request = Request(
            'DELETE',
            Uri.parse('https://example.com/rest/v1/users?age=lte.64'),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE age <= ?',
          );
        });
      });

      group('pattern matching operators', () {
        test('like with wildcards', () {
          final request = Request(
            'DELETE',
            Uri.parse('https://example.com/rest/v1/users?name=like.*john*'),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE name LIKE ?',
          );
        });

        test('ilike (case insensitive)', () {
          final request = Request(
            'DELETE',
            Uri.parse('https://example.com/rest/v1/users?name=ilike.John'),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE name ILIKE ?',
          );
        });
      });

      group('array operators', () {
        test('in with quoted values', () {
          final request = Request(
            'DELETE',
            Uri.parse(
              'https://example.com/rest/v1/users?status=in.("active","pending")',
            ),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE status IN ?',
          );
        });

        test('in with unquoted values', () {
          final request = Request(
            'DELETE',
            Uri.parse(
              'https://example.com/rest/v1/users?status=in.(active,pending)',
            ),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE status IN ?',
          );
        });
      });

      group('complex WHERE clauses', () {
        test('multiple AND conditions', () {
          final request = Request(
            'DELETE',
            Uri.parse(
              'https://example.com/rest/v1/users?id=eq.42&status=eq.active&age=gt.18',
            ),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE id = ? AND status = ? AND age > ?',
          );
        });

        test('OR condition', () {
          final request = Request(
            'DELETE',
            Uri.parse(
              'https://example.com/rest/v1/users?id=eq.42&or=status.eq.inactive',
            ),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE id = ? OR status = ?',
          );
        });

        test('multiple OR conditions', () {
          final request = Request(
            'DELETE',
            Uri.parse(
              'https://example.com/rest/v1/users?id=eq.42&or=status.eq.inactive&or=age.lt.18',
            ),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE id = ? OR status = ? OR age < ?',
          );
        });

        test('NOT condition', () {
          final request = Request(
            'DELETE',
            Uri.parse(
              'https://example.com/rest/v1/users?not=status.eq.deleted',
            ),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE status != ?',
          );
        });

        test('mixed AND, OR, and NOT conditions', () {
          final request = Request(
            'DELETE',
            Uri.parse(
              'https://example.com/rest/v1/users?id=eq.42&age=gt.18&or=status.eq.premium&not=type.eq.bot',
            ),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE id = ? AND age > ? OR status = ? AND type != ?',
          );
        });
      });

      group('SELECT with WHERE clauses', () {
        test('SELECT ignores WHERE clauses in SQL generation', () {
          final request = Request(
            'GET',
            Uri.parse(
              'https://example.com/rest/v1/users?id=eq.42&status=eq.active',
            ),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'SELECT * FROM "users"',
          );
        });
      });

      group('edge cases', () {
        test('malformed query parameter', () {
          final request = Request(
            'DELETE',
            Uri.parse('https://example.com/rest/v1/users?invalid_param'),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users"',
          );
        });

        test('empty query value', () {
          final request = Request(
            'DELETE',
            Uri.parse('https://example.com/rest/v1/users?id='),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users"',
          );
        });

        test('query with select that should be skipped in WHERE', () {
          final request = Request(
            'DELETE',
            Uri.parse(
              'https://example.com/rest/v1/users?select=name,email&id=eq.42',
            ),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE id = ?',
          );
        });

        test('unknown operator defaults to equals', () {
          final request = Request(
            'DELETE',
            Uri.parse('https://example.com/rest/v1/users?id=unknown.42'),
          );
          final supabaseRequest =
              SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

          expect(
            supabaseRequest.generateSqlQuery(),
            'DELETE FROM "users" WHERE id = ?',
          );
        });
      });
    });

    group('query parsing', () {
      test('parses table name from URL path', () {
        final request = Request(
          'GET',
          Uri.parse('https://example.com/rest/v1/my_table_name'),
        );
        final supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

        expect(supabaseRequest.table, 'my_table_name');
      });

      test('parses table name correctly when URL has additional path segments',
          () {
        // Test with URL like /rest/v1/users/123 where 'users' is the table name, not '123'
        final request = Request(
          'GET',
          Uri.parse('https://example.com/rest/v1/users/123'),
        );
        final supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

        expect(supabaseRequest.table, 'users');
      });

      test(
          'parses table name correctly when URL has multiple additional path segments',
          () {
        // Test with URL like /rest/v1/users/123/profile where 'users' is the table name
        final request = Request(
          'GET',
          Uri.parse('https://example.com/rest/v1/users/123/profile'),
        );
        final supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

        expect(supabaseRequest.table, 'users');
      });

      test('returns null for URLs with insufficient path segments', () {
        // Test with URL like /rest/v1 (missing table name)
        final request = Request(
          'GET',
          Uri.parse('https://example.com/rest/v1'),
        );
        final supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions);

        expect(supabaseRequest, isNull);
      });

      test('returns null for URLs with only rest/v1/ (missing table name)', () {
        // Test with URL like /rest/v1/ (missing table name)
        final request = Request(
          'GET',
          Uri.parse('https://example.com/rest/v1/'),
        );
        final supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions);

        expect(supabaseRequest, isNull);
      });

      test('parses operation from HTTP method and headers', () {
        // GET -> SELECT
        var request =
            Request('GET', Uri.parse('https://example.com/rest/v1/users'));
        var supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;
        expect(supabaseRequest.operation.value, 'select');

        // POST -> INSERT
        request =
            Request('POST', Uri.parse('https://example.com/rest/v1/users'));
        supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;
        expect(supabaseRequest.operation.value, 'insert');

        // POST with Prefer header -> UPSERT
        request =
            Request('POST', Uri.parse('https://example.com/rest/v1/users'))
              ..headers['Prefer'] = 'resolution=merge-duplicates';
        supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;
        expect(supabaseRequest.operation.value, 'upsert');

        // PATCH -> UPDATE
        request =
            Request('PATCH', Uri.parse('https://example.com/rest/v1/users'));
        supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;
        expect(supabaseRequest.operation.value, 'update');

        // DELETE -> DELETE
        request =
            Request('DELETE', Uri.parse('https://example.com/rest/v1/users'));
        supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;
        expect(supabaseRequest.operation.value, 'delete');
      });

      test('parses query parameters into query list', () {
        final request = Request(
          'GET',
          Uri.parse(
            'https://example.com/rest/v1/users?id=eq.42&name=ilike.John&status=in.("active","pending")&select=id,name',
          ),
        );
        final supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

        expect(
          supabaseRequest.query,
          containsAll([
            'eq(id, 42)',
            'ilike(name, John)',
            'in(status, ("active","pending"))',
            'select(id,name)',
          ]),
        );
      });

      test('parses JSON body', () {
        final request =
            Request('POST', Uri.parse('https://example.com/rest/v1/users'))
              ..body = jsonEncode({'name': 'John', 'age': 30});
        final supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions)!;

        expect(supabaseRequest.body, {'name': 'John', 'age': 30});
      });

      test('handles non-JSON body gracefully', () {
        final request =
            Request('POST', Uri.parse('https://example.com/rest/v1/users'))
              ..body = 'not valid json';

        final supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions);
        expect(supabaseRequest, isNull);
      });

      test('handles empty body', () {
        final request =
            Request('POST', Uri.parse('https://example.com/rest/v1/users'));
        final supabaseRequest =
            SentrySupabaseRequest.fromRequest(request, options: mockOptions);
        expect(supabaseRequest, isNotNull);
        expect(supabaseRequest?.body, isNull);
      });

      test('respects sendDefaultPii setting', () {
        final request = Request(
          'POST',
          Uri.parse('https://example.com/rest/v1/users'),
        )..body = jsonEncode({'name': 'John', 'age': 30});

        // Test with sendDefaultPii = false
        final optionsWithPiiDisabled = SentryOptions()
          ..sendDefaultPii = false
          ..maxRequestBodySize = MaxRequestBodySize.always;

        final supabaseRequestWithoutPii = SentrySupabaseRequest.fromRequest(
          request,
          options: optionsWithPiiDisabled,
        );
        expect(supabaseRequestWithoutPii, isNotNull);
        expect(supabaseRequestWithoutPii?.body, isNull);

        // Test with sendDefaultPii = true
        final optionsWithPiiEnabled = SentryOptions()
          ..sendDefaultPii = true
          ..maxRequestBodySize = MaxRequestBodySize.always;

        final supabaseRequestWithPii = SentrySupabaseRequest.fromRequest(
          request,
          options: optionsWithPiiEnabled,
        );
        expect(supabaseRequestWithPii, isNotNull);
        expect(supabaseRequestWithPii?.body, {'name': 'John', 'age': 30});
      });

      test('respects maxRequestBodySize setting', () {
        final request = Request(
          'POST',
          Uri.parse('https://example.com/rest/v1/users'),
        )..body = jsonEncode({'name': 'John', 'age': 30});

        // Test with maxRequestBodySize = small (4KB limit)
        final optionsWithSmallLimit = SentryOptions()
          ..sendDefaultPii = true
          ..maxRequestBodySize = MaxRequestBodySize.small;

        // Small body should be included
        final supabaseRequestWithSmallBody = SentrySupabaseRequest.fromRequest(
          request,
          options: optionsWithSmallLimit,
        );
        expect(supabaseRequestWithSmallBody, isNotNull);
        expect(supabaseRequestWithSmallBody?.body, {'name': 'John', 'age': 30});

        // Test with a large body that exceeds the small limit
        final largeBody = 'x' * 5000; // 5KB, exceeds 4KB small limit
        final requestWithLargeBody = Request(
          'POST',
          Uri.parse('https://example.com/rest/v1/users'),
        )..body = largeBody;

        final supabaseRequestWithLargeBody = SentrySupabaseRequest.fromRequest(
          requestWithLargeBody,
          options: optionsWithSmallLimit,
        );
        expect(supabaseRequestWithLargeBody, isNotNull);
        expect(
          supabaseRequestWithLargeBody?.body,
          isNull,
        ); // Body should be filtered out due to size

        // Test with maxRequestBodySize = never
        final optionsWithNeverLimit = SentryOptions()
          ..sendDefaultPii = true
          ..maxRequestBodySize = MaxRequestBodySize.never;

        final supabaseRequestWithNeverLimit = SentrySupabaseRequest.fromRequest(
          request,
          options: optionsWithNeverLimit,
        );
        expect(supabaseRequestWithNeverLimit, isNotNull);
        expect(
          supabaseRequestWithNeverLimit?.body,
          isNull,
        ); // Body should never be included
      });
    });
  });
}
