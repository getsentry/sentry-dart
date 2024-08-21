load_cache("${CMAKE_CURRENT_LIST_DIR}" READ_WITH_PREFIX SENTRY_NATIVE_ repo version)
message(STATUS "Sentry native version: ${SENTRY_NATIVE_version} from ${SENTRY_NATIVE_repo}")

set(SENTRY_SDK_NAME "sentry.native.flutter" CACHE STRING "The SDK name to report when sending events." FORCE)
set(SENTRY_BACKEND "inproc" CACHE STRING "The sentry backend responsible for reporting crashes" FORCE)
set(SENTRY_BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libraries (.dll/.so) instead of static ones (.lib/.a)" FORCE)

include(FetchContent)
FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY ${SENTRY_NATIVE_repo}
    GIT_TAG ${SENTRY_NATIVE_version}
)

FetchContent_MakeAvailable(sentry-native)
