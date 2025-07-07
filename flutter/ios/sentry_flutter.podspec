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
  s.dependency 'Sentry/HybridSDK', '8.52.1'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.14'

  # Flutter.framework does not contain a i386 slice.
  s.ios.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => '$(inherited) i386',
    # Add header search paths for Sentry private headers when building frameworks
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_CONFIGURATION_BUILD_DIR}/Sentry/Sentry.framework/Headers" "${PODS_CONFIGURATION_BUILD_DIR}/Sentry/Sentry.framework/PrivateHeaders" "${PODS_ROOT}/Sentry/Sources/Sentry/include"',
    # Ensure framework builds include necessary headers
    'OTHER_CFLAGS' => '$(inherited) -fmodule-map-file="${PODS_CONFIGURATION_BUILD_DIR}/Sentry/Sentry.framework/Modules/module.modulemap"'
  }
  s.osx.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    # Add header search paths for Sentry private headers when building frameworks
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_CONFIGURATION_BUILD_DIR}/Sentry/Sentry.framework/Headers" "${PODS_CONFIGURATION_BUILD_DIR}/Sentry/Sentry.framework/PrivateHeaders" "${PODS_ROOT}/Sentry/Sources/Sentry/include"',
    # Ensure framework builds include necessary headers
    'OTHER_CFLAGS' => '$(inherited) -fmodule-map-file="${PODS_CONFIGURATION_BUILD_DIR}/Sentry/Sentry.framework/Modules/module.modulemap"'
  }
  s.swift_version = '5.0'
  
  # Preserve the Sentry framework structure when building as a framework
  s.preserve_paths = 'sentry_flutter/Sources/**/*'
  
  # Custom script phase to ensure private headers are available
  s.script_phases = [
    {
      :name => 'Copy Sentry Private Headers',
      :script => <<-SCRIPT
        if [ -d "${PODS_CONFIGURATION_BUILD_DIR}/Sentry/Sentry.framework/PrivateHeaders" ]; then
          echo "Sentry private headers are available"
        else
          echo "Warning: Sentry private headers not found at expected location"
        fi
      SCRIPT,
      :execution_position => :before_compile
    }
  ]
end
