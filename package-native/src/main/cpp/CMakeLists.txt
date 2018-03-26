cmake_minimum_required (VERSION 3.4)
project (utilities.jiminger.com)

set(CMAKE_VERBOSE_MAKEFILE ON)

set (CMAKE_CXX_STANDARD 11)

if(UNIX)
  add_definitions(-DUNIX)
endif()

include_directories($ENV{OPENCV_INSTALL}/include)

add_library(lib-image-native.jiminger.com
	MODULE sources/CvRasterNative.cpp)

find_library(OPENCV_JAVA_LIB opencv_java$ENV{OPENCV_SHORT_VERSION} HINTS $ENV{LIB_DIR} )

target_link_libraries(lib-image-native.jiminger.com ${OPENCV_JAVA_LIB})
