require 'yaml'
pubspec = YAML.load_file('./../pubspec.yaml')
version = pubspec['version'].to_s

Pod::Spec.new do |s|
  s.name             = 'sentry_flutter'
  s.version          = version
  s.summary          = 'Sentry SDK for Flutter.'
  s.description      = <<-DESC
Sentry SDK for Flutter with support to native through sentry-cocoa.
                       DESC
  s.homepage         = 'https://sentry.io'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.authors          = "Sentry"
  s.source           = { :git => "https://github.com/getsentry/sentry-dart.git",
                         :tag => s.version.to_s }
  s.source_files     = 'sentry_flutter/Sources/**/*'
  s.public_header_files = 'sentry_flutter/Sources/**/*.h'
  s.dependency 'Sentry/HybridSDK', '8.50.0'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.14'

  # Flutter.framework does not contain a i386 slice.
  s.ios.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => '$(inherited) i386' }
  s.osx.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
