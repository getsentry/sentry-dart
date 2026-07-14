import 'package:meta/meta.dart';

@internal
const appStartRootName = 'App Start';

@internal
const appStartExtensionName = 'Extended App Start';

@internal
const appStartIdleTimeout = Duration(seconds: 3);

@internal
const appStartFinalTimeout = Duration(seconds: 30);

@internal
const appStartPluginRegistrationDescription =
    'App start to plugin registration';

@internal
const appStartSentrySetupDescription = 'Before Sentry Init Setup';

@internal
const appStartFirstFrameRenderDescription = 'First frame render';

@internal
DateTime appStartMeasurementEnd(
  DateTime naturalEnd,
  DateTime? extensionEnd,
) =>
    extensionEnd != null && extensionEnd.isAfter(naturalEnd)
        ? extensionEnd
        : naturalEnd;

@internal
Duration appStartDuration(
  DateTime processStart,
  DateTime naturalEnd,
  DateTime? extensionEnd,
) =>
    appStartMeasurementEnd(naturalEnd, extensionEnd).difference(processStart);
