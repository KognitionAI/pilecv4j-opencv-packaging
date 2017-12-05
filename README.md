# *WARNING: Any changes made to the project and left uncommitted will be undone upon a successful run of `package.sh`*

This project will package an `OpenCV` distribution's Java extentions for use with the `com.jiminger.utilities` libraries as well as install the jar file into the local maven repository. The OpenCV distribution will first need to be built following the instructions for the particular platform on the [OpenCV website](http://opencv.org/). On Windows the distribution already contains binaries so there's no additional step necessary. On Linux you'll need to `make` opencv it before following the instructions below. See the section `Building OpenCV on Linux` below.

Install the opencv packaging using maven by pointing to the opencv install by setting OPENCV_INSTALL and running the build script.

On windows, from git-bash, MSYS/MinGW, or Cygwin you can invoke something like:

```MVN=/c/utils/apache-3.2.2/bin/mvn OPENCV_INSTALL=`cygpath -w /c/Users/[user]/projects/opencv-3.2.0` ./package.sh```

on Linux it's slightly more straightforward

```GIT=[path to git] MVN=[mvn command] OPENCV_INSTALL="[absolute path to opencv-3.2.0]" ./package.sh```

`MVN` defaults to `mvn` therefore assuming it's on the path
`GIT` defaults to `git` therefore assuming it's on the path

## Buildng OpenCV on Linux

When building opencv on Linux, you need to set JAVA_HOME and also have 'ant' installed. These are not done by default when following the instructions. The following worked for me after installing ant:

```JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/home/[user]/utils/opencv-3.2.0 ..```

## Buildng OpenCV on Windows

I managed to build OpenCV (3.3.1) on Windows using the following. (Hat Tip, Osama Abbas for [Install OpenCV 3.3.0 + Python 2: Build and Compile on Windows 10](https://www.youtube.com/watch?v=MXqpHIMdKfU) )

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

I created a directory called "opencv" and made 2 subdirectories: 'source,' and 'build.' In the 'source' directory I checked out of github the main opencv tree and also the opencv_contrib. Switch to the version you want using *git checkout _tag_.* From the build directory using a CMD prompt you can run:

```cmake -G "Visual Studio 14 2015 Win64" -DOPENCV_EXTRA_MODULES_PATH=..\sources\opencv_contrib\modules -DBUILD_SHARED_LIBS=false -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=[e.g. C:\utils\opencv-3.3.1-win] ..\sources\opencv```

Obviously if you have a different Visual Studio installed you'll select that one for the -G option.

Then load the .sln file into Visual Studio.
Build the INSTALL project which will build everything else and install it to the directory you specified above.

Note: This doesn't explicitly package the actual binary distribution of OpenCV (though I'm considering doing that). It packages the Java JNI extension that allows OpenCV to be used from Java. That means you still need to install and use the binaries appropriately on Linux. If you followed the instructions for the Windows build, or you installed OpenCV from the Windows installers then the .dll file built for java has all the other libs statically linked into it. At least this was my experience using 3.0.0 to the current release, 3.3.1. If you don't use "BUILD_SHARED_LIBS=false" when building yourself then you will need the OpenCV DLLs on your path on Windows.

