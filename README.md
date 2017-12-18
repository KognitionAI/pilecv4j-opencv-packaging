# *WARNING: Any changes made to the project and left uncommitted will be undone upon a successful run of `package.sh` or `fromscratch.sh`*

This project will build from scratch, package into a jar file, and install into the local maven repository, an `OpenCV` distribution's Java extentions. You can use this project to optionally simply build the opencv libraries. 

If you are writing OpenCV code in java and you use this project to build and package the native binaries, you can use `com.jiminger.utilities` to load them from your code with alomost no work. This project will package the binaries into a jar file so it will work just like other java dependencies. The `utilities` will scan the classpath and automatically `System.load()` the native libraries out of the jar files. This makes it easy to incorporate opencv into your java projects and rely on the same dependency mechanisms for the native code that you normally rely on for java code. 

Alternatively, if you're not interested in packaging up the binaries but only building them, you can also build OpenCV locally, pretty much from scratch, on either Windows (using an MSYS2 or Cygwon shell) or Linux.

This doesn't currently explicitly package the actual binary distribution of OpenCV (though I'm working on it). However, if you build with static linking (which is done automatically on Windows), then the JNI library that's built contains all of the other necessary object code so you don't need to manage a local install of OpenCV binaries. If you don't build that way you will still need to install and use the opencv binaries appropriately (this is the default on Linux).

Optioanlly, on Windows, you can simply `package.sh` the binary distribution downloaded and installed from the OpenCV website. The DLLs installed using OpenCV's Windows installers already has the the other libs statically linked into the JNI library. At least this was my experience using 3.0.0 to the current release, 3.3.1. If you manually build for Windows with `BUILD_SHARED_LIBS=false` or use the option "-no-static" when using `fromscratch.sh` then you will need the OpenCV DLLs on your path on Windows to use the packaged JNI native libraries.

## Buliding OpenCV `fromscratch.sh`

`fromscratch.sh` should build OpenCV on Linux or Windows comlpetely from scratch. It will check out OpenCV, build and install your chosen version, and then run the packaging to install the artifacts into the local maven repository. The usage message is as follows:

```
[GIT=/path/to/git/binary/git] [JAVA_HOME=/path/to/java/jdk/root] [MVN=/path/to/mvn/mvn] [CMAKE=/path/to/cmake/cmake] ./fromscratch.sh -v opencv-version [options]
    -v:  opencv-version. This needs to be specified. e.g. "-v 3.3.1"
 Options:
    -w /path/to/workingDirectory: this is /tmp by default.
    -jN: specify the number of threads to use when running make. If the cmake-generator is
       Visual Studio then this translates to /m option to "msbuild"
    -G cmake-generator: specifially specify the cmake generator to use. This is probably 
       necessary when building using VS on Windows or you get Win32 arch. e.g. -G "Visual Studio 14 2015 Win64"
    -sc: This will "skip the checkout" of the opencv code. If you're playing with different options
       then once the code is checked out, using -sc will allow subsequent runs to progress faster.
       This doesn't work unless the working directory remains the same between runs.
    -sp: Skip the packaging step. That is, only build opencv and opencv_contrib libraries but don't
       package them in a jar file for use with com.jiminger.utilities
    -static|-no-static: force the build to statically link (dynamically link for "-no-static") the JNI libraries.
        By default, the JNI library is statically linked on Windows and dynamically linked on Linux.
    --help|-help: print this message

    if GIT isn't set then the script assumes "git" is on the command line PATH
    if MVN isn't set then the script assumes "mvn" is on the command line PATH
    if CMAKE isn't set then the script assumes "cmake" is on the command line PATH
    if JAVA_HOME isn't set then the script will locate the "java" executable on the PATH
      and will attempt infer the JAVA_HOME environment variable from there.
```

### Building using `fromscratch.sh` on Windows

On Windows, the expectation is that `fromscratch.sh` will be run from MSYS2 or Cygwin. When running `fromscratch.sh` on Windows, you'll need to a few prerequisites.

1. MSYS2 or Cygwin installed, updated and set up.
1. Java is installed and on your MSYS2/Cygwin PATH or JAVA_HOME is set correctly.
1. Apache ANT is installed (unzip to a directory on Windows)
1. The **Windows** version of CMake is installed.
1. You'll also need either MinGW toolchain OR Visual Studio installed (there are currently issues using the artifacts generated from the MSYS2 toolchain) depending on which CMake generator you choose.
1. You'll need the **Windows** version of Python2 installed.

__Note: This requires the Windows version of CMake and wont run correctly with the MSYS2 or Cygwin version of cmake.__

__Note: This requires the Windows version of Python 2. You can try using the MSYS2 version but it's untested at this point.__

When you run `fromscratch.sh` you'll need to make sure `ant.bat`, `python.exe`, and `java.exe` are on your MSYS2/Cygwin PATH (Note: it will work without `java.exe` on your PATH if `JAVA_HOME` is set). The following are some examples that worked for me:

