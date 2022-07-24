
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
