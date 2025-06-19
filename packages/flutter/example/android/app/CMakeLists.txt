cmake_minimum_required(VERSION 3.6)
project(sentry-sample LANGUAGES C CXX)

include("../../../sentry-native/sentry-native.cmake")
add_library(native-sample SHARED src/main/cpp/native-sample.cpp)

find_library(LOG_LIB log)

target_link_libraries(
    native-sample PRIVATE
    ${LOG_LIB}
    sentry_flutter_plugin # Use the alias defined in sentry-native.cmake
)
