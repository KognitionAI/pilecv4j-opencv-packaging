#!/bin/bash

if [ "$VERBOSE" != "" ]; then
    set -x
fi

MIN_MAJOR_VER=3
MIN_MINOR_VER=4
TO_PATCH_VER=3.4.0

# =============================================================================
# Preamble
# =============================================================================
set -e
MAIN_DIR="$(dirname "$BASH_SOURCE")"
cd "$MAIN_DIR"
PROJDIR="$(pwd -P)"

OS=`uname`

# Platform specifics
WINDOWS=
set +e
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
set -e

if [ "$WINDOWS" = "true" ]; then
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

sgrep() {
    set +e
    grep "$@"
    set -e
}

segrep() {
    set +e
    egrep "$@"
    set -e
}


# Determine arch automatically for Windows so you don't need to specify it in the generator
OS_SPECIFIC_CMAKE_OPTIONS=
CMAKE_ARCH=
if [ "$WINDOWS" = "true" ]; then
    if [ "$(arch | sgrep 64)" != "" ]; then
        CMAKE_ARCH="-Ax64"
    fi
    OS_SPECIFIC_CMAKE_OPTIONS="-DBUILD_WITH_STATIC_CRT=ON"
fi
# =============================================================================

DEFAULT_WORKING_DIRECTORY=/tmp/opencv-working

