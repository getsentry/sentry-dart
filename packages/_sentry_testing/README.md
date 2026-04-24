# _sentry_testing

Internal testing utilities for the Sentry Dart/Flutter SDK monorepo that can be shared among packages.

> ⚠️ **Internal Use Only**
> This package is for use within the Sentry SDK development only.
> It is not published and should not be used in external projects.

## Usage

Add to the integration package's `dev_dependencies`:

```yaml
dev_dependencies:
  _sentry_testing:
    path: ../_sentry_testing
```

Import in tests:

```dart
import 'package:_sentry_testing/_sentry_testing.dart';
```
