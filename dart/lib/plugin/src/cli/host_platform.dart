enum HostPlatform {
  darwinUniversal,
  linux64bit,
  linuxArmv7,
  linuxAarch64,
  windows32bit,
  windows64bit,
}

extension HostPlatformUtils on HostPlatform {
  get executableExtension =>
      (this == HostPlatform.windows32bit || this == HostPlatform.windows64bit)
          ? '.exe'
          : '';
}
