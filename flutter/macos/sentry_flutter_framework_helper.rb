# Helper script for sentry_flutter when building as a framework
# This ensures that private headers from the Sentry Cocoa SDK are available

def configure_sentry_for_framework_build(installer)
  installer.pods_project.targets.each do |target|
    if target.name == 'sentry_flutter'
      target.build_configurations.each do |config|
        # Add header search paths for Sentry private headers
        header_search_paths = config.build_settings['HEADER_SEARCH_PATHS'] ||= ['$(inherited)']
        
        sentry_headers = [
          '"${PODS_CONFIGURATION_BUILD_DIR}/Sentry/Sentry.framework/Headers"',
          '"${PODS_CONFIGURATION_BUILD_DIR}/Sentry/Sentry.framework/PrivateHeaders"',
          '"${PODS_ROOT}/Sentry/Sources/Sentry/include"',
          '"${PODS_ROOT}/Sentry/Sources/Sentry"'
        ]
        
        sentry_headers.each do |path|
          unless header_search_paths.include?(path)
            header_search_paths << path
          end
        end
        
        config.build_settings['HEADER_SEARCH_PATHS'] = header_search_paths
        
        # Ensure module maps are available
        other_cflags = config.build_settings['OTHER_CFLAGS'] ||= ['$(inherited)']
        module_flag = '-fmodule-map-file="${PODS_CONFIGURATION_BUILD_DIR}/Sentry/Sentry.framework/Modules/module.modulemap"'
        unless other_cflags.include?(module_flag)
          other_cflags << module_flag
        end
        config.build_settings['OTHER_CFLAGS'] = other_cflags
      end
    end
  end
end

# Function to copy required headers after pod install
def copy_sentry_private_headers_if_needed(pods_project_path)
  # This function can be called in a post_install hook to ensure headers are copied
  sentry_framework_path = File.join(pods_project_path, '../Pods/Sentry')
  
  if File.exist?(sentry_framework_path)
    puts "Sentry framework found, checking for private headers..."
    # Additional header copying logic can be added here if needed
  end
end