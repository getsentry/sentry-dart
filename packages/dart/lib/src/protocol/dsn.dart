import 'package:meta/meta.dart';

/// Regex to extract the org ID from a DSN host (e.g. `o123.ingest.sentry.io` -> `123`).
final RegExp _orgIdFromHostRegExp = RegExp(r'^o(\d+)\.');

/// Extracts the organization ID from a DSN host string.
///
/// Returns the numeric org ID as a string, or `null` if the host does not
/// match the expected pattern (e.g. `o123.ingest.sentry.io`).
String? extractOrgIdFromDsnHost(String host) {
  final match = _orgIdFromHostRegExp.firstMatch(host);
  return match?.group(1);
}

/// The Data Source Name (DSN) tells the SDK where to send the events
@immutable
class Dsn {
  const Dsn({
    required this.publicKey,
    required this.projectId,
    this.uri,
    this.secretKey,
  });

  /// The Sentry.io public key for the project.
  final String publicKey;

  /// The Sentry.io secret key for the project.
  final String? secretKey;

  /// The ID issued by Sentry.io to your project.
  ///
  /// Attached to the event payload.
  final String projectId;

  /// The DSN URI.
  final Uri? uri;

  Uri get postUri {
    final uriCopy = uri!;
    final port = uriCopy.hasPort &&
            ((uriCopy.scheme == 'http' && uriCopy.port != 80) ||
                (uriCopy.scheme == 'https' && uriCopy.port != 443))
        ? ':${uriCopy.port}'
        : '';

    final pathLength = uriCopy.pathSegments.length;

    String apiPath;
    if (pathLength > 1) {
      // some paths would present before the projectID in the uri
      apiPath =
          (uriCopy.pathSegments.sublist(0, pathLength - 1) + ['api']).join('/');
    } else {
      apiPath = 'api';
    }
    return Uri.parse(
      '${uriCopy.scheme}://${uriCopy.host}$port/$apiPath/$projectId/envelope/',
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
