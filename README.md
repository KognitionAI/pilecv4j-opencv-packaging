# OpenCV build and package for java

This project will allow you to build from scratch, package into a jar file, and install into the local maven repository, an `OpenCV` distribution's Java extensions including `opencv_contrib`. If you don't care about packaging up the OpenCv distribution for use with Java, you can simply use this project to build the OpenCv libraries. 

If you are writing OpenCV code in java and you use this project to build and package the native binaries, you can use `dempsy-commons` utilities to load them from your code. This project will package the OpenCv JNI binaries into a jar file so it will work just like any other java dependencies. The `dempsy-commons` utilities will scan the classpath and automatically `System.load()` the native libraries out of the jar files. This makes it easy to incorporate OpenCv into your java projects and rely on the same dependency mechanisms for the native code that you normally rely on for java code. 

Alternatively, if you're not interested in packaging up the binaries but only building OpenCv, you can do that from scratch, on either Windows (using an MSYS2/MinGW64) or Linux.

By default, the scripts here build the JNI shared library so that it's statically linked to the OpenCv binaries. That way the JNI library contains all of the other necessary object code so you don't need to manage a local install of the OpenCV binaries. 

## Buliding OpenCV `fromscratch.sh`

`fromscratch.sh` should build OpenCV on Linux or Windows (as the name implies) completely from scratch. It will check out OpenCV, build and install your chosen version, and then run the packaging to install the artifacts into the local maven repository. The usage message is as follows:

```
[GIT=/path/to/git/binary/git] [JAVA_HOME=/path/to/java/jdk/root] [MVN=/path/to/mvn/mvn] [CMAKE=/path/to/cmake/cmake] ./fromscratch.sh --opencv-version opencv-version --version version [options]

    --opencv-version opencv-version: This needs to be specified. e.g. "--opencv-version 4.5.2"
    --version version: This needs to be specified. e.g. "--version 1.0"
    --install-prefix|-i /path/to/install/opencv : Install opencv to the given path.

  This checkout and build opencv then it will package it up so that it can be used from a self contained
     java jar without any additional dependencies installed. The maven artifact created will be:
             "ai.kognition.pilecv4j:opencv-(platform):(version)-opencv(opencv-version)[-cuda(cuda-version)]:jar"
     a few examples:
             "ai.kognition.pilecv4j:opencv-windows-x86_64:1.0-opencv4.5.2:jar"
             "ai.kognition.pilecv4j:opencv-linux-x86_64:1.0-opencv4.5.2-cuda11.2:jar"
 Options:
    -w /path/to/workingDirectory: this is /tmp/opencv-working by default. The directory is created
       and deleted as necessary.
    -jN: specify the number of threads to use when running make. If the cmake-generator is
       Visual Studio then this translates to /m option to "msbuild"
    -G cmake-generator: specifially specify the cmake generator to use. The default is chosen otherwise.
    --zip /path/to/zip: Create a zip file of the final installed directory with the headers and libraries.

    --help|-help: print this message
    --skip-checkout: This will "skip the checkout" of the opencv code. If you're playing with different
       options then once the code is checked out, using --skip-checkout will allow subsequent runs to progress
       faster. This doesn't work unless the working directory remains the same between runs.
    --skip-packaging: Skip the packaging step. That is, only build opencv and opencv_contrib libraries but
       don't package them in a jar file for use with net.dempsy.util.library.NativeLivbraryLoader
    --deploy: perform a "mvn deploy" rather than just a "mvn install"
    --deploy-zip: by default the zipped up opencv distribution created using --zip will not be deployed even
       when the --deploy flag is used. If you want to explicitly deploy it you'll need to include --deploy-zip
       also. Obviously if you specify --deploy-zip you must also request the opencv distribution be zipped
       using --zip
    --offline: Pass -o to maven.

 Build Options
    --static(default)|--no-static: force the build to statically link (dynamically link for "--no-static")
        the JNI libraries. By default, the JNI library is statically linked on all platform builds.
    --build-python: Build python3 wrappers. By default, the script blocks building the Python wrappers. If
        you want to build them anyway you can specify "--build-python" or "--build-python-3".
    --build-python-2: Build python2 wrappers. By default, the script blocks building the Python wrappers.
        This is mutually exclusive with "--build-python".
    --build-samples: Build the OpenCV samples also.
    --build-cuda-support: Build the OpenCV using NVidia's CUDA (Note: CUDA must already be installed, this
        option is untested on Windows). The cuda version will be determined by what's installed.
    --build-qt-support: Build the OpenCV using QT as the GUI implementation (Note: QT5 Must already be
        installed, this option is untested on Windows).
    --no-dnn: disable opencv's DNN support. As a note, OpenCV's DNN seems to conflict with Caffee. Disabling
        OpenCV's DNN also means that DNN Object detection and the contrib module "text" is also disabled,
        as is potentially other modules that depend on opencv's DNN support.
    --build-protobuf: This option will enable OpenCV's internal build of protobuf. While the raw OpenCV build
        defaults to building this, this script defaults to blocking it since it tends to conflict with
        other systems that also rely on protobufs. NOT selecting this option implies protobuf will need to be
        installed on your build machine. You should set the environment variable CMAKE_PREFIX_PATH to point
        to point to the directory where the version of protobufs you're using is installed.

        If you don't want to use protobufs at all then you need to prevent then Nvidia DNN from building.
        see --no-dnn.
    --with-tbb: This option will build OpenCV using libtbb. It's assumed that libtbb-dev is installed.
    --no-contrib: Don't build the contrib modules which are build by default. The pilecv4j module lib-tracking
        depends on contrib. So that module wont build if you use this option.

    if GIT isn't set then the script assumes "git" is on the command line PATH
    if MVN isn't set then the script assumes "mvn" is on the command line PATH
    if CMAKE isn't set then the script assumes "cmake" is on the command line PATH
    if JAVA_HOME isn't set then the script will locate the "java" executable on the PATH
      and will attempt infer the JAVA_HOME environment variable from there.

    If you set the environment variable "VERBOSE=1" then you will get script debugging output as well as
        verbose 'make' output.
    To build against an externally built, non-system installed, version of Protobuf's (only needed for DNN)
       you set/append to the environment variable "CMAKE_PREFIX_PATH" to point to the root of the Protobuf
       install.
```

