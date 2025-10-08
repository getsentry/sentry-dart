<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>


===========

<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry integration for `supabase` package
===========

| package     | build                                                                                                                                                                                | pub                                                                                                  | likes                                                                                                | popularity                                                                                                     | pub points |
|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------| ------- |
| sentry_supabase | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/supabase.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-supabase) | [![pub package](https://img.shields.io/pub/v/sentry_supabase.svg)](https://pub.dev/packages/sentry_supabase) | [![likes](https://img.shields.io/pub/likes/sentry_supabase)](https://pub.dev/packages/sentry_supabase/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_supabase)](https://pub.dev/packages/sentry_supabase/score) | [![pub points](https://img.shields.io/pub/points/sentry_supabase)](https://pub.dev/packages/sentry_supabase/score)

Integration for [`supabase`](https://pub.dev/packages/supabase) package. 

#### Usage

- Sign up for a Sentry.io account and get a DSN at https://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io.

- Call...

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_supabase/sentry_supabase.dart';

// Create a [SentrySupabaseClient] and pass it to Supabase during initialization.

final sentrySupabaseClient = SentrySupabaseClient();
await Supabase.initialize(
  url: '<YOUR_SUPABASE_URL>',
  anonKey: '<YOUR_SUPABASE_ANON_KEY>',
  httpClient: sentrySupabaseClient,
);

// Now all [Supabase] operations and queries will
// be instrumented with Sentry breadcrumbs, traces and errors.

final issues = await Supabase.instance.client
  .from('issues')
  .select();
```

#### Resources

* [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
* [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
* [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-dart.svg)](https://github.com/getsentry/sentry-dart/discussions)
* [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/PXa5Apfe7K)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
