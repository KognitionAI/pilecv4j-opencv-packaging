#!/bin/bash

if [ "$OPENCV_INSTALL" = "" ]; then
    echo "OPENCV_INSTALL must be set to point to the path where OpenCV is installed."
    exit 1
fi

if [ ! -d "$OPENCV_INSTALL" ]; then
    echo "\"$OPENCV_INSTALL\" doesn't exist or isn't a directory."
    exit 1
fi

OPENCV_MAKE="$OPENCV_INSTALL/share/OpenCV/OpenCVConfig-version.cmake"
if [ ! -f "$OPENCV_MAKE" ]; then
    OPENCV_MAKE="$OPENCV_INSTALL/build/OpenCVConfig-version.cmake"
    if [ ! -f "$OPENCV_MAKE" ]; then
        echo "Can't find the build file \"$OPENCV_INSTALL/share/OpenCV/OpenCVConfig-version.cmake\" or \"$OPENCV_INSTALL/build/OpenCVConfig-version.cmake\" in order to extract the version."
        exit 1
    fi
fi

if [ "$MVN" = "" ]; then
    MVN=mvn
fi

if [ "$GIT" = "" ]; then
    GIT=git
fi

OPENCV_VERSION=`grep OpenCV_VERSION "$OPENCV_MAKE" | head -1 | sed -e 's/^.*set(.*OpenCV_VERSION *//g' | sed -e 's/).*$//g'`
OPENCV_SHORT_VERSION=`echo "$OPENCV_VERSION" | sed -e 's/\.//g'`

echo "==========================================="
echo "Building with:"
echo "OPENCV_INSTALL=$OPENCV_INSTALL"
echo "OPENCV_VERSION=$OPENCV_VERSION"
echo "OPENCV_SHORT_VERSION=$OPENCV_SHORT_VERSION"
echo "==========================================="

echo ""
echo "Setting version in the project."

$MVN versions:set -DnewVersion=$OPENCV_VERSION
if [ "$?" -ne 0 ]; then
    echo "Failed to set version. Please manually reset the project using \"git reset --hard HEAD\""
    exit 1
fi

export OPENCV_VERSION
export OPENCV_SHORT_VERSION
export OPENCV_INSTALL

$MVN clean install
if [ "$?" -ne 0 ]; then
    echo "Failed to install packaged opencv.Please manually reset the project using \"git reset --hard HEAD\""
    exit 1
fi

$GIT reset --hard HEAD
$GIT clean -dxf
