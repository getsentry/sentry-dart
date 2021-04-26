import 'package:meta/meta.dart';

/// Sentry Exception Mechanism
/// The exception mechanism is an optional field residing
/// in the Exception Interface. It carries additional information about
/// the way the exception was created on the target system.
/// This includes general exception values obtained from operating system or
/// runtime APIs, as well as mechanism-specific values.
@immutable
class Mechanism {
  /// Required unique identifier of this mechanism determining rendering and processing of the mechanism data
  /// The type attribute is required to send any exception mechanism attribute,
  /// even if the SDK cannot determine the specific mechanism.
  /// In this case, set the type to "generic". See below for an example.
  final String type;

  /// Optional human readable description of the error mechanism and a possible hint on how to solve this error
  final String? description;

  /// Optional fully qualified URL to an online help resource, possible interpolated with error parameters
  final String? helpLink;

  /// Optional flag indicating whether the exception has been handled by the user (e.g. via try..catch)
  final bool? handled;

  final Map<String, dynamic>? _meta;

  /// Optional information from the operating system or runtime on the exception mechanism
  /// The mechanism meta data usually carries error codes reported by
  /// the runtime or operating system, along with a platform dependent
  /// interpretation of these codes. SDKs can safely omit code names and
  /// descriptions for well known error codes, as it will be filled out by
  /// Sentry. For proprietary or vendor-specific error codes,
  /// adding these values will give additional information to the user.
  Map<String, dynamic> get meta => Map.unmodifiable(_meta ?? const {});

  final Map<String, dynamic>? _data;

  /// Arbitrary extra data that might help the user understand the error thrown by this mechanism
  Map<String, dynamic> get data => Map.unmodifiable(_data ?? const {});

  /// An optional flag indicating that this error is synthetic.
  /// Synthetic errors are errors that carry little meaning by themselves.
  /// This may be because they are created at a central place (like a crash handler), and are all called the same: Error, Segfault etc. When the flag is set, Sentry will then try to use other information (top in-app frame function) rather than exception type and value in the UI for the primary event display. This flag should be set for all "segfaults" for instance as every single error group would look very similar otherwise.
  final bool? synthetic;

  Mechanism({
    required this.type,
    this.description,
    this.helpLink,
    this.handled,
    this.synthetic,
    Map<String, dynamic>? meta,
    Map<String, dynamic>? data,
  })  : _meta = meta != null ? Map.from(meta) : null,
        _data = data != null ? Map.from(data) : null;

  Mechanism copyWith({
    String? type,
    String? description,
    String? helpLink,
    bool? handled,
    Map<String, dynamic>? meta,
    Map<String, dynamic>? data,
    bool? synthetic,
  }) =>
      Mechanism(
        type: type ?? this.type,
        description: description ?? this.description,
        helpLink: helpLink ?? this.helpLink,
        handled: handled ?? this.handled,
        meta: meta ?? this.meta,
        data: data ?? this.data,
        synthetic: synthetic ?? this.synthetic,
      );

  /// Deserializes a [Mechanism] from JSON [Map].
  factory Mechanism.fromJson(Map<String, dynamic> json) {
    return Mechanism(
      type: json['type'],
      description: json['description'],
      helpLink: json['help_link'],
      handled: json['handled'],
      meta: json['meta'],
      data: json['data'],
      synthetic: json['synthetic'],
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    json['type'] = type;

    if (description != null) {
      json['description'] = description;
    }

    if (helpLink != null) {
      json['help_link'] = helpLink;
    }

    if (handled != null) {
      json['handled'] = handled;
    }

    if (_meta?.isNotEmpty ?? false) {
      json['meta'] = _meta;
    }

    if (_data?.isNotEmpty ?? false) {
      json['data'] = _data;
    }

    if (synthetic != null) {
      json['synthetic'] = synthetic;
    }

    return json;
  }
}
