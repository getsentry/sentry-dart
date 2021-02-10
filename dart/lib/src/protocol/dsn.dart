import 'package:meta/meta.dart';

/// The Data Source Name (DSN) tells the SDK where to send the events
@immutable
class Dsn {
  const Dsn({
    @required this.publicKey,
    @required this.projectId,
    this.uri,
    this.secretKey,
  });

  /// The Sentry.io public key for the project.
  final String publicKey;

  /// The Sentry.io secret key for the project.
  final String secretKey;

  /// The ID issued by Sentry.io to your project.
  ///
  /// Attached to the event payload.
  final String projectId;

  /// The DSN URI.
  final Uri uri;

  Uri get postUri {
    final port = uri.hasPort &&
            ((uri.scheme == 'http' && uri.port != 80) ||
                (uri.scheme == 'https' && uri.port != 443))
        ? ':${uri.port}'
        : '';

    final pathLength = uri.pathSegments.length;

    String apiPath;
    if (pathLength > 1) {
      // some paths would present before the projectID in the uri
      apiPath =
          (uri.pathSegments.sublist(0, pathLength - 1) + ['api']).join('/');
    } else {
      apiPath = 'api';
    }
    return Uri.parse(
      '${uri.scheme}://${uri.host}$port/$apiPath/$projectId/store/',
    );
  }

  /// Parses a DSN String to a Dsn object
  factory Dsn.parse(String dsn) {
    final uri = Uri.parse(dsn);
    final userInfo = uri.userInfo.split(':');

    if (uri.pathSegments.isEmpty) {
      throw ArgumentError(
        'Project ID not found in the URI path of the DSN URI: $dsn',
      );
    }

    return Dsn(
      publicKey: userInfo[0],
      secretKey: userInfo.length >= 2 ? userInfo[1] : null,
      projectId: uri.pathSegments.last,
      uri: uri,
    );
  }
}
