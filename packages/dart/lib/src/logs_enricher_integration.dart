import 'dart:async';
import 'package:meta/meta.dart';

import 'sdk_lifecycle_hooks.dart';
import 'utils/os_utils.dart';
import 'integration.dart';
import 'hub.dart';
import 'protocol/sentry_attribute.dart';
import 'sentry_options.dart';

@internal
class LogsEnricherIntegration extends Integration<SentryOptions> {
  static const integrationName = 'LogsEnricher';

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    if (options.enableLogs) {
      options.lifecycleRegistry.registerCallback<OnBeforeCaptureLog>(
        (event) async {
          final os = getSentryOperatingSystem();

          if (os.name != null) {
            event.log.attributes['os.name'] = SentryAttribute.string(
              os.name ?? '',
            );
          }
          if (os.version != null) {
            event.log.attributes['os.version'] = SentryAttribute.string(
              os.version ?? '',
            );
          }
        },
      );
      options.sdk.addIntegration(integrationName);
    }
  }
}