usage() {
    echo "[GIT=/path/to/git/binary/git] [JAVA_HOME=/path/to/java/jdk/root] [MVN=/path/to/mvn/mvn] [CMAKE=/path/to/cmake/cmake] $BASH_SOURCE -v opencv-version [options]"
    echo "    -v  opencv-version: This needs to be specified. e.g. \"-v 3.4.2\""
    echo "    --install-prefix|-i /path/to/install/opencv : Install opencv to the given path."
    echo " Options:"
    echo "    -w /path/to/workingDirectory: this is $DEFAULT_WORKING_DIRECTORY by default."
    echo "    -jN: specify the number of threads to use when running make. If the cmake-generator is"
    echo "       Visual Studio then this translates to /m option to \"msbuild\""
    echo "    -G cmake-generator: specifially specify the cmake generator to use. The default is chosen otherwise."
    echo "    --zip /path/to/zip: Create a zip file of the final installed directory with the headers and libraries."
    echo ""
    echo "    --help|-help: print this message"
    echo "    --skip-checkout: This will \"skip the checkout\" of the opencv code. If you're playing with different"
    echo "       options then once the code is checked out, using --skip-checkout will allow subsequent runs to progress"
    echo "       faster. This doesn't work unless the working directory remains the same between runs."
    echo "    --skip-packaging: Skip the packaging step. That is, only build opencv and opencv_contrib libraries but"
    echo "       don't package them in a jar file for use with net.dempsy.util.library.NativeLivbraryLoader"
    echo "    --deploy: perform a \"mvn deploy\" rather than just a \"mvn install\""
    echo "    --offline: Pass -o to maven."
    echo ""
    echo " Build Options"
    echo "    --static(default)|--no-static: force the build to statically link (dynamically link for \"--no-static\")"
    echo "        the JNI libraries. By default, the JNI library is statically linked on all platform builds."
    echo "    --build-python: Build python3 wrappers. By default, the script blocks building the Python wrappers. If"
    echo "        you want to build them anyway you can specify \"--build-python\" or \"--build-python-3\"."
    echo "    --build-python-2: Build python2 wrappers. By default, the script blocks building the Python wrappers."
    echo "        This is mutually exclusive with \"--build-python\"."
    echo "    --build-samples: Build the OpenCV samples also."
    echo "    --build-cuda-support: Build the OpenCV using NVidia's CUDA (Note: CUDA must already be installed, this"
    echo "        option is untested on Windows)."
    echo "    --build-qt-support: Build the OpenCV using QT as the GUI implementation (Note: QT5 Must already be"
    echo "        installed, this option is untested on Windows)."
    echo "    --no-dnn: disable opencv's DNN support. As a note, OpenCV's DNN seems to conflict with Caffee. Disabling"
    echo "        OpenCV's DNN also means that DNN Object detection and the contrib module \"text\" is also disabled,"
    echo "        as is potentially other modules that depend on opencv's DNN support."
    echo "    --build-protobuf: This option will enable OpenCV's internal build of protobuf. While the raw OpenCV build"
    echo "        defaults to building this, this script defaults to blocking it since it tends to conflict with"
    echo "        other systems that also rely on protobufs. NOT selecting this option implies protobuf will need to be"
    echo "        installed on your build machine."
    echo "    --with-tbb: This option will build OpenCV using libtbb. It's assumed that libtbb-dev is installed."
    echo ""
    echo "    if GIT isn't set then the script assumes \"git\" is on the command line PATH"
    echo "    if MVN isn't set then the script assumes \"mvn\" is on the command line PATH"
    echo "    if CMAKE isn't set then the script assumes \"cmake\" is on the command line PATH"
    echo "    if JAVA_HOME isn't set then the script will locate the \"java\" executable on the PATH"
    echo "      and will attempt infer the JAVA_HOME environment variable from there."
    echo ""
    echo "    If you set the environment variable \"VERBOSE=1\" then you will get script debugging output as well as"
    echo "        verbose 'make' output."
    echo "    To build against an externally built, non-system installed, version of Protobuf's (only needed for DNN)"
    echo "       you set/append to the environment variable \"CMAKE_PREFIX_PATH\" to point to the root of the Protobuf"
    echo "       install."
    if [ $# -gt 0 ]; then
        exit $1
    else
        exit 1
    fi
}

WORKING_DIR="$DEFAULT_WORKING_DIRECTORY"
OPENCV_VERSION=
PARALLEL_BUILD=
CMAKE_GENERATOR_OPT=
SKIPC=
SKIPP=
BUILD_SHARED="-DBUILD_SHARED_LIBS=OFF -DBUILD_FAT_JAVA_LIB=ON"
BUILD_PYTHON="-DBUILD_opencv_python2=OFF -DBUILD_opencv_python3=OFF -DBUILD_opencv_python_bindings_generator=OFF"
DEPLOY_ME=
BUILD_SAMPLES=
BUILD_CUDA=
BUILD_QT=
ZIPUP=
OFFLINE=

# The default is to build the DNN. This variable is set when we disable building the DNN
BUILD_DNN=
# default for use is to NOT build the internal protobuf
BUILD_PROTOBUF="-DBUILD_PROTOBUF=OFF -DPROTOBUF_UPDATE_FILES=ON"
INSTALL_PREFIX=
WITH_TBB=

while [ $# -gt 0 ]; do
    case "$1" in
        "-w")
            WORKING_DIR=$2
            shift
            shift
            ;;
        "-i"|"--install-prefix")
            INSTALL_PREFIX=$2
            shift
            shift
            ;;
        "-v")
            OPENCV_VERSION=$2
            shift
            shift
            ;;
        "--zip")
            ZIPUP=$2
            shift
            shift
            ;;
        -j*)
            PARALLEL_BUILD="$1"
            shift
            ;;
        "-G")
            CMAKE_GENERATOR_OPT="-G \"$2\""
            shift
            shift
            ;;
        "-sc"|"--skip-checkout")
            SKIPC=true
            shift
            ;;
        "-sp"|"--skip-packaging")
            SKIPP=true
            shift
            ;;
        "-static"|"--static")
            shift
            ;;
        "-no-static"|"--no-static")
            # BUILD_SHARED should already be set
            shift
            ;;
        "-bp"|"--build-python"|"-bp3"|"--build-python-3")
            BUILD_PYTHON="-DBUILD_opencv_python2=OFF -DBUILD_opencv_python3=ON -DBUILD_opencv_python_bindings_generator=ON"
            shift
            ;;
        "-bp2"|"--build-python-2")
            BUILD_PYTHON="-DBUILD_opencv_python2=ON -DBUILD_opencv_python3=OFF -DBUILD_opencv_python_bindings_generator=OFF"
            shift
            ;;
        "--deploy")
            DEPLOY_ME="--deploy"
            shift
            ;;
        "--offline")
            OFFLINE=--offline
            shift
            ;;
        "--build-samples")
            BUILD_SAMPLES="-DBUILD_EXAMPLES=ON"
            shift
            ;;
        "--build-cuda-support")
            # Explicity enable support for CUDA runtime, CUDA FFT support, CUDA linear algebra, and CUDA video decode.
            # CUDA_NVCC_FLAG explanation: The current OpenCV compilation mode is equal to default settings of system 
            # compiler. It usually C++98 (gnu++98) for Ubuntu/Fedora/etc. The NVCC flag is required when building 
            # using C++11 (rather than OpenCV's expected C++98) but should not cause problems when building on C++98. 
            # This change is relevant only for CUDA 9.0 or higher but should not effect 8.X builds.
            #
            # Since cuda 10 opencv doesn't compile without disabling cudacodec since it's deprecated.
            BUILD_CUDA="-DWITH_CUDA=ON -DCUDA_NVCC_FLAGS=--expt-relaxed-constexpr -DWITH_CUFFT=ON -DWITH_CUBLAS=ON -DWITH_NVCUVID=ON -DBUILD_opencv_cudacodec=OFF"
            shift
            ;;
        "--build-qt-support")
            BUILD_QT="-DWITH_QT=ON"
            shift
            ;;
        "--no-dnn")
            # These clash with an independent build of caffe. dnn_objdetect and text are dependent on dnn
            BUILD_DNN="-DBUILD_opencv_dnn=OFF"
            shift
            ;;
        "--build-protobuf")
            BUILD_PROTOBUF="-DBUILD_PROTOBUF=ON"
            shift
            ;;
        "--with-tbb")
            WITH_TBB="-DWITH_TBB=ON"
            shift
            ;;
        "-help"|"--help"|"-h"|"-?")
            usage 0
            ;;
        *)
            echo "ERROR: Unknown option \"$1\""
            usage
            ;;
    esac
