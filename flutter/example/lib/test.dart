import 'package:sentry/sentry.dart';

SentryEvent beforeSend(SentryEvent event, {dynamic hint}) {
  return hint is MyHint ? null : event;
}

Future<void> main() async {
  await Sentry.init((options) => options.beforeSend = beforeSend);
}
