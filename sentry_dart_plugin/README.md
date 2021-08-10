# Sentry Dart Plugin

A Dart Build Plugin that uploads symbols to Sentry via sentry-cli

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

The `flutter build apk` or `flutter build ios` is required to upload the symbols

## Configuration (Optional)
This tool come with default configuration, you can configure it to suit your needs.

Add `sentry_plugin:` configuration at the end of your `pubspec.yaml` file:
```yaml
sentry_plugin:
  upload_native_symbols: true
  include_native_sources: true
  project: sentry-flutter
  org: sentry-sdks
  auth_token: ...
  wait: true
  log_level: error
```

###### Available Configuration Fields:
_TODO_
