import 'package:meta/meta.dart';

class Dsn {
  Dsn({
    @required this.publicKey,
    @required this.projectId,
    this.uri,
    this.secretKey,
  });

  /// The Sentry.io public key for the project.
  @visibleForTesting
  final String publicKey;

  /// The Sentry.io secret key for the project.
  @visibleForTesting
  final String secretKey;

  /// The ID issued by Sentry.io to your project.
  ///
  /// Attached to the event payload.
  final String projectId;

  /// The DSN URI.
  final Uri uri;

  static Dsn parse(String dsn) {
    final uri = Uri.parse(dsn);
    final userInfo = uri.userInfo.split(':');

    assert(() {
      if (uri.pathSegments.isEmpty) {
        throw ArgumentError(
          'Project ID not found in the URI path of the DSN URI: $dsn',
        );
      }

      return true;
    }());

    return Dsn(
      publicKey: userInfo[0],
      secretKey: userInfo.length >= 2 ? userInfo[1] : null,
      projectId: uri.pathSegments.last,
      uri: uri,
    );
  }
}
