#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint sentry_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'sentry_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Sentry for Flutter'
  s.description      = <<-DESC
  Sentry SDK for Flutter. This package aims to support different Flutter targets
  by relying on the many platforms supported by Sentry with native SDKs.
                       DESC
  s.homepage         = 'https://sentry.io'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'sdks@sentry.io' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
