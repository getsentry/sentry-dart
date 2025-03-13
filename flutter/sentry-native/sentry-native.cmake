load_cache("${CMAKE_CURRENT_LIST_DIR}" READ_WITH_PREFIX SENTRY_NATIVE_ repo version)
message(STATUS "Fetching Sentry native version: ${SENTRY_NATIVE_version} from ${SENTRY_NATIVE_repo}")

set(SENTRY_SDK_NAME "sentry.native.flutter" CACHE STRING "The SDK name to report when sending events." FORCE)
set(SENTRY_BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libraries (.dll/.so) instead of static ones (.lib/.a)" FORCE)

# Note: the backend is also set in linux/CMakeLists.txt and windows/CMakeLists.txt. This overwrites those if user sets an env var.
if("$ENV{SENTRY_NATIVE_BACKEND}" STREQUAL "")
    # Windows ARM64 currently has issues with crashpad so we opt for using breakpad
    if(WIN32 AND CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64")
        set(SENTRY_BACKEND "breakpad" CACHE STRING "The sentry backend responsible for reporting crashes" FORCE)
    else()
        set(SENTRY_BACKEND "crashpad" CACHE STRING "The sentry backend responsible for reporting crashes" FORCE)
    endif()
else()
    set(SENTRY_BACKEND $ENV{SENTRY_NATIVE_BACKEND} CACHE STRING "The sentry backend responsible for reporting crashes" FORCE)
endif()

include(FetchContent)
FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY ${SENTRY_NATIVE_repo}
    GIT_TAG ${SENTRY_NATIVE_version}
    EXCLUDE_FROM_ALL
)

FetchContent_MakeAvailable(sentry-native)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an external build triggered from this build file.
if(SENTRY_BACKEND STREQUAL "crashpad")
    if(WIN32)
        set(sentry_flutter_bundled_libraries
            $<TARGET_FILE:crashpad_handler>
            $<TARGET_FILE:crashpad_wer>
            PARENT_SCOPE)
    else()
        set(sentry_flutter_bundled_libraries
            $<TARGET_FILE:crashpad_handler>
            PARENT_SCOPE)
    endif()
else()
    set(sentry_flutter_bundled_libraries "" PARENT_SCOPE)
endif()

# `*_plugin` is the name of the plugin library as expected by flutter.
# We don't actually need a plugin here, we just need to get the native library linked
# The following generated code achieves that:
# https://github.com/flutter/flutter/blob/ebfaa45c7d23374a7f3f596adea62ae1dd4e5845/packages/flutter_tools/lib/src/flutter_plugins.dart#L591-L596
add_library(sentry_flutter_plugin ALIAS sentry)
