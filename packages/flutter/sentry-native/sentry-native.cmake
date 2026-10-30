load_cache("${CMAKE_CURRENT_LIST_DIR}" READ_WITH_PREFIX SENTRY_NATIVE_ repo version sha256)

# How sentry-native sources are fetched:
#   git             - FetchContent git clone with submodules (default)
#   git-longpaths   - same, with core.longpaths=true passed to the clone
#   git-shallow     - same, with GIT_SHALLOW
#   separate-gitdir - git clone with its git dir in a short temp dir, checked
#                     out directly into the build dir; the git dir is deleted
#   tempdir         - git clone into a short temp dir, drop .git, copy into
#                     the build dir
#   tempdir-move    - same, but move instead of copy where possible
#   zip             - download the release zip, which has no .git metadata
# All but git try to keep nested submodule git dirs from exceeding the Windows
# MAX_PATH limit for deep project paths.
# https://github.com/getsentry/sentry-dart/issues/3969
set(SENTRY_NATIVE_FETCH_METHOD "git")
if(NOT "$ENV{SENTRY_NATIVE_FETCH_METHOD}" STREQUAL "")
    set(SENTRY_NATIVE_FETCH_METHOD $ENV{SENTRY_NATIVE_FETCH_METHOD})
endif()
if(NOT SENTRY_NATIVE_FETCH_METHOD MATCHES "^(git|git-longpaths|git-shallow|separate-gitdir|tempdir|tempdir-move|zip)$")
    message(FATAL_ERROR "Unknown SENTRY_NATIVE_FETCH_METHOD '${SENTRY_NATIVE_FETCH_METHOD}', expected git, git-longpaths, git-shallow, separate-gitdir, tempdir, tempdir-move or zip")
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
if(SENTRY_NATIVE_FETCH_METHOD STREQUAL "zip")
    if(POLICY CMP0135)
        cmake_policy(SET CMP0135 NEW)
    endif()
    FetchContent_Declare(
        sn
        URL ${SENTRY_NATIVE_repo}/releases/download/${SENTRY_NATIVE_version}/sentry-native.zip
        URL_HASH SHA256=${SENTRY_NATIVE_sha256}
        EXCLUDE_FROM_ALL
    )
else()
    set(sentry_native_fetch_options)
    if(sentry_native_submodules)
        set(sentry_native_fetch_options GIT_SUBMODULES ${sentry_native_submodules})
    endif()
    if(SENTRY_NATIVE_FETCH_METHOD STREQUAL "git-longpaths")
        list(APPEND sentry_native_fetch_options GIT_CONFIG core.longpaths=true)
    elseif(SENTRY_NATIVE_FETCH_METHOD STREQUAL "git-shallow")
        list(APPEND sentry_native_fetch_options GIT_SHALLOW TRUE)
    endif()
    FetchContent_Declare(
        sn
        GIT_REPOSITORY ${SENTRY_NATIVE_repo}
        GIT_TAG ${SENTRY_NATIVE_version}
        ${sentry_native_fetch_options}
        EXCLUDE_FROM_ALL
    )
endif()

if(SENTRY_NATIVE_FETCH_METHOD MATCHES "^(separate-gitdir|tempdir|tempdir-move)$")
    include("${CMAKE_CURRENT_LIST_DIR}/sentry-native-tempdir.cmake")
    sentry_native_fetch_via_tempdir(${SENTRY_NATIVE_FETCH_METHOD})
endif()

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
