import 'package:meta/meta.dart';

/// A [Package] part of the [Sdk].
@immutable
class Package {
  /// Creates an [Package] object that is part of the [Sdk].
  const Package(this.name, this.version);

  /// The name of the SDK.
  final String name;

  /// The version of the SDK.
  final String version;

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return <String, String>{
      'name': name,
      'version': version,
    };
  }
}
