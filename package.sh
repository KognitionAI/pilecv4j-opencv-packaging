#!/bin/bash

usage() {
    echo "usage: [MVN=[path to maven]] OPENCV_INSTALL=[path to opencv install] ./package.sh [-r] [--deploy] [--version deploy-version]"
    echo "    if MVN isn't set then the script assumes \"mvn\" is on the command line PATH"
    echo "    OPENCV_INSTALL must be defined"
    echo ""
    echo "  -r        : Reset the checked out git code after a successful completion. Otherwise just put back the version to 0"
    echo "              IMPORTANT NOTE!!!: If you made an chagnes to the checked out code, selecting -r will have it all "
    echo "              reversed upon successful completion of this script."
    echo "  --deploy  : do a \"mvn deploy\" as part of building."
    echo "  --offline : Pass -o to maven."
    echo "  --version : Supply the version explicitly. This is to allow extended versions of opencv. E.g. \"3.4.3-cuda9.2\""
    echo "  --zip /path/to/zip: Create a zip file of the final installed directory with the headers and libraries."
    echo "  --deploy-zip: Deploy the zip file created with the --zip option."
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
OPENCV_MAKE="$(find "$OPENCV_INSTALL"/ -name OpenCVConfig-version.cmake | head -1)"

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
# Setup some platform specifics
###############################################################
OS=`uname`

WINDOWS=
if [ "$(echo "$OS" | grep MINGW)" != "" ]; then
    PLAT=MINGW
    WINDOWS=true
elif [ "$(echo "$OS" | grep MSYS)" != "" ]; then
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
    echo "      2) Linux"
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
RESET=
MVN_TARGET=install
DEPLOY_VERSION=
ZIPUP=
MVN_OFFLINE=
DEPLOY_ZIP=

while [ $# -gt 0 ]; do
    case "$1" in
        "-r")
            RESET=true
            shift
            ;;
        "--deploy")
            MVN_TARGET=deploy
            shift
            ;;
        "--deploy-zip")
            DEPLOY_ZIP="-P deploy-opencv-dist-zip"
            shift
            ;;
        "--offline")
            MVN_OFFLINE=-o
            shift
            ;;
        "--version")
            DEPLOY_VERSION="$2"
            shift
            shift
            ;;
        "--zip")
            ZIPUP=$2
            shift
            shift
            ;;
        *)
            usage
            ;;
    esac
done

# consistency checks
if [ "$DEPLOY_ZIP" != "" -a "$ZIPUP" = "" ]; then
    echo "ERROR: You specified --deploy-zip but didn't specify --zip."
    usage
fi

OPENCV_VERSION=`grep OpenCV_VERSION "$OPENCV_MAKE" | head -1 | sed -e 's/^.*set(.*OpenCV_VERSION *//g' | sed -e 's/).*$//g'`
OPENCV_SHORT_VERSION=`echo "$OPENCV_VERSION" | sed -e 's/\.//g'`

OPENCV_JAVA_JAR="opencv-$OPENCV_SHORT_VERSION.jar"
OPENCV_JAVA_INSTALL_ROOT="$(cwpath "$(dirname "$(find "$OPENCV_INSTALL" -name "$OPENCV_JAVA_JAR" -type f)")")"

if [ "$DEPLOY_VERSION" = "" ]; then
    DEPLOY_VERSION="$OPENCV_VERSION"
fi

echo "==========================================="
echo "Building with:"
echo "OPENCV_INSTALL=$OPENCV_INSTALL"
echo "OPENCV_VERSION=$OPENCV_VERSION"
echo "OPENCV_SHORT_VERSION=$OPENCV_SHORT_VERSION"
echo "OPENCV_JAVA_INSTALL_ROOT=$OPENCV_JAVA_INSTALL_ROOT"
echo "DEPLOY_VERSION=$DEPLOY_VERSION"
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

# if we're on linux, and execstack is installed, then we want to fixup the opencv_${shortversion} library
if [ "Linux" = "$PLAT" ]; then
    type execstack
    if [ $? -eq 0 ]; then
        JAVA_SHARED_LIB=`ls "$OPENCV_LIBS_PATH"/libopencv_java*.so | head -1`
        if [ -f "$JAVA_SHARED_LIB" ]; then
            echo "Applying buffer overrun protection to \"$JAVA_SHARED_LIB\""
            execstack -c "$JAVA_SHARED_LIB"
        else
            echo "WARN: I should have been able to apply buffer overrun protection to the shared lib \"$JAVA_SHARED_LIB\" but I couldn't find it."
        fi
    else
        echo "NOT applying overrun protection. You should install 'execstack' using 'sudo apt-get install execstack'. Continuing..."
    fi
fi

cp "$OPENCV_INSTALL"/cmake.out "$OPENCV_LIBS_PATH"

echo "Files to package:"
ls -l "$OPENCV_LIBS_PATH"

echo "Setting version in the project."

$MVN -B $MVN_OFFLINE -Pinstall-jar-build versions:set -DnewVersion=$DEPLOY_VERSION
if [ "$?" -ne 0 ]; then
    echo "Failed to set version. Please manually reset the project using \"git reset --hard HEAD\""
    exit 1
fi

export OPENCV_SHORT_VERSION
export OPENCV_INSTALL
export OPENCV_JAVA_INSTALL_ROOT

$MVN -B $MVN_OFFLINE -Pinstall-jar-build clean install

if [ "$?" -ne 0 ]; then
    echo "Failed to install packaged opencv. Please manually reset the project using \"git reset --hard HEAD\""
    exit 1
fi

if [ "$MVN_TARGET" = "deploy" ]; then
    cd package-native
    $MVN -B $MVN_OFFLINE clean deploy
    cd ..
fi

if [ "$RESET" = "true" ]; then
    $GIT reset --hard HEAD
    $GIT clean -dxf
else
    $MVN -B versions:set -DnewVersion=0
fi

if [ "$ZIPUP" != "" ]; then
    if [ -f "$ZIPUP" ]; then
        rm "$ZIPUP"
    fi

    ZIP_PATH="$(realpath "$ZIPUP")"
    set -e
    cd "$OPENCV_INSTALL"
    set +e
    
    zip -y -r "$ZIP_PATH" ./

    if [ $? -ne 0 ]; then
        echo "The zipping of the opencv install seems to have failed."
        exit 1
    fi

    cd -

    set -e
    cd opencv-zip-install
    MVN_ZIP_TARGET=install
    if [ "$DEPLOY_ZIP" != "" ]; then
        MVN_ZIP_TARGET=deploy
    fi
    "$MVN" -B $MVN_OFFLINE -Dopencv-zip-path="$ZIP_PATH" -Dopencv-zip-version=$DEPLOY_VERSION clean $MVN_ZIP_TARGET $DEPLOY_ZIP
    set +e
fi
