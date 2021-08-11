# Sentry Dart Plugin

A Dart Build Plugin that uploads symbols for Android and iOS to Sentry via sentry-cli.

## :clipboard: Install

In your `pubspec.yaml`, add `sentry_dart_plugin` as a new dev dependency.

```yaml
dev_dependencies:
  sentry_dart_plugin: ^1.0.0-alpha.1
```

## Run

```bash
dart run sentry_dart_plugin
```

The `flutter build apk` or `flutter build ios` is required before executing the `sentry_dart_plugin` plugin.

## Configuration (Optional)

This tool comes with default configuration, you can configure it to suit your needs.

Add `sentry_plugin:` configuration at the end of your `pubspec.yaml` file:

```yaml
sentry_plugin:
  upload_native_symbols: true
  include_native_sources: false
  project: ...
  org: ...
  auth_token: ...
  wait: false
  log_level: error # possible values: trace, debug, info, warn, error
```

###### Available Configuration Fields:

| Configuration Name | Description | Default Value And Type | Required | Alternative Environment variable |
| - | - | - | - | - |
| upload_native_symbols | Enables or disables the automatic upload of debug symbols | true (boolean) | no | - |
| include_native_sources | Does or doesn't include the source code of native code | false (boolean) | no | - |
| project | Project's name | e.g. sentry-flutter (string) | yes | SENTRY_PROJECT |
| org | Organization's slug | e.g. sentry-sdks (string) | yes | SENTRY_ORG |
| auth_token | Auth Token | e.g. 64 random characteres (string)  | yes | SENTRY_AUTH_TOKEN |
| wait | Wait for server-side processing of uploaded files | false (boolean)  | no | - |
| log_level | Configures the log level for sentry-cli | warn (string)  | no | SENTRY_LOG_LEVEL |
