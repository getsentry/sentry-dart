Pod::Spec.new do |s|
  s.name             = 'sentry_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Sentry SDK for Flutter.'
  s.description      = <<-DESC
Sentry SDK for Flutter with support to native through sentry-cocoa.
                       DESC
  s.homepage         = 'https://sentry.io'
  s.license          = { :file => '../LICENSE' }
  s.authors          = "Sentry"
  s.source           = { :git => "https://github.com/getsentry/sentry-dart.git",
                         :tag => s.version.to_s }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Sentry', '~> 7.0.3'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.11'
  
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
