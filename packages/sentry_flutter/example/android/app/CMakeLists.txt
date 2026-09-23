cmake_minimum_required(VERSION 3.6)
project(sentry-sample LANGUAGES C CXX)

# Link the prebuilt sentry-native shipped by io.sentry:sentry-native-ndk via Prefab.
find_package(sentry-native-ndk REQUIRED CONFIG)

add_library(native-sample SHARED src/main/cpp/native-sample.cpp)

find_library(LOG_LIB log)

target_link_libraries(
    native-sample PRIVATE
    ${LOG_LIB}
    sentry-native-ndk::sentry
)
