#!/bin/bash

usage() {
    echo "usage: [MVN=/path/to/mvn] OPENCV_SHORT_VERSION=[short ver. e.g. 340] OPENCV_INSTALL=[path to install] $0"
    exit 1
}


##################################################
# preamble
set -e
cd "$(dirname "$0")"
SCRIPTDIR="$(pwd -P)"
##################################################

if [ "$MVN" = "" ]; then
    MVN=mvn
fi

if [ "$OPENCV_SHORT_VERSION" = "" -o "$OPENCV_INSTALL" = "" ]; then
    usage
fi

export LIB_DIR="$OPENCV_INSTALL"/lib
export OPENCV_INSTALL
export OPENCV_SHORT_VERSION

cd ../lib-image-native/
$MVN clean install
cd -

set +e
rm -rf src/main/cpp/build/
set -e

mkdir -p src/main/cpp/build/build
mkdir -p src/main/cpp/build/lib

cp ../lib-image-native/target/lib-image-native-0.jar src/main/cpp/build/lib

cd src/main/cpp/build/build

PROJECT_VERSION=0 cmake ../..



