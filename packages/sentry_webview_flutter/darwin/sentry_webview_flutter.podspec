Pod::Spec.new do |s|
  s.name = 'sentry_webview_flutter'
  s.version = '0.0.1'
  s.summary = 'Sentry integration for webview_flutter.'
  s.homepage = 'https://github.com/getsentry/sentry-dart'
  s.license = { :type => 'MIT', :file => '../LICENSE' }
  s.author = 'Sentry'
  s.source = { :git => 'https://github.com/getsentry/sentry-dart.git' }
  s.source_files = 'sentry_webview_flutter/Sources/sentry_webview_flutter/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