done

if [ "$OPENCV_VERSION" = "" ]; then
    echo "ERROR: you didn't specify and opencv version"
    usage
fi

MAJOR_VER="$(echo "$OPENCV_VERSION" | sed -e "s/\..*$//1")"
MINOR_VER="$(echo "$OPENCV_VERSION" | sed -e "s/^$MAJOR_VER\.//1" | sed -e "s/\..*$//1")"
PATCH_VER="$(echo "$OPENCV_VERSION" | sed -e "s/^$MAJOR_VER\.$MINOR_VER\.//1")"

# determine if this version is too old to build our native JNI code against.
TOO_OLD=
if [ $MIN_MAJOR_VER -gt $MAJOR_VER ]; then
    TOO_OLD="true"
elif [ $MIN_MAJOR_VER -eq $MAJOR_VER -a $MIN_MINOR_VER -gt $MINOR_VER ]; then
    TOO_OLD="true"
fi

if [ "$TOO_OLD" = "true" ]; then
    echo "WARNING: The version you're building ($OPENCV_VERSION) is lower than the minimum version allowed ($MIN_MAJOR_VER.$MIN_MINOR_VER.x) to build the ai.kognition.pilecv4j extentions."
    if [ "$SKIPP" != "true" ]; then
        echo "         if you want to continue bulding this version you must supply the \"-sp\" option in order to skip building the extenstion."
        exit 1
    fi
fi

PATCHME=
if [ "$TO_PATCH_VER" = "$OPENCV_VERSION" ]; then
    PATCHME=true
fi

mkdir -p "$WORKING_DIR"
if [ ! -d "$WORKING_DIR" ]; then
    echo "ERROR: \"$WORKING_DIR\" is not a valid directory."
    usage
fi

