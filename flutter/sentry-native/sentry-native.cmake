load_cache("${CMAKE_CURRENT_LIST_DIR}" READ_WITH_PREFIX SENTRY_NATIVE_ repo version)
message(STATUS "Fetching Sentry native version: ${SENTRY_NATIVE_version} from ${SENTRY_NATIVE_repo}")

set(SENTRY_SDK_NAME "sentry.native.flutter" CACHE STRING "The SDK name to report when sending events." FORCE)
set(SENTRY_BACKEND "crashpad" CACHE STRING "The sentry backend responsible for reporting crashes" FORCE)
set(SENTRY_BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libraries (.dll/.so) instead of static ones (.lib/.a)" FORCE)

include(FetchContent)
FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY ${SENTRY_NATIVE_repo}
    GIT_TAG ${SENTRY_NATIVE_version}
    EXCLUDE_FROM_ALL
)

FetchContent_MakeAvailable(sentry-native)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(sentry_flutter_bundled_libraries
    $<TARGET_FILE:crashpad_handler>
    PARENT_SCOPE
)

# `*_plugin` is the name of the plugin library as expected by flutter.
# We don't actually need a plugin here, we just need to get the native library linked
# The following generated code achieves that:
# https://github.com/flutter/flutter/blob/ebfaa45c7d23374a7f3f596adea62ae1dd4e5845/packages/flutter_tools/lib/src/flutter_plugins.dart#L591-L596
add_library(sentry_flutter_plugin ALIAS sentry)
