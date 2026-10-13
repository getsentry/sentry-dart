import 'package:sentry/sentry.dart';

import 'sentry_supabase_client_error.dart';

/// Keeps the issue title readable in obfuscated builds, where
/// `SentrySupabaseClientError.runtimeType` resolves to a minified name.
class SentrySupabaseExceptionTypeIdentifier implements ExceptionTypeIdentifier {
  @override
  String? identifyType(dynamic throwable) {
    if (throwable is SentrySupabaseClientError) {
      return 'SentrySupabaseClientError';
    }
    return null;
  }
}
