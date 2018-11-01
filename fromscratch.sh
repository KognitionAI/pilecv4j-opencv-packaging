#!/bin/bash

MIN_MAJOR_VER=3
MIN_MINOR_VER=4
TO_PATCH_VER=3.4.0

# =============================================================================
# Preamble
# =============================================================================
set -e
MAIN_DIR="$(dirname "$0")"
cd "$MAIN_DIR"
PROJDIR="$(pwd -P)"

OS=`uname`

# Platform specifics
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
set +e

# Determine arch automatically for Windows so you don't need to specify it in the generator
CMAKE_ARCH=
if [ "$WINDOWS" = "true" -a "$(arch | grep 64)" != "" ]; then
    CMAKE_ARCH="-Ax64"
fi
# =============================================================================

usage() {
    echo "[GIT=/path/to/git/binary/git] [JAVA_HOME=/path/to/java/jdk/root] [MVN=/path/to/mvn/mvn] [CMAKE=/path/to/cmake/cmake] $0 -v opencv-version [options]"
    echo "    -v:  opencv-version. This needs to be specified. e.g. \"-v 3.4.2\"" 
    echo " Options:"
    echo "    -w /path/to/workingDirectory: this is /tmp by default."
    echo "    -jN: specify the number of threads to use when running make. If the cmake-generator is"
    echo "       Visual Studio then this translates to /m option to \"msbuild\""
    echo "    -G cmake-generator: specifially specify the cmake generator to use. The default is chosen otherwise."
    echo "    --zip /path/to/zip: Create a zip file of the final installed directory with the headers and libraries."
    echo ""
    echo "    --help|-help: print this message"
    echo "    --skip-checkout: This will \"skip the checkout\" of the opencv code. If you're playing with different"
    echo "       options then once the code is checked out, using -sc will allow subsequent runs to progress faster."
    echo "       This doesn't work unless the working directory remains the same between runs."
    echo "    --skip-packaging: Skip the packaging step. That is, only build opencv and opencv_contrib libraries but"
    echo "       don't package them in a jar file for use with net.dempsy.util.library.NativeLivbraryLoader"
    echo "    --deploy: perform a \"mvn deploy\" rather than just a \"mvn install\""
    echo "    --offline: Pass -O to maven."
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
    echo "    --caffe-safe: Assuming you're building for CUDA (you must also specify --build-cuda-support), this"
    echo "        option will produce a deployment that can be used to link against Caffe. This implies:"
    echo "          1) As mentioned, you're also building with --build-cuda-support"
    echo "          2) opencv's DNN support is disabled. This means that DNN Object detection and the contrib module"
    echo "             \"text\" is also disabled."
    echo "          3) This build will NOT build the internal build of protobuf. That means you need to have protobuf"
    echo "             installed on the build host or the build will fail."
    echo ""
    echo "    if GIT isn't set then the script assumes \"git\" is on the command line PATH"
    echo "    if MVN isn't set then the script assumes \"mvn\" is on the command line PATH"
    echo "    if CMAKE isn't set then the script assumes \"cmake\" is on the command line PATH"
    echo "    if JAVA_HOME isn't set then the script will locate the \"java\" executable on the PATH"
    echo "      and will attempt infer the JAVA_HOME environment variable from there."

    if [ $# -gt 0 ]; then
        exit $1
    else
        exit 1
    fi
}

WORKING_DIR=/tmp/opencv
OPENCV_VERSION=
PARALLEL_BUILD=
CMAKE_GENERATOR=
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

CAFFE_SAFE=

while [ $# -gt 0 ]; do
    case "$1" in
        "-w")
            WORKING_DIR=$2
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
            CMAKE_GENERATOR="$2"
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
            BUILD_CUDA="-DWITH_CUDA=ON -DCUDA_NVCC_FLAGS=--expt-relaxed-constexpr -DWITH_CUFFT=ON -DWITH_CUBLAS=ON -DWITH_NVCUVID=ON"
            shift
            ;;
        "--build-qt-support")
            BUILD_QT="-DWITH_QT=ON"
            shift
            ;;
        "--caffe-safe")
            # These clash with an independent build of caffe. dnn_objdetect and text are dependent on dnn
            CAFFE_SAFE="-DBUILD_opencv_dnn=OFF -DBUILD_PROTOBUF=OFF"
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

