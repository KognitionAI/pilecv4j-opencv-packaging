
## Notes on what the build does
The build process is as follows:

1. the `fromscratch.sh` script will check out opencv and contrib (unless optionally blocked) and build it targeting a statically compiled build with the java api.
1. once built fromscratch.sh will call `package.sh`
1. `package.sh` will find all of the build `*.so` and/or `*.dll` files and copy them to `./package-native/src/temp/libs`
1. `package.sh` will manipulate the files and delete files it deems unnecessary (see the script for details).
1. `package.sh` will then set the version for the maven project. The maven project consists of:
          .
          |- package-native
          |- install-jar
1. It will then run maven, optionally with the deploy target. The parent pom will call:
   1. install-jar which will install the jar file that was built by the opencv make process into a maven artifact at ai.kognition.pilecv4j:opencv --and optionally deploy it--
   1. package-native build a jar file that includes the content of the above artifact as well as the native libraries prepared earlier into an artifact at ai.kognition.pilecv4j:opencv with a classifier `withlib` and optionally deploy it.
1. If you're deploying or building an opencv install, `package.sh` will bundle up the native install (the bin/lib/include dirs) into a zip file and use the maven project in `opencv-zip-install` to package it into an artifact at ai.kognition.pilecv4j:opencv-build and install that zip file into the local maven repo and optionally deploy it.


The following is enough to build from within a clean `ubuntu:20.04` docker container.

``` bash
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
apt update
apt install -y --no-install-recommends gnupg2 curl ca-certificates openjdk-11-jdk build-essential execstack git unzip zip pkg-config libjpeg-dev libpng-dev libtiff-dev python-dev python-numpy libgtk-3-dev libtbb2 libtbb-dev cmake tar ant maven python3-dev python3-numpy file
export ANT_HOME=/usr/share/ant
git clone ....
cd pilecv4j-opencv-packaging
./fromscratch.sh [-j12] --version 0.17 --opencv-version 4.5.2 --build-python --with-tbb --no-dnn [--zip /tmp/opencv4.5.2.zip] --install-prefix /opt/opencv [--deploy]
```

