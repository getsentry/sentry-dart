Map<String, String> buildHeaders({String sdkIdentifier}) {
  return {
    'Content-Type': 'application/json',
    // NOTE(lejard_h) overriding user agent on VM and Flutter not sure why
    // for web it use browser user agent
    'User-Agent': sdkIdentifier
  };
}