if [ "$CAFFE_SAFE" != "" -a "$BUILD_CUDA" = "" ]; then
    echo "ERROR: If you specify --caffe-safe you also need to specify --build-cuda-support"
    exit 1
fi

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

# ========================================
# Make the WORKING_DIR an absolute path
cd "$WORKING_DIR"
if [ $? -ne 0 ]; then
    echo "ERROR: \"$WORKING_DIR\" is not a valid directory."
    usage
fi
# change working directory to absolute path
WORKING_DIR="$(pwd -P)"
# ========================================

# ========================================
# set and test git command
if [ "$GIT" = "" ]; then
    GIT=git
fi

"$GIT" --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot find \"$GIT\" command"
    usage
fi
# ========================================

# ========================================
# set and test git command
if [ "$CMAKE" = "" ]; then
    CMAKE=cmake
fi

"$CMAKE" --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot find \"$CMAKE\" command"
    usage
fi
# ========================================

# ========================================
# set and test mvn command
if [ "$MVN" = "" ]; then
    MVN=mvn
fi
"$MVN" --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot find \"$MVN\" command"
    usage
fi
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

    # find the directory with bin and jre as a subdir
    CDIR="$(dirname "$JAVA_LOCATION")"
    DONE=
    while [ "$DONE" != "true" ]; do
        if [ "$CDIR" = "/" -o "$CDIR" = "//" -o "$CDIR" = "" ]; then
            echo "Can't automatically locate the correct JAVA_HOME. Please set it explicitly."
            usage
        fi
        
        if [ ! -d "$CDIR/java" -a ! -d "$CDIR/jre" ]; then
            CDIR="$(dirname "$CDIR")"
        else
            DONE="true"
        fi
    done

    JAVA_HOME="$(cpath "$CDIR")"
    echo "JAVA_HOME :$JAVA_HOME"
fi

export JAVA_HOME
# ========================================

# figure out the deploy version

