import 'package:meta/meta.dart';

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

  @Deprecated('Use [envelopeUri] instead')
  Uri get postUri => envelopeUri;

  Uri get envelopeUri => _UriData.fromUri(uri!, projectId).envelopeUri;

  Uri get featureFlagsUri => _UriData.fromUri(uri!, projectId).featureFlagsUri;

  // Uri get featureFlagsUri {
  //   return postUri.replace()
  // }

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

class _UriData {
  final String scheme;
  final String host;
  final String port;
  final String apiPath;
  final String projectId;

  _UriData(this.scheme, this.host, this.port, this.apiPath, this.projectId);

  factory _UriData.fromUri(Uri uri, String projectId) {
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

    return _UriData(uri.scheme, uri.host, port, apiPath, projectId);
  }

  Uri get envelopeUri =>
      Uri.parse('$scheme://$host}$port/$apiPath/$projectId/envelope/');

  Uri get featureFlagsUri =>
      Uri.parse('$scheme://$host}$port/$apiPath/$projectId/feature_flags/');
}
