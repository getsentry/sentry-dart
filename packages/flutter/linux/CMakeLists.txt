# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

set(SENTRY_BACKEND "crashpad" CACHE STRING "The sentry backend responsible for reporting crashes" FORCE)

include("../sentry-native/sentry-native.cmake")

# Even though sentry_flutter doesn't actually provide a useful plugin, we need to accommodate the Flutter tooling.
# sentry_flutter/sentry_flutter_plugin.h is included by the flutter-tool generated plugin registrar:
target_include_directories(sentry INTERFACE .)