# calculate the version
# find the cuda version
CUDA_VERSION=
if [ "$BUILD_CUDA" != "" ]; then
    if [ -f /usr/local/cuda/version.txt ]; then
        CUDA_VERSION="$(cat /usr/local/cuda/version.txt | grep -i cuda | grep -i version | tail -1 | sed -e "s/^.*[Vv]ersion //1" | egrep -o -e "^[0-9][0-9]*[0-9]*\.[0-9][0-9]*[0-9]*[0-9]*")"
    else
        NVCC_EXE=
        if [ "$(type nvcc 2>& | grep "not found")" != "" -a -x /usr/local/cuda/bin/nvcc ]; then
            NVCC_EXE=/usr/local/cuda/bin/nvcc
        else
            NVCC_EXE=nvcc
        fi
        if [ "$NVCC_EXEC" != "" ]; then
            CUDA_VERSION="$($NVCC_EXEC --version | egrep -e ", V[0-9][0-9]*[0-9]*[0-9]*\." | sed -e "s/^.*, V//1" | sed -E "s/\.[0-9][0-9]*[0-9]*[0-9]*[0-9]*[0-9]*[0-9]*$//1")"
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
if [ "$SKIPC" != "true" ]; then
    rm -rf "$WORKING_DIR"/* 2>/dev/null

    mkdir -p sources
    if [ $? -ne 0 ]; then
        echo "ERROR: Couldn't create \"$WORKING_DIR\"/sources. Do I have permissions?"
        usage
    fi

    mkdir -p build
    if [ $? -ne 0 ]; then
        echo "ERROR: Couldn't create \"$WORKING_DIR\"/build. Do I have permissions?"
        usage
    fi

    cd sources
    if [ $? -ne 0 ]; then
        echo "ERROR: Couldn't cd to \"$WORKING_DIR\"/sources. Do I have permissions?"
        usage
    fi

    "$GIT" clone https://github.com/opencv/opencv.git
    if [ $? -ne 0 ]; then
        echo "Failed to clone the main opencv repo using \"$GIT clone https://github.com/opencv/opencv.git\""
        exit 1
    fi

    cd opencv
    if [ $? -ne 0 ]; then
        echo "ERROR: Couldn't cd to \"$WORKING_DIR\"/sources/opencv. Do I have permissions?"
        usage
    fi
    "$GIT" checkout "$OPENCV_VERSION"
    if [ $? -ne 0 ]; then
        echo "ERROR:Failed to check out the tag $OPENCV_VERSION for opencv"
        exit 1
    fi
    if [ "$PATCHME" = "true" ]; then
        echo "Applying patch for building a FAT jar."
        # if it's not too old then apply the patch to build a fat jar
        set -e
        git cherry-pick f3dde79ed6f5e17f16f4e2ad9669841e0dd6887c
        set +e
    fi
    cd ..

    "$GIT" clone https://github.com/opencv/opencv_contrib.git
    if [ $? -ne 0 ]; then
        echo "Failed to clone the main opencv repo using \"$GIT clone https://github.com/opencv/opencv_contrib.git\""
        exit 1
    fi

    cd opencv_contrib
    if [ $? -ne 0 ]; then
        echo "ERROR: Couldn't cd to \"$WORKING_DIR\"/sources/opencv_contrib. Do I have permissions?"
        usage
    fi
    "$GIT" checkout "$OPENCV_VERSION"
    if [ $? -ne 0 ]; then
        echo "ERROR:Failed to check out the tag $OPENCV_VERSION for opencv_contrib"
        exit 1
    fi
    cd ..
else
    # we're still going to clean up the build directory
    rm -rf "$WORKING_DIR"/build

    mkdir -p "$WORKING_DIR"/build
    if [ $? -ne 0 ]; then
        echo "ERROR: Couldn't create \"$WORKING_DIR\"/build. Do I have permissions?"
        usage
    fi
fi
# ========================================

cd "$WORKING_DIR"/build
if [ $? -ne 0 ]; then
    echo "ERROR: Couldn't cd to \"$WORKING_DIR\"/build. Do I have permissions?"
    usage
fi

# Make sure cmake.out is removed because we need to grep it assuming it was empty/non-existent at the beginning of the run
if [ -f "$WORKING_DIR/cmake.out" ]; then
    rm "$WORKING_DIR/cmake.out" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Couldn't remove \"$WORKING_DIR/cmake.out\" from a previous run. Can't continue."
        exit 1
    fi
    if [ -f "$WORKING_DIR/cmake.out" ]; then
        echo "Couldn't remove \"$WORKING_DIR/cmake.out\" from a previous run. Can't continue."
        exit 1
    fi
fi

echo "JAVA_HOME: \"$JAVA_HOME\"" | tee "$WORKING_DIR/cmake.out"

if [ "$CMAKE_GENERATOR" != "" ]; then
    echo "\"$CMAKE\" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=\"$(cwpath "$WORKING_DIR/installed")\" -DOPENCV_EXTRA_MODULES_PATH=../sources/opencv_contrib/modules $BUILD_SHARED $BUILD_PYTHON $BUILD_SAMPLES $BUILD_CUDA $BUILD_QT $CAFFE_SAFE -DENABLE_PRECOMPILED_HEADERS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_TESTS=OFF -DOPENCV_SKIP_VISIBILITY_HIDDEN=ON $CMAKE_ARCH -G \"$CMAKE_GENERATOR\" ../sources/opencv" | tee -a "$WORKING_DIR/cmake.out"
    "$CMAKE" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$(cwpath "$WORKING_DIR/installed")" -DOPENCV_EXTRA_MODULES_PATH=../sources/opencv_contrib/modules $BUILD_SHARED $BUILD_PYTHON $BUILD_SAMPLES $BUILD_CUDA $BUILD_QT $CAFFE_SAFE -DENABLE_PRECOMPILED_HEADERS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_TESTS=OFF -DOPENCV_SKIP_VISIBILITY_HIDDEN=ON $CMAKE_ARCH -G "$CMAKE_GENERATOR" ../sources/opencv | tee -a "$WORKING_DIR/cmake.out"
else
    echo "\"$CMAKE\" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=\"$(cwpath  "$WORKING_DIR/installed")\" -DOPENCV_EXTRA_MODULES_PATH=../sources/opencv_contrib/modules $BUILD_SHARED $BUILD_PYTHON $BUILD_SAMPLES $BUILD_CUDA $BUILD_QT $CAFFE_SAFE -DENABLE_PRECOMPILED_HEADERS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_TESTS=OFF -DOPENCV_SKIP_VISIBILITY_HIDDEN=ON $CMAKE_ARCH ../sources/opencv" | tee -a "$WORKING_DIR/cmake.out"
    "$CMAKE" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$(cwpath "$WORKING_DIR/installed")" -DOPENCV_EXTRA_MODULES_PATH=../sources/opencv_contrib/modules $BUILD_SHARED $BUILD_PYTHON $BUILD_SAMPLES $BUILD_CUDA $BUILD_QT $CAFFE_SAFE -DENABLE_PRECOMPILED_HEADERS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_TESTS=OFF -DOPENCV_SKIP_VISIBILITY_HIDDEN=ON $CMAKE_ARCH ../sources/opencv | tee -a "$WORKING_DIR/cmake.out"
fi

if [ $? -ne 0 ]; then
    echo "The CMake step seems to have failed. I can't continue."
    exit 1
fi

# check cmake.out for the java wrappers
if [ "$(grep -A4 -- '--   Java:' "$WORKING_DIR/cmake.out" | grep -- '--     Java wrappers:' | grep YES)" = "" ]; then
    echo "ERROR: It appears that the JNI wrappers wont build in this configuration."
    echo "       Some common reasons include:"
    echo "          1) Ant isn't installed or on the path"
    echo "          2) The cmake build cannot find python."
    echo " Note: on Windows when using the Windows CMake (as opposed to the mingw cmake) \"ant\" needs to be on the Windows PATH"
    exit 1
fi

# Get the make command from the cmake output
MAKE="$(cpath "$(grep -- '--     CMake build tool:' "$WORKING_DIR/cmake.out" | sed -e "s/^.*CMake build tool: *//g")")"