#### Example 1
From MSYS2 bash, specifying JAVA_HOME, specifying the location of ANT, selecting the **Windows** CMAKE, building OpenCV version 3.3.1, and using the MinGW toolchain to build and parallel build on 8 cores (the Windows version of Python2 is already on the PATH):
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
From MSYS2 bash, specifying the location of ANT, selecting the **Windows** CMAKE, building OpenCV version 3.3.1, and using Visual Studio (the Windows version of Python2 is already on the PATH and `java` is on the PATH):
``` bash
PATH="$PATH":/c/utils/apache-ant-1.10.1/bin CMAKE=/c/Program\ Files/CMake/bin/cmake ./fromscratch.sh -v 3.3.1 -G "Visual Studio 14 2015 Win64" -j8
```

### Building using `fromscratch.sh` on Linux

When running `fromscratch.sh` on Linux, you'll need to a few prerequisites.

1. Make sure Java is installed and on the path.
1. Install apache ANT
1. Install build tools (on Debian based system `sudo apt-get install build-essential`)

Using `fromscratch.sh` on Linux is similar to Windows described above.

#### Example 1

From bash, specifying the location of the maven executable, and building OpenCV version 3.3.1 in parallel using 8 cores:
``` bash
MVN=[/path/to/mvn/mvn] ./fromscratch.sh -v 3.3.1 -j8
```

This example will use the default `cmake-generator` for your Linux distribution.

## Manually Buliding OpenCV

The latest version of the image processing utilities requires `opencv_contrib` in order to get the SIFT algorithm. This requires OpenCV to be built for whatever system you're going to run it on since `opencv_contrib` isn't distributed as a binary. If you don't care about using the SIFT algorithm you can install OpenCV from the binaries on Windows. Since you'll need to build on Linux anyway (or at least it seems that way for 3.3.1) you might as well follow the instructions here to build both the `opencv` and `opencv_contrib` projects.

__Of course, if you just use the `fromscratch.sh` script then you don't need to go through all this.__

Hat Tip to Osama Abbas for [Install OpenCV 3.3.0 + Python 2: Build and Compile on Windows 10](https://www.youtube.com/watch?v=MXqpHIMdKfU) for bootstrapping me on building this for Windows.

First, create a directory to build everything under. `opencv` will do. Create 2 subdirectories: `source`,' and `build`. In the `source` directory check out of github the main `opencv` tree and also the `opencv_contrib`. Switch to your desired opencv version using *git checkout _[tag]_* (the current released tag is `3.3.1`). 

### Manually buildng OpenCV on Linux

When building opencv on Linux, you need to set JAVA_HOME and also have 'ant' installed. These are not done by default when following the instructions on OpenCVs website. The following is an *example* that worked for me _after installing ant_:

``` bash
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/home/[user]/utils/opencv-3.3.1 -DOPENCV_EXTRA_MODULES_PATH=../sources/opencv_contrib/modules ../sources/opencv
```

Then you can build using the standard Linux build tools (`make clean`, `make`, `make install`).

### Manually buildng OpenCV on Windows

If you don't want the SIFT algorithm it's possible to just install the OpenCV binaries rather than build locally and then just use `package.sh` to package the JNI binaries for use with `com.jiminger.utilities`. If you insist on building it manually this description might help:

I managed to build OpenCV (3.3.1) on Windows using the following:

1. Make sure Java is installed.
1. Install apache ANT (unzip to a directory on windows)
1. Install the Windows version of CMake.
1. Install Visual Studio C/C++ installed.
1. Install the *Windows* Python 2.7.
1. Set the environment varialbes:
    1. JAVA_HOME=[e.g. C:/Program Files/Java/jdk1.8.0_92]
    1. Add $JAVA_HOME/bin to the *Windows* PATH (User path works)
    1. Add the directory that 'ant.bat' is in to your *windows* PATH (User path works)

I installed Python in the default location (C:\Python27) and CMake found it.

To generate the build projects, from the build directory using a CMD prompt run:

```cmake -G "Visual Studio 14 2015 Win64" -DOPENCV_EXTRA_MODULES_PATH=..\sources\opencv_contrib\modules -DBUILD_SHARED_LIBS=false -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=[e.g. C:\utils\opencv-3.3.1-win] ..\sources\opencv```

Obviously if you have a different Visual Studio installed you'll select that one for the -G option.

Then load the .sln file into Visual Studio.
Build the `INSTALL` project which will build everything else and install it to the directory you specified above.

### Manually packaging your distribution.

The OpenCV distribution will first need to be built following the instructions for the particular platform on the [OpenCV website](http://opencv.org/) and/or above. If you don't want the SIFT algorithm, and you're on Windows, it's possible to just install the OpenCV binaries. See the section on building for more details.

Once you've installed or built the Open CV binary distribution, you can package and install the Java jar with the native binaries by pointing to the installed distribution via the `OPENCV_INSTALL` variable and running the `package.sh` script as follows:

On windows, from git-bash, MSYS2/MinGW, or Cygwin you can invoke something like:

```MVN=/c/utils/apache-3.2.2/bin/mvn OPENCV_INSTALL=`cygpath -w /c/Users/[user]/projects/opencv-3.3.1` ./package.sh```

An example on Linux would be:

```GIT=[path to git] MVN=[mvn command] OPENCV_INSTALL="[absolute path to opencv-3.3.1 install dir]" ./package.sh```

`MVN` defaults to `mvn` therefore assuming it's on the path
`GIT` defaults to `git` therefore assuming it's on the path

