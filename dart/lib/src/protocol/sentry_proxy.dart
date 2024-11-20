class SentryProxy {
  final SentryProxyType type;
  final String? host;
  final int? port;
  final String? user;
  final String? pass;

  SentryProxy({required this.type, this.host, this.port, this.user, this.pass});

  String toPacString() {
    String type = 'DIRECT';
    switch (this.type) {
      case SentryProxyType.direct:
        return 'DIRECT';
      case SentryProxyType.http:
        type = 'PROXY';
        break;
      case SentryProxyType.socks:
        type = 'SOCKS';
        break;
    }
    if (host != null && port != null) {
      return '$type $host:$port';
    } else if (host != null) {
      return '$type $host';
    } else {
      return 'DIRECT';
    }
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      'type': type.toString().split('.').last.toUpperCase(),
      if (user != null) 'user': user,
      if (pass != null) 'pass': pass,
    };
  }

  SentryProxy copyWith({
    String? host,
    int? port,
    SentryProxyType? type,
    String? user,
    String? pass,
  }) =>
      SentryProxy(
        host: host ?? this.host,
        port: port ?? this.port,
        type: type ?? this.type,
        user: user ?? this.user,
        pass: pass ?? this.pass,
      );
}

enum SentryProxyType {
  direct,
  http,
  socks;
}
