class Proxy {
  final String? host;
  final String? port;
  final ProxyType? type;
  final String? user;
  final String? pass;

  Proxy({this.host, this.port, this.type, this.user, this.pass});

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (type != null) 'type': type.toString().split('.').last.toUpperCase(),
      if (user != null) 'user': user,
      if (pass != null) 'pass': pass,
    };
  }
}

enum ProxyType {
  direct,
  http,
  socks;
}
