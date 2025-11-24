import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_supabase/sentry_supabase.dart';

Future<void> main() async {
  // Create a [SentrySupabaseClient] and pass it to Supabase during initialization.

  final sentrySupabaseClient = SentrySupabaseClient();
  await Supabase.initialize(
    url: '<YOUR_SUPABASE_URL>',
    anonKey: '<YOUR_SUPABASE_ANON_KEY>',
    httpClient: sentrySupabaseClient,
  );

  // Now all [Supabase] operations and queries will
  // be instrumented with Sentry breadcrumbs, traces and errors.

  final issues = await Supabase.instance.client.from('issues').select();
}