if [ "$INSTALL_PREFIX" = "" ]; then
    echo "ERROR: You must specify the --install-prefix option."
    usage
fi

# ========================================
# Make the WORKING_DIR an absolute path
cd "$WORKING_DIR"

# change working directory to absolute path
WORKING_DIR="$(pwd -P)"
# ========================================

# ========================================
# set and test git command
if [ "$GIT" = "" ]; then
    GIT=git
fi

set +e
"$GIT" --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot find \"$GIT\" command"
    usage
fi
set -e
# ========================================

# ========================================
# set and test git command
if [ "$CMAKE" = "" ]; then
    CMAKE=cmake
fi

set +e
"$CMAKE" --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot find \"$CMAKE\" command"
    usage
fi
set -e
# ========================================

# ========================================
# set and test mvn command
if [ "$MVN" = "" ]; then
    MVN=mvn
fi

set +e
"$MVN" --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot find \"$MVN\" command"
    usage
fi
set -e
# ========================================

# ========================================
# Attempt to caclulate JAVA_HOME if necessary
if [ "$JAVA_HOME" = "" ]; then
    TYPE_JAVA="$(type java 2> /dev/null)"
    if [ "$TYPE_JAVA" = "" ]; then
        echo "ERROR: There's no java command available and JAVA_HOME isn't set."
        usage
    fi

    # make sure 'readlink' works
    if [ "$(type readlink 2>/dev/null)" = "" ]; then
        echo "Can't use \"readlink\" from this shell. Either install it or explicitly set JAVA_HOME"
        usage
    fi

    JAVA_LOCATION="/$(echo "$TYPE_JAVA" | sed -e "s/^.* \///1")"
    while [ -L "$JAVA_LOCATION" ]; do
          JAVA_LOCATION="$(readlink "$JAVA_LOCATION")"
    done

    # java should be in a "bin" directory
    if [ "$(basename "$(dirname "$JAVA_LOCATION")")" = "bin" ]; then
        JAVA_HOME="$(dirname "$(dirname "$JAVA_LOCATION")")"
        echo "JAVA_HOME not set. It seems to be at $JAVA_HOME so I'm going with that."
        echo "JAVA_HOME :$JAVA_HOME"
    else
        echo "Can't automatically locate the correct JAVA_HOME. Please set it explicitly."
        usage
        
    fi
fi

export JAVA_HOME
# ========================================

# figure out the deploy version

# calculate the version
# find the cuda version
CUDA_VERSION=
if [ "$BUILD_CUDA" != "" ]; then
    if [ -f /usr/local/cuda/version.txt ]; then
        CUDA_VERSION="$(cat /usr/local/cuda/version.txt | sgrep -i cuda | sgrep -i version | tail -1 | sed -e "s/^.*[Vv]ersion //1" | segrep -o -e "^[0-9][0-9]*[0-9]*\.[0-9][0-9]*[0-9]*[0-9]*")"
    else
        NVCC_EXE=
        if [ "$(type nvcc 2>& | sgrep "not found")" != "" -a -x /usr/local/cuda/bin/nvcc ]; then
            NVCC_EXE=/usr/local/cuda/bin/nvcc
        else
            NVCC_EXE=nvcc
        fi
        if [ "$NVCC_EXEC" != "" ]; then
            CUDA_VERSION="$($NVCC_EXEC --version | segrep -e ", V[0-9][0-9]*[0-9]*[0-9]*\." | sed -e "s/^.*, V//1" | sed -E "s/\.[0-9][0-9]*[0-9]*[0-9]*[0-9]*[0-9]*[0-9]*$//1")"
        else
            echo "WARNING: Can't calculate the cuda version."
        fi
    fi
    CUDA_VERSION="-cuda$CUDA_VERSION"
fi

DEPLOY_VERSION="$OPENCV_VERSION$CUDA_VERSION"

#=========================================
# Comment out the actual build by including the next line
#if [ "Yo" = "" ]; then
#=========================================

