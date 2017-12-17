# *WARNING: Any changes made to the project and left uncommitted will be undone upon a successful run of `package.sh` or `fromscratch.sh`*

This project will package an `OpenCV` distribution's Java extentions for use with the `com.jiminger.utilities` libraries as well as install the jar files into the local maven repository. It can also build OpenCV locally pretty much from scratch on either Windows (using an MSYS2 shell) or Linux.

_Note: This doesn't explicitly package the actual binary distribution of OpenCV (though I'm considering doing that). It packages the Java JNI extension that allows OpenCV to be used from Java. That means you still need to install and use the binaries appropriately on Linux. If you followed the instructions for the Windows build, or you installed OpenCV from the Windows installers then the .dll file built for java has all the other libs statically linked into it. At least this was my experience using 3.0.0 to the current release, 3.3.1. If you don't use `BUILD_SHARED_LIBS=false` when building yourself then you will need the OpenCV DLLs on your path on Windows._

## Buliding OpenCV

I've recently added a script that should build OpenCV on Linux or Windows comlpetely from scratch. It will check out OpenCV, build and install your chosen version, and then run the packaging to install the artifacts into the local maven repository. The usage message is as follows:

```
[GIT=/path/to/git/binary/git] [JAVA_HOME=/path/to/java/jdk/root] [MVN=/path/to/mvn/mvn] [CMAKE=/path/to/cmake/cmake] ./fromscratch.sh -v opencv-version [options]
    -v:  opencv-version. This needs to be specified. e.g. "-v 3.3.1"
 Options:
    -w /path/to/workingDirectory: this is /tmp by default.
    -jN:  specify the number of threads to use when running make. Doesn't apply to VS projects
    -G cmake-generator: specifially specify the cmake generator to use. This is probably
       necessary when building using VS on Windows or you get Win32 arch. e.g. -G "Visual Studio 14 2015 Win64"
    -sc: This will "skip the checkout" of the opencv code. If you're playing with different options
       then once the code is checked out, using -sc will allow subsequent runs to progress faster.
       This doesn't work unless the working directory remains the same between runs.

    if GIT isn't set then the script assumes "git" is on the command line PATH
    if MVN isn't set then the script assumes "mvn" is on the command line PATH
    if CMAKE isn't set then the script assumes "cmake" is on the command line PATH
    if JAVA_HOME isn't set then the script "java" is on the PATH and will attempt to locate it
```

### Building using `fromscratch.sh` on Windows

On Windows, the expectation is that `fromscratch.sh` will be run from MSYS2. When running `fromscratch.sh` on Windows, you'll need to a few prerequisites.

1. MSYS2 installed, updated and set up.
1. Make sure Java is installed.
1. Install apache ANT (unzip to a directory on windows)
1. Install the **Windows** version of CMake.
1. You'll also need either MinGW toolchain OR Visual Studio installed depending on which CMake generator you choose.
1. You'll need the **Windows** version of Python2 installed.

__Note: This requires the Windows version of CMake and wont run correctly with the MSYS2 version of cmake.__

__Note: This requires the Windows version of Python 2. You can try using the MSYS2 version but it's untested at this point.__

When you run `fromscratch.sh` you'll need to make sure `ant.bat`, `python.exe`, and `java.exe` are on your MSYS2/bash PATH (Note: it will work without `java.exe` on your PATH if `JAVA_HOME` is set). The following are some examples that worked for me:

#### Example 1
Specifying JAVA_HOME, specifying the location of ANT, selecting CMAKE, building OpenCV version 3.3.1, and using the MinGW toolchain to build and parallel build on 8 cores (the Windows version of Python2 is already on the PATH):
``` bash
JAVA_HOME="$(cygpath "$JAVA_HOME")" CMAKE=/c/Program\ Files/CMake/bin/cmake PATH="$PATH":/c/utils/apache-ant-1.10.1/bin ./fromscratch.sh -v 3.3.1 -G "MSYS Makefiles" -j8
```

This last example assumes the MSYS2 toolchain is already installed. You can do that using the following:
``` bash
pacman -Sy --noconfirm --needed base-devel
pacman -Sy --noconfirm --needed msys2-devel
pacman -Sy --noconfirm --needed mingw-w64-x86_64-toolchain
```

#### Example 2
Specifying the location of ANT, selecting CMAKE, building OpenCV version 3.3.1, and using Visual Studio (the Windows version of Python2 is already on the PATH and `java` is on the PATH):
``` bash
PATH="$PATH":/c/utils/apache-ant-1.10.1/bin CMAKE=/c/Program\ Files/CMake/bin/cmake ./fromscratch.sh -v 3.3.1 -G "Visual Studio 14 2015 Win64"
```

