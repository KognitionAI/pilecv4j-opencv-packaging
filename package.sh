#!/bin/bash

if [ "$OPENCV_INSTALL" = "" ]; then
    echo "OPENCV_INSTALL must be set to point to the path where OpenCV is installed."
    exit 1
fi

if [ ! -d "$OPENCV_INSTALL" ]; then
    echo "\"$OPENCV_INSTALL\" doesn't exist or isn't a directory."
    exit 1
fi

# find the opencv make
OPENCV_MAKE="$(find "$OPENCV_INSTALL" -name OpenCVConfig-version.cmake | head -1)"

if [ ! -f "$OPENCV_MAKE" ]; then
    echo "ERROR: Couldn't find OpenCVConfig-version.cmake in any directory under \"$OPENCV_INSTALL\""
    exit 1
fi

if [ "$MVN" = "" ]; then
    MVN=mvn
fi

if [ "$GIT" = "" ]; then
    GIT=git
fi

###############################################################
# Setup some platforM specifics
###############################################################
OS=`uname`

WINDOWS=
if [ "$(echo "$OS" | grep MINGW)" != "" ]; then
    PLAT=MINGW
    WINDOWS=true
elif [ "$(echo "$OS" | grep CYGWIN)" != "" ]; then
    PLAT=CYGWIN
    WINDOWS=true
elif [ "$(echo "$OS" | grep Linux)" != "" ]; then
    PLAT=Linux
else
    echo "Sorry, I don't know how to handle building for \"$OS.\" Currently this works on:"
    echo "      1) Windows using MSYS2"
    echo "      2) Windows using Cygwin"
    echo "      3) Linux"
    exit 1
fi

BUILD_SHARED=
if [ "$WINDOWS" = "true" ]; then
    BUILD_SHARED="-DBUILD_SHARED_LIBS=false"

    cpath() {
        cygpath "$1"
    }

    if [ "$PLAT" = "CYGWIN" ]; then
        cwpath() {
            cygpath -w "$1"
        }
    else
        cwpath() {
            ehco "$1"
        }
    fi
else
    INSTALL_TARGET=install

    cpath() {
        echo "$1"
    }

    cwpath() {
        echo "$1"
    }
fi
###############################################################

OPENCV_VERSION=`grep OpenCV_VERSION "$OPENCV_MAKE" | head -1 | sed -e 's/^.*set(.*OpenCV_VERSION *//g' | sed -e 's/).*$//g'`
OPENCV_SHORT_VERSION=`echo "$OPENCV_VERSION" | sed -e 's/\.//g'`

OPENCV_JAVA_JAR="opencv-$OPENCV_SHORT_VERSION.jar"
OPENCV_JAVA_INSTALL_ROOT="$(cwpath "$(dirname "$(find "$OPENCV_INSTALL" -name "$OPENCV_JAVA_JAR" -type f)")")"

echo "==========================================="
echo "Building with:"
echo "OPENCV_INSTALL=$OPENCV_INSTALL"
echo "OPENCV_VERSION=$OPENCV_VERSION"
echo "OPENCV_SHORT_VERSION=$OPENCV_SHORT_VERSION"
echo "OPENCV_JAVA_INSTALL_ROOT=$OPENCV_JAVA_INSTALL_ROOT"
echo "==========================================="

# copy the libs into the project in a flat directory structure

OPENCV_LIBS_PATH=./package-native/src/temp/libs
echo ""
echo "Copying libs to \"$OPENCV_LIBS_PATH\""

mkdir -p "$OPENCV_LIBS_PATH"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create the directory to copy the libs into. \"$OPENCV_LIBS_PATH\""
    exit 1
fi

rm -rf "$OPENCV_LIBS_PATH"/* 2>/dev/null

find "$OPENCV_INSTALL" -name "*.dll" -type f -exec cp {} "$OPENCV_LIBS_PATH" \;
find "$OPENCV_INSTALL" -name "*.so" -type f -exec cp {} "$OPENCV_LIBS_PATH" \;

echo "Files to package:"
ls -l "$OPENCV_LIBS_PATH"

echo "Generating the properties file"
mkdir -p ./package-native/src/main/resources
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create the directory to generate the properties file. \"./package-native/src/main/resources\""
    exit 1
fi

rm -f ./package-native/src/main/resources/com.jiminger.lib.properties 2>/dev/null

LIBS=$(ls "$OPENCV_LIBS_PATH")

for lib in $LIBS; do
    echo "library.$lib=$lib" >> ./package-native/src/main/resources/com.jiminger.lib.properties
done

echo "com.jiminger.lib.properties is:"
cat ./package-native/src/main/resources/com.jiminger.lib.properties

echo "Setting version in the project."

$MVN versions:set -DnewVersion=$OPENCV_VERSION
if [ "$?" -ne 0 ]; then
    echo "Failed to set version. Please manually reset the project using \"git reset --hard HEAD\""
    exit 1
fi

export OPENCV_VERSION
export OPENCV_SHORT_VERSION
export OPENCV_INSTALL
export OPENCV_JAVA_INSTALL_ROOT

$MVN clean install
if [ "$?" -ne 0 ]; then
    echo "Failed to install packaged opencv.Please manually reset the project using \"git reset --hard HEAD\""
    exit 1
fi

$GIT reset --hard HEAD
$GIT clean -dxf
