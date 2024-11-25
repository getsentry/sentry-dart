cmake_minimum_required(VERSION 3.6)
project(sentry-sample LANGUAGES C CXX)

add_library(native-sample SHARED src/main/cpp/native-sample.cpp)

find_library(LOG_LIB log)

include (${ANDROID_GRADLE_NATIVE_BUNDLE_PLUGIN_MK})

target_link_libraries(
    native-sample PRIVATE
    ${LOG_LIB}
    ${ANDROID_GRADLE_NATIVE_MODULES}
)

# https://developer.android.com/guide/practices/page-sizes#compile-r26-lower
target_link_options(native-sample PRIVATE "-Wl,-z,max-page-size=16384")
