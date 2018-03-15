#!/bin/bash

usage() {
    echo "usage: [MVN=[path to maven]] OPENCV_INSTALL=[path to opencv install] ./package.sh [-G \"cmake generator\"] [-r]"
    echo "    if MVN isn't set then the script assumes \"mvn\" is on the command line PATH"
    echo "    OPENCV_INSTALL must be defined"
    echo ""
    echo "  -r  : Reset the repository after a successful completion. Otherwise just put back the version to 0"
    exit 1
}

if [ "$OPENCV_INSTALL" = "" ]; then
    echo "OPENCV_INSTALL must be set to point to the path where OpenCV is installed."
    usage
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
            echo "$1"
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
CMAKE_GENERATOR=
RESET=
while [ $# -gt 0 ]; do
    case "$1" in
        "-G")
            CMAKE_GENERATOR="$2"
            shift
            shift
            ;;
        "-r")
            RESET=true
            shift
            ;;
        *)
            usage
            ;;
    esac
done

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

# remove any libs incompatible with this arch
BIT64="$(arch | grep 64)"
for lib in "$OPENCV_LIBS_PATH"/*; do
    # IS_ARCH will be non-empty if the lib belong on this arch
    if [ "$BIT64" != "" ]; then # 64 bit
        IS_ARCH="$(file "$lib" | grep -i "64")"
    else # 32 bit
        TMP="$(file "$lib" | grep -i "64")"
        if [ "$TMP" = "" ]; then
            IS_ARCH=true
        fi
    fi
    if [ "$IS_ARCH" = "" ]; then
        echo "removing \"$lib\" because it's from the wrong architecture."
        rm "$lib"
    fi
done

# find any import libs that go along with the dll.
LIBNAMES="$(find "$OPENCV_LIBS_PATH" -name "*.dll")"
for lib in $LIBNAMES; do
    IMPLIB="$(echo "$(basename "$lib")" | sed -e "s/\.dll$/\.lib/1")"
    echo "Searching for \"$IMPLIB\""
    find "$OPENCV_INSTALL" -name "$IMPLIB" -type f -exec cp {} "$OPENCV_LIBS_PATH" \;
done

echo "Files to package:"
ls -l "$OPENCV_LIBS_PATH"

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

if [ "$CMAKE_GENERATOR" != "" ]; then
    $MVN -Dgenerator="$CMAKE_GENERATOR" clean install
else
    $MVN clean install
fi

if [ "$?" -ne 0 ]; then
    echo "Failed to install packaged opencv.Please manually reset the project using \"git reset --hard HEAD\""
    exit 1
fi

if [ "$RESET" = "true" ]; then
    $GIT reset --hard HEAD
    $GIT clean -dxf
else
    $MVN versions:set -DnewVersion=0
fi