if [ "$(echo "$MAKE" | grep -i msbuild)" != "" ]; then
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
if [ $? -ne 0 ]; then
    echo "The make step seems to have failed. I can't continue."
    exit 1
fi

# if we're on linux, and execstack is installed, then we want to fixup the opencv_${shortversion} library
if [ "Linux" = "$PLAT" ]; then
    type execstack
    if [ $? -eq 0 ]; then
        JAVA_SHARED_LIB=`find "$WORKING_DIR/installed" -name "libopencv_java*.so" | head -1`
        if [ -f "$JAVA_SHARED_LIB" ]; then
            echo "Applying buffer overrun protection to \"$JAVA_SHARED_LIB\""
            execstack -s "$JAVA_SHARED_LIB"
        else
            echo "WARN: I should have been able to apply buffer overrun protection to the shared lib \"$JAVA_SHARED_LIB\" but I couldn't find it."
        fi
    else
        echo "NOT applying overrun protection. You should install 'execstack' using 'sudo apt-get install execstack'. Continuing..."
    fi
fi

#=========================================
# Comment out the actual build by including the next line
#fi
#=========================================

cd $PROJDIR
if [ $? -ne 0 ]; then
    echo "Couldn't get back to the main project directory \"$PROJDIR\""
    exit 1
fi

if [ "$SKIPP" != "true" ]; then
    if [ "$ZIPUP" != "" ]; then
        OPENCV_INSTALL="$WORKING_DIR/installed" ./package.sh $OFFLINE --version "$DEPLOY_VERSION" $DEPLOY_ME --zip "$ZIPUP"
    else 
        OPENCV_INSTALL="$WORKING_DIR/installed" ./package.sh $OFFLINE --version "$DEPLOY_VERSION" $DEPLOY_ME
    fi
    if [ $? -ne 0 ]; then
        echo "The packaing step seems to have failed. I can't continue."
        exit 1
    fi
fi

