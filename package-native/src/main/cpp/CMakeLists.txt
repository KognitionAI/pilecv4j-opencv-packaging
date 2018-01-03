cmake_minimum_required (VERSION 3.4)
project (utilities.jiminger.com)

find_package(Java REQUIRED)
find_package(JNI REQUIRED)

include(UseJava)
set(CMAKE_JAVA_COMPILE_FLAGS "-source" "1.8" "-target" "1.8")

set (_stubDir "${CMAKE_CURRENT_BINARY_DIR}")
set (CMAKE_CXX_STANDARD 11)

if(UNIX)
  add_definitions(-DUNIX)
endif()


add_custom_command(
    OUTPUT com_jiminger_image_CvRasterNative.h
    COMMAND ${Java_JAVAH_EXECUTABLE} -verbose
        -classpath ../lib/lib-image-native-$ENV{PROJECT_VERSION}.jar
        -d ${_stubDir}
        -jni com.jiminger.image.CvRasterNative
    )

include_directories(${JNI_INCLUDE_DIRS} ${_stubDir} $ENV{OPENCV_INSTALL}/include)
add_library(lib-image-native.jiminger.com
	MODULE com_jiminger_image_CvRasterNative.h
               sources/CvRasterNative.cpp)

target_link_libraries(lib-image-native.jiminger.com ${JNI_LIBRARIES})