### Building using `fromscratch.sh` on Windows

On Windows, the expectation is that `fromscratch.sh` will be run from `mingw64` bash shell. When running `fromscratch.sh` on Windows, you'll need to prepare a few prerequisites.

1. MSYS2/mingw64 installed, updated and set up.
    1. Follow the [MSYS2 Installation instructions and download](https://www.msys2.org). While it shouldn't make a difference, I ran `mingw64` and NOT `MSYS2` when following the instructions.
    1. Install the following:
        1. `pacman -Su --noconfirm --needed rsync`
        1. `pacman -Su --noconfirm --needed diffutils`
        1. `pacman -Su --noconfirm --needed git`
        1. `pacman -Su --noconfirm --needed mingw-w64-x86_64-pkg-config`
        1. `pacman -Su --noconfirm --needed unzip`
        1. (optional) `pacman -Su --noconfirm --needed vim`
        1. (optional) `pacman -Su --noconfirm --needed emacs`
1. Java is installed and JAVA_HOME is set correctly.
1. Apache ANT is installed (unzip to a directory on Windows) and included on your `PATH` in *both* Windows and `MSYS/mingw64`. For `MSYS/mingw64` I added the location to my `PATH` variable in `.bashrc`.
1. Apache Maven is installed (unzip to a directory on Windows) and included on your `PATH` on `MSYS/mingw64`. I added the location to my `PATH` variable in `.bashrc`.
1. The **Windows** version of CMake is installed and is on the `MSYS/mingw64` `PATH`. I added the location to my `PATH` variable in `.bashrc`. *
1. You'll also need Visual Studio (community edition is fine) installed with Visual C++. Currently there are issues using the artifacts generated from the MSYS2 toolchain.
1. You'll need the **Windows** version of Python3 installed and configured on the `MSYS2/mingw64` PATH. **

__* Note: This requires the Windows version of CMake and wont run correctly with the MSYS2 version of cmake.__

__** Note: This requires the Windows version of Python. You can try using the MSYS2 version but it's untested at this point.__

When you run `fromscratch.sh` you'll need to make sure `ant.bat`, `python.exe` are on your MSYS2/minGW64 bash `PATH` and `JAVA_HOME` is set appropriately. The following are some examples that worked for me:

#### Example 1
From `MSYS2` bash, specifying the location of ANT, selecting the **Windows** CMAKE, building OpenCV version 3.3.1, and using Visual Studio (the Windows version of Python2 is already on the PATH and `JAVA_HOME` is set):
``` bash
PATH="$PATH":/c/utils/apache-ant-1.10.1/bin CMAKE=/c/Program\ Files/CMake/bin/cmake ./fromscratch.sh -v 3.3.1 --install-prefix /c/utils -G "Visual Studio 14 2015" -j8
```

#### Example 2
Assuming all of your paths are set up as suggested above, using with Windows PATH environment variabels and `.bashrc`, the following should work:
``` bash
./fromscratch.sh -v 4.0.1 -G "Visual Studio 15 2017" --install-prefix /c/utils -j8
```

My  `MSYS2` `.bashrc` file has the following lines:
```
export PATH=/c/Program\ Files/Java/jdk-11.0.1/bin:"$PATH"
export PATH="$PATH":/c/Program\ Files/Python37
export PATH="$PATH":/c/Program\ Files/CMake/bin
export PATH="$PATH":/c/utils/apache-maven-3.6.0/bin
export PATH="$PATH":/c/utils/apache-ant-1.10.5/bin
export JAVA_HOME=/c/Program\ Files/Java/jdk-11.0.1
```

Obviously yours will be different depending on where you installed the various packages.

Hat Tip to Osama Abbas for [Install OpenCV 3.3.0 + Python 2: Build and Compile on Windows 10](https://www.youtube.com/watch?v=MXqpHIMdKfU) for bootstrapping me on building this for Windows.

### Building using `fromscratch.sh` on Linux

When running `fromscratch.sh` on Linux, you'll need to a few prerequisites.

1. Make sure Java is installed and on the path.
1. Install Apache ANT (on Debian based systems `sudo apt-get install ant`) 
1. Install build tools (on Debian based systems `sudo apt-get install build-essential`)

Using `fromscratch.sh` on Linux is similar to Windows described above.

#### Example

From bash, specifying the location of the maven executable, and building OpenCV version 3.3.1 in parallel using 8 cores:
``` bash
MVN=[/path/to/mvn/mvn] ./fromscratch.sh -v 3.3.1 -j8
```

This example will use the default `cmake-generator` for your Linux distribution.

On Ubuntu, this is an example of the last build I did:

``` bash
ANT_HOME=/usr/share/ant ./fromscratch.sh -j12 --version 1.0 --opencv-version 4.5.2 --build-python --with-tbb --no-dnn --zip /tmp/opencv4.5.2.zip --install-prefix /opt/opencv --deploy
```

Explanation:
1. when you install `ant` on Ubuntu using `apt install` the `ant` executable is a link in `/usr/bin` but the build requires the ant install and wont figure it out from the link to ANT_HOME is explicitly provided.
2. -j12 use 12 CPUs to compile in parallel
3. The version of this release of the packaged jar file needs to be specified. `--version 1.0` does this.
4. The version/tag of opencv we're building and bundling into this jar will be `4.5.2`
5. We want to include python binds so `lib-python` doesn't need it's own opencv install. This is usually unnecessary since opencv is usually installed in the virtual environment the final app will need to run in anyway.
6. build opencv against Intel's libtbb
7. Don't build OpenCVs CuDNN functionality. You might want this but nothing in pilecv4j requires it.
8. Create a zip file with the install called `/tmp/opencv4.5.2.zip`
9. Install the development libraries at `/opt/opencv`. While a development install isn't needed to run pilecv4j, it is for building the native portions.

