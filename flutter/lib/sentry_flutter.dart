/// A Flutter client for Sentry.io crash reporting.
library;

// ignore: invalid_export_of_internal_element
export 'package:sentry/sentry.dart';

export 'src/binding_wrapper.dart'
    show BindingWrapper, SentryWidgetsFlutterBinding;
export 'src/feedback/sentry_feedback_widget.dart';
export 'src/flutter_sentry_attachment.dart';
export 'src/integrations/load_release_integration.dart';
export 'src/integrations/on_error_integration.dart';
export 'src/navigation/sentry_navigator_observer.dart';
export 'src/replay/replay_quality.dart';
export 'src/screenshot/masking_config.dart' show SentryMaskingDecision;
export 'src/screenshot/sentry_mask_widget.dart';
export 'src/screenshot/sentry_screenshot_quality.dart';
export 'src/screenshot/sentry_screenshot_widget.dart';
export 'src/screenshot/sentry_unmask_widget.dart';
export 'src/sentry_asset_bundle.dart' show SentryAssetBundle;
export 'src/sentry_flutter.dart';
export 'src/sentry_flutter_options.dart';
export 'src/sentry_privacy_options.dart';
export 'src/sentry_replay_options.dart';
export 'src/sentry_widget.dart';
export 'src/user_interaction/sentry_user_interaction_widget.dart';
