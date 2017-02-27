

Install the opencv packaging using maven by pointing to the opencv install by setting OPENCV_INSTALL.

The version of the install should match the pom.xml version. At the time of this writing that 3.2.0.

On windows, from git-bash you can invoke something like:

```OPENCV_INSTALL=`cygpath -w /c/Users/user/projects/opencv-3.2.0` OPENCV_VERSION=3.2.0 OPENCV_SHORT_VERSION=320 mvn clean install```

on Linux it's more straightforward

OPENCV_INSTALL="[absolute path to opencv-3.2.0]" OPENCV_VERSION=3.2.0 OPENCV_SHORT_VERSION=320 mvn clean install

When building opencv on Linux, you need to set JAVA_HOME and also have 'ant' installed. These are not done by default when following the instructions. The following worked for me after installing ant:

```JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/home/jim/utils/opencv-3.2.0 ..```