__Note: Don't specify `-jN` when using a Visual Stidio generator.__

### Building using `fromscratch.sh` on Linux

When running `fromscratch.sh` on Linux, you'll need to a few prerequisites.

1. Make sure Java is installed and on the path.
1. Install apache ANT
1. Install build tools (on Debian based system `sudo apt-get install build-essential`)

Using `fromscratch.sh` on Linux is similar to Windows described above.

Specifying the location of the maven executable, and building OpenCV version 3.3.1 in parallel using 8 cores:
``` bash
MVN=[/path/to/mvn/mvn] ./fromscratch.sh -v 3.3.3 -j8
```

This example will use the default generator for your Linux distribution.

## Manually Buliding OpenCV

The latest version of the image processing utilities requires `opencv_contrib` in order to get the SIFT algorithm. This requires OpenCV to be built for whatever system you're going to run it on since `opencv_contrib` isn't distributed as a binary. If you don't care about using the SIFT algorithm you can install OpenCV from the binaries on Windows. Since you'll need to build on Linux anyway (or at least it seems that way for 3.3.1) you might as well follow the instructions here to build both the `opencv` and `opencv_contrib` projects.

Hat Tip to Osama Abbas for [Install OpenCV 3.3.0 + Python 2: Build and Compile on Windows 10](https://www.youtube.com/watch?v=MXqpHIMdKfU) for bootstrapping me on building this for Windows.

First, create a directory to build everything under. `opencv` will do. Create 2 subdirectories: `source`,' and `build`. In the `source` directory check out of github the main `opencv` tree and also the `opencv_contrib`. Switch to your desired opencv version using *git checkout _[tag]_* (the current released tag is `3.3.1`). 

### Manually buildng OpenCV on Linux

When building opencv on Linux, you need to set JAVA_HOME and also have 'ant' installed. These are not done by default when following the instructions on OpenCVs website. The following worked for me _after installing ant_:

``` bash
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/home/jim/utils/opencv-3.3.1 -DOPENCV_EXTRA_MODULES_PATH=../sources/opencv_contrib/modules ../sources/opencv
```

Then you can build using the standard Linux build tools (`make clean`, `make`, `make install`).

### Manually buildng OpenCV on Windows

If you don't want the SIFT algorithm it's possible to just install the OpenCV binaries rather than build locally.

I managed to build OpenCV (3.3.1) on Windows using the following:

1. Make sure Java is installed.
1. Install apache ANT (unzip to a directory on windows)
1. Install the Windows version of CMake.
1. You'll need a Visual Studio C/C++ installed.
1. Install Python 2.7.
1. Set the environment varialbes:
    1. JAVA_HOME=[e.g. C:/Program Files/Java/jdk1.8.0_92]
    1. Add $JAVA_HOME/bin to your windows PATH (User path works)
    1. Add the directory that 'ant.bat' is in to your windows PATH (User path works)

I installed Python in the default location (C:\Python27) and CMake found it.

To generate the build projects, from the build directory using a CMD prompt run:

```cmake -G "Visual Studio 14 2015 Win64" -DOPENCV_EXTRA_MODULES_PATH=..\sources\opencv_contrib\modules -DBUILD_SHARED_LIBS=false -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=[e.g. C:\utils\opencv-3.3.1-win] ..\sources\opencv```

Obviously if you have a different Visual Studio installed you'll select that one for the -G option.

Then load the .sln file into Visual Studio.
Build the INSTALL project which will build everything else and install it to the directory you specified above.

### Manually packaging your distribution.

The OpenCV distribution will first need to be built following the instructions for the particular platform on the [OpenCV website](http://opencv.org/) and/or above. If you don't want the SIFT algorithm, and you're on Windows, it's possible to just install the OpenCV binaries. See the section on building for more details.

Once you've installed or built the Open CV binary distribution, you can package and install the Java jar with the native binaries by pointing to the installed distribution via the `OPENCV_INSTALL` variable and running the `package.sh` script as follows:

On windows, from git-bash, MSYS2/MinGW, or Cygwin you can invoke something like:

```MVN=/c/utils/apache-3.2.2/bin/mvn OPENCV_INSTALL=`cygpath -w /c/Users/[user]/projects/opencv-3.3.1` ./package.sh```

An example on Linux would be:

```GIT=[path to git] MVN=[mvn command] OPENCV_INSTALL="[absolute path to opencv-3.3.1 install dir]" ./package.sh```

`MVN` defaults to `mvn` therefore assuming it's on the path
`GIT` defaults to `git` therefore assuming it's on the path

