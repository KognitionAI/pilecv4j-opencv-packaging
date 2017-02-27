
Install the opencv packaging using maven by pointing to the opencv install by setting OPENCV_INSTALL and running the build script.

On windows, from git-bash you can invoke something like:

```MVN=/c/utils/apache-3.2.2/bin/mvn OPENCV_INSTALL=`cygpath -w /c/Users/user/projects/opencv-3.2.0` ./package.sh```

on Linux it's slightly more straightforward

```MVN=[mvn command] OPENCV_INSTALL="[absolute path to opencv-3.2.0]" ./package.sh```

When building opencv on Linux, you need to set JAVA_HOME and also have 'ant' installed. These are not done by default when following the instructions. The following worked for me after installing ant:

```JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/home/jim/utils/opencv-3.2.0 ..```
