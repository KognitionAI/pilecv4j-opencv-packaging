# *WARNING: Any changes made to the project and left uncommitted will be undone upon a successful run of `package.sh`*

This project will package an `OpenCV` distribution for use with the `com.jiminger.utilities` libraries as well as install the jar file into the local maven repository. The OpenCV distribution will first need to be built following the instructions for the particular platform on the [OpenCV website](http://opencv.org/). On Windows the distribution already contains binaries so there's no additional step necessary. On Linux you'll need to `make` opencv but you don't need to `make install` it before following the instructions below. See the section `Building OpenCV on Linux` below.

Install the opencv packaging using maven by pointing to the opencv install by setting OPENCV_INSTALL and running the build script.

On windows, from git-bash you can invoke something like:

```MVN=/c/utils/apache-3.2.2/bin/mvn OPENCV_INSTALL=`cygpath -w /c/Users/[user]/projects/opencv-3.2.0` ./package.sh```

on Linux it's slightly more straightforward

```GIT=[path to git] MVN=[mvn command] OPENCV_INSTALL="[absolute path to opencv-3.2.0]" ./package.sh```

`MVN` defaults to `mvn` therefore assuming it's on the path
`GIT` defaults to `git` therefore assuming it's on the path

## Buildng OpenCV on Linux

When building opencv on Linux, you need to set JAVA_HOME and also have 'ant' installed. These are not done by default when following the instructions. The following worked for me after installing ant:

```JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/home/[user]/utils/opencv-3.2.0 ..```

The windows distributions of OpenCV (at least 3.1.0 and 3.2.0) already have the binaries included in them.
