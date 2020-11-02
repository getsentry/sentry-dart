/// Sentry Exception Mechanism
/// The exception mechanism is an optional field residing
/// in the Exception Interface. It carries additional information about
/// the way the exception was created on the target system.
/// This includes general exception values obtained from operating system or
/// runtime APIs, as well as mechanism-specific values.
class Mechanism {
  /// Required unique identifier of this mechanism determining rendering and processing of the mechanism data
  /// The type attribute is required to send any exception mechanism attribute,
  /// even if the SDK cannot determine the specific mechanism.
  /// In this case, set the type to "generic". See below for an example.
  final String type;

  /// Optional human readable description of the error mechanism and a possible hint on how to solve this error
  final String description;

  /// Optional fully qualified URL to an online help resource, possible interpolated with error parameters
  final String helpLink;

  /// Optional flag indicating whether the exception has been handled by the user (e.g. via try..catch)
  final bool handled;

  /// Optional information from the operating system or runtime on the exception mechanism
  /// The mechanism meta data usually carries error codes reported by
  /// the runtime or operating system, along with a platform dependent
  /// interpretation of these codes. SDKs can safely omit code names and
  /// descriptions for well known error codes, as it will be filled out by
  /// Sentry. For proprietary or vendor-specific error codes,
  /// adding these values will give additional information to the user.
  final Map<String, dynamic> meta;

  /// Arbitrary extra data that might help the user understand the error thrown by this mechanism
  final Map<String, dynamic> data;

  final bool synthetic;

  Mechanism({
    this.type,
    this.description,
    this.helpLink,
    this.handled,
    this.meta,
    this.data,
    this.synthetic,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (type != null) {
      json['type'] = type;
    }

    if (description != null) {
      json['description'] = description;
    }

    if (helpLink != null) {
      json['help_link'] = helpLink;
    }

    if (handled != null) {
      json['handled'] = handled;
    }

    if (meta != null && meta.isNotEmpty) {
      json['meta'] = meta;
    }

    if (data != null && data.isNotEmpty) {
      json['data'] = data;
    }

    if (synthetic != null) {
      json['synthetic'] = synthetic;
    }

    return json;
  }
}
