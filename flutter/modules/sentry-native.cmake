set(SENTRY_SDK_NAME "sentry.native.flutter" CACHE STRING "The SDK name to report when sending events." FORCE)
set(SENTRY_BACKEND "inproc" CACHE STRING "The sentry backend responsible for reporting crashes" FORCE)
set(SENTRY_BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libraries (.dll/.so) instead of static ones (.lib/.a)" FORCE)
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/sentry-native" "${CMAKE_CURRENT_BINARY_DIR}/sentry-native")
