# Sentry Dart Plugin

A Dart Build Plugin that uploads symbols for Android, iOS/macOS and Web to Sentry via [sentry-cli](https://docs.sentry.io/product/cli/).

For doing it manually, please follow our [docs](https://docs.sentry.io/platforms/flutter/upload-debug/).

## :clipboard: Install

In your `pubspec.yaml`, add `sentry_dart_plugin` as a new dev dependency.

```yaml
dev_dependencies:
  sentry_dart_plugin: ^1.0.0-alpha.1
```

## Build App

The `flutter build apk`, `flutter build ios` (or _macos_) or `flutter build web` is required before executing the `sentry_dart_plugin` plugin, because the build spits out the debug symbols and source maps.

## Run

```bash
dart run sentry_dart_plugin
```

## Configuration (Optional)

This tool comes with default configuration, you can configure it to suit your needs.

Add `sentry:` configuration at the end of your `pubspec.yaml` file:

```yaml
sentry:
  upload_native_symbols: true
  upload_source_maps: false
  include_native_sources: false
  project: ...
  org: ...
  auth_token: ...
  wait_for_processing: false
  log_level: error # possible values: trace, debug, info, warn, error
  release: ...
  web_build_path: ...
```

###### Available Configuration Fields:

| Configuration Name | Description | Default Value And Type | Required | Alternative Environment variable |
| - | - | - | - | - |
| upload_native_symbols | Enables or disables the automatic upload of debug symbols | true (boolean) | no | - |
| upload_source_maps | Enables or disables the automatic upload of source maps | false (boolean) | no | - |
| include_native_sources | Does or doesn't include the source code of native code | false (boolean) | no | - |
| project | Project's name | e.g. sentry-flutter (string) | yes | SENTRY_PROJECT |
| org | Organization's slug | e.g. sentry-sdks (string) | yes | SENTRY_ORG |
| auth_token | Auth Token | e.g. 64 random characteres (string)  | yes | SENTRY_AUTH_TOKEN |
| wait_for_processing | Wait for server-side processing of uploaded files | false (boolean)  | no | - |
| log_level | Configures the log level for sentry-cli | warn (string)  | no | SENTRY_LOG_LEVEL |
| release | The release version for source maps, it should match the release set by the SDK | default: name@version from pubspec (string)  | no | - |
| web_build_path | The web build folder | default: build/web (string)  | no | - |
