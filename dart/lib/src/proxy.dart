class Proxy {
  final ProxyType type;
  final String? host;
  final String? port;
  final String? user;
  final String? pass;

  Proxy({required this.type, this.host, this.port, this.user, this.pass});

  String toPacString() {
    String type = 'DIRECT';
    switch (this.type) {
      case ProxyType.direct:
        return 'DIRECT';
      case ProxyType.http:
        type = 'PROXY';
        break;
      case ProxyType.socks:
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

  Proxy copyWith({
    String? host,
    String? port,
    ProxyType? type,
    String? user,
    String? pass,
  }) =>
      Proxy(
        host: host ?? this.host,
        port: port ?? this.port,
        type: type ?? this.type,
        user: user ?? this.user,
        pass: pass ?? this.pass,
      );
}

enum ProxyType {
  direct,
  http,
  socks;
}