# ========================================
# Checkout everything and switch to the correct tag
# remove these even if we're skipping the checkout
if [ -d "$WORKING_DIR/build" ]; then
    rm -rf "$WORKING_DIR/build"/* 2>/dev/null
fi
if [ -f "$WORKING_DIR/cmake.out" ]; then
    rm -rf "$WORKING_DIR/cmake.out"
fi
if [ -d "$WORKING_DIR/installed" ]; then
    rm -rf "$WORKING_DIR/installed"/* 2>/dev/null
fi

if [ "$SKIPC" != "true" ]; then
    # remove ONLY the expected generated files if they exist
    if [ -d "$WORKING_DIR/sources" ]; then
        rm -rf "$WORKING_DIR/sources"/* 2>/dev/null
    fi

    mkdir -p sources
    mkdir -p build

    cd sources

    "$GIT" clone https://github.com/opencv/opencv.git

    cd opencv
    "$GIT" checkout "$OPENCV_VERSION"
    if [ "$PATCHME" = "true" ]; then
        echo "Applying patch for building a FAT jar."
        # if it's not too old then apply the patch to build a fat jar
        git cherry-pick f3dde79ed6f5e17f16f4e2ad9669841e0dd6887c
    fi
    cd ..

    "$GIT" clone https://github.com/opencv/opencv_contrib.git

    cd opencv_contrib
    "$GIT" checkout "$OPENCV_VERSION"

    cd ..
else
    # we're still going to clean up the build directory
    mkdir -p "$WORKING_DIR"/build
fi
# ========================================

cd "$WORKING_DIR"/build

# Make sure cmake.out is removed because we need to grep it assuming it was empty/non-existent at the beginning of the run
if [ -f "$WORKING_DIR/cmake.out" ]; then
    set +e
    rm "$WORKING_DIR/cmake.out" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Couldn't remove \"$WORKING_DIR/cmake.out\" from a previous run. Can't continue."
        exit 1
    fi
    if [ -f "$WORKING_DIR/cmake.out" ]; then
        echo "Couldn't remove \"$WORKING_DIR/cmake.out\" from a previous run. Can't continue."
        exit 1
    fi
    set -e
fi

echo "JAVA_HOME: \"$JAVA_HOME\"" | tee "$WORKING_DIR/cmake.out"

if [ "$CMAKE_PREFIX_PATH" != "" ]; then
    echo "CMAKE_PREFIX_PATH is set to \"$CMAKE_PREFIX_PATH\"" | tee -a "$WORKING_DIR/cmake.out"
fi

BUILD_CMD=$(echo "\"$CMAKE\" $CMAKE_GENERATOR_OPT -DCMAKE_BUILD_TYPE=Release -DOPENCV_ENABLE_NONFREE:BOOL=ON -DCMAKE_INSTALL_PREFIX=\"$(cwpath "$INSTALL_PREFIX")\" -DOPENCV_EXTRA_MODULES_PATH=../sources/opencv_contrib/modules $BUILD_SHARED $BUILD_PYTHON $BUILD_SAMPLES $BUILD_CUDA $BUILD_QT $BUILD_DNN $BUILD_PROTOBUF $WITH_TBB -DENABLE_PRECOMPILED_HEADERS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_TESTS=OFF -DOPENCV_SKIP_VISIBILITY_HIDDEN=ON $OS_SPECIFIC_CMAKE_OPTIONS $CMAKE_ARCH ../sources/opencv")
echo "$BUILD_CMD" | tee -a "$WORKING_DIR/cmake.out"
eval "$BUILD_CMD" | tee -a "$WORKING_DIR/cmake.out"

# check cmake.out for the java wrappers
if [ "$(sgrep -A4 -- '--   Java:' "$WORKING_DIR/cmake.out" | sgrep -- '--     Java wrappers:' | sgrep YES)" = "" ]; then
    echo "ERROR: It appears that the JNI wrappers wont build in this configuration."
    echo "       Some common reasons include:"
    echo "          1) Ant isn't installed or on the path"
    echo "          2) The cmake build cannot find python."
    echo " Note: on Windows when using the Windows CMake (as opposed to the mingw cmake) \"ant\" needs to be on the Windows PATH"
    exit 1
fi

# Get the make command from the cmake output
MAKE="$(cpath "$(sgrep -- '--     CMake build tool:' "$WORKING_DIR/cmake.out" | sed -e "s/^.*CMake build tool: *//g")")"

