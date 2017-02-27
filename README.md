Install the opencv packaging using maven by pointing to the opencv install by setting OPENCV_INSTALL.

The version of the install should match the pom.xml version. At the time of this writing that 3.2.0.

On windows, from git-bash you can invoke something like:

OPENCV_INSTALL=`cygpath -w /c/Users/user/projects/opencv-3.2.0` mvn clean install

on Linux it's more straightforward

OPENCV_INSTALL="[absolute path to opencv-3.2.0]" mvn clean install


