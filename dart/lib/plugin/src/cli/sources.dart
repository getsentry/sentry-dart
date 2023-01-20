class CLISource {
  final Uri downloadUrl;
  final String hash;

  CLISource(String downloadUrl, this.hash)
      : downloadUrl = Uri.parse(downloadUrl);
}

// TODO after increasing min dart SDK version to 2.13.0
// typedef CLISources = Map<HostPlatform, CLISource>;