if [ "$(echo "$MAKE" | sgrep -i msbuild)" != "" ]; then
    # We're on windows using Visual Studio
    INSTALL_TARGET=INSTALL.vcxproj
    RELEASE="-p:Configuration=Release"
    if [ "$PARALLEL_BUILD" != "" ]; then
        PARALLEL_BUILD="-m"
    fi
else
    # otherwise we're running MAKE
    INSTALL_TARGET=install
    RELEASE=
fi

echo "Building using:" | tee -a "$WORKING_DIR/cmake.out"
echo "\"$MAKE\" $PARALLEL_BUILD $INSTALL_TARGET $RELEASE" | tee -a "$WORKING_DIR/cmake.out"

"$MAKE" $PARALLEL_BUILD $INSTALL_TARGET $RELEASE

# HACK to repair incorrectly generate protobuf dependency
OCV_CMAKE_CONFIG=`find "$INSTALL_PREFIX" -name "OpenCVModules.cmake"`
DO_REPLACE_PROTOBUF_LINK=true
if [ "$OCV_CMAKE_CONFIG" = "" ]; then
    echo "WARNING: Cannot find the OpenCVModules.cmake so I cannot correct potention downstream Protobuf link dependency."
    DO_REPLACE_PROTOBUF_LINK=
fi

if [ $(echo "$OCV_CMAKE_CONFIG" | wc -l) -ne 1 ]; then
    echo "WARNING: There seeme to be more than one OpenCVModules.cmake in the install directory \"$INSTALL_PREFIX\""
    DO_REPLACE_PROTOBUF_LINK=
fi

if [ "$DO_REPLACE_PROTOBUF_LINK" = "true" ]; then
    cp "$OCV_CMAKE_CONFIG" /tmp
    cat /tmp/"$(basename "$OCV_CMAKE_CONFIG")" | sed -e "s/<LINK_ONLY:libprotobuf>/<LINK_ONLY:protobuf>/g" > "$OCV_CMAKE_CONFIG"
    rm /tmp/"$(basename "$OCV_CMAKE_CONFIG")"
fi


# if we're on linux, and execstack is installed, then we want to fixup the opencv_${shortversion} library
if [ "Linux" = "$PLAT" ]; then
    set +e
    type execstack
    if [ $? -eq 0 ]; then
        JAVA_SHARED_LIB=`find "$INSTALL_PREFIX" -name "libopencv_java*.so" | head -1`
        if [ -f "$JAVA_SHARED_LIB" ]; then
            echo "Applying buffer overrun protection to \"$JAVA_SHARED_LIB\""
            execstack -s "$JAVA_SHARED_LIB"
        else
            echo "WARN: I should have been able to apply buffer overrun protection to the shared lib \"$JAVA_SHARED_LIB\" but I couldn't find it."
        fi
    else
        echo "NOT applying overrun protection. You should install 'execstack' using 'sudo apt-get install execstack'. Continuing..."
    fi
    set -e
fi

#=========================================
# Comment out the actual build by including the next line
#fi
#=========================================

cd "$PROJDIR"

if [ "$SKIPP" != "true" ]; then
    if [ "$ZIPUP" != "" ]; then
        OPENCV_INSTALL="$INSTALL_PREFIX" ./package.sh $OFFLINE --version "$DEPLOY_VERSION" $DEPLOY_ME --zip "$ZIPUP"
    else 
        OPENCV_INSTALL="$INSTALL_PREFIX" ./package.sh $OFFLINE --version "$DEPLOY_VERSION" $DEPLOY_ME
    fi
fi

