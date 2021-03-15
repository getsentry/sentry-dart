import 'dart:async';
import '../protocol.dart';
import '../sentry_options.dart';

/// Default value for [User.ipAddress]. It gets set when an event does not have
/// a user and IP address. Only applies if [SentryOptions.sendDefaultPii] is set
/// to true.
const _defaultIpAddress = '{{auto}}';

/// This adds an [EventProcessor] which modifies the users IP address according
/// to [SentryOptions.sendDefaultPii].
void addUserEventProcessor(SentryOptions options) {
  options.addEventProcessor(
      (event, {hint}) => userEventProcessor(options, event, hint: hint));
}

FutureOr<SentryEvent?> userEventProcessor(
    SentryOptions options, SentryEvent event,
    {dynamic hint}) {
  if (options.sendDefaultPii == false) {
    return event;
  }
  var user = event.user;
  if (user == null) {
    user = User(ipAddress: _defaultIpAddress);
    return event.copyWith(user: user);
  } else if (event.user?.ipAddress == null) {
    return event.copyWith(user: user.copyWith(ipAddress: _defaultIpAddress));
  }
  return event;
}
