load_cache("${CMAKE_CURRENT_LIST_DIR}" READ_WITH_PREFIX SENTRY_NATIVE_ repo version sha256)

# How sentry-native sources are fetched:
#   git - FetchContent git clone with submodules (default, except on Windows)
#   zip - download the release zip, which has no .git metadata (default on
#         Windows). Falls back to git when the download fails; a hash
#         mismatch is an error.
# Nested submodule git dirs can exceed the Windows MAX_PATH limit for deep
# project paths, which the zip avoids.
# https://github.com/getsentry/sentry-dart/issues/3969
# Only Windows has the path length problem, so only it defaults to the zip.
if(WIN32)
    set(SENTRY_NATIVE_FETCH_METHOD "zip")
else()
    set(SENTRY_NATIVE_FETCH_METHOD "git")
endif()
if(NOT "$ENV{SENTRY_NATIVE_FETCH_METHOD}" STREQUAL "")
    set(SENTRY_NATIVE_FETCH_METHOD $ENV{SENTRY_NATIVE_FETCH_METHOD})
endif()
if(NOT SENTRY_NATIVE_FETCH_METHOD MATCHES "^(git|zip)$")
    message(FATAL_ERROR "Unknown SENTRY_NATIVE_FETCH_METHOD '${SENTRY_NATIVE_FETCH_METHOD}', expected git or zip")
endif()
message(STATUS "Fetching Sentry native version: ${SENTRY_NATIVE_version} from ${SENTRY_NATIVE_repo} (${SENTRY_NATIVE_FETCH_METHOD})")

set(SENTRY_SDK_NAME "sentry.native.flutter" CACHE STRING "The SDK name to report when sending events." FORCE)
set(SENTRY_BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libraries (.dll/.so) instead of static ones (.lib/.a)" FORCE)

set(SENTRY_BACKEND "breakpad" CACHE STRING "The sentry backend responsible for reporting crashes" FORCE)

if(NOT "$ENV{SENTRY_NATIVE_BACKEND}" STREQUAL "")
    # If environment variable is set, it takes highest precedence
    set(SENTRY_BACKEND $ENV{SENTRY_NATIVE_BACKEND} CACHE STRING "The sentry backend responsible for reporting crashes" FORCE)
endif()

# Avoid fetching Crashpad's nested Chromium dependencies for Breakpad builds.
# These can exceed Windows path limits even when Crashpad is not compiled.
# https://github.com/getsentry/sentry-dart/issues/3969
set(sentry_native_submodules)
if(SENTRY_BACKEND STREQUAL "breakpad")
    set(sentry_native_submodules external/breakpad)
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        list(APPEND sentry_native_submodules external/third_party/lss)
    endif()
endif()

include(FetchContent)
include("${CMAKE_CURRENT_LIST_DIR}/sentry-native-fetch.cmake")

if(SENTRY_NATIVE_FETCH_METHOD STREQUAL "zip")
    sentry_native_fetch_zip(zip_ok)
    if(NOT zip_ok)
        message(WARNING "Falling back to fetching sentry-native with git. On deep project paths this can fail with Windows path length errors, see https://github.com/getsentry/sentry-dart/issues/3969")
        set(SENTRY_NATIVE_FETCH_METHOD "git")
    endif()
endif()

set(sentry_native_fetch_options)
if(sentry_native_submodules)
    set(sentry_native_fetch_options GIT_SUBMODULES ${sentry_native_submodules})
endif()
# Also declared when the sources come from the zip, because
# FETCHCONTENT_SOURCE_DIR_SN overrides it but needs a declaration.
FetchContent_Declare(
    sn
    GIT_REPOSITORY ${SENTRY_NATIVE_repo}
    GIT_TAG ${SENTRY_NATIVE_version}
    ${sentry_native_fetch_options}
    EXCLUDE_FROM_ALL
)

# A short name keeps the _deps/sn-src and _deps/sn-build paths short (#3969).
FetchContent_MakeAvailable(sn)

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
