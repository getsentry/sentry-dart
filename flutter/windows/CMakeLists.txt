# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Temporarily disabled due to https://github.com/getsentry/sentry-dart-plugin/issues/270
# include("${CMAKE_CURRENT_SOURCE_DIR}/../sentry-native/sentry-native.cmake")

# # Even though sentry_flutter doesn't actually provide a useful plugin, we need to accomodate the Flutter tooling.
# # sentry_flutter/sentry_flutter_plugin.h is included by the flutter-tool generated plugin registrar:
# target_include_directories(sentry INTERFACE ${CMAKE_CURRENT_LIST_DIR})

# Temp code: replace with the previous code when sentry-native is enabled
add_library(sentry_flutter_plugin temp.cpp)
target_include_directories(sentry_flutter_plugin INTERFACE ${CMAKE_CURRENT_LIST_DIR})
