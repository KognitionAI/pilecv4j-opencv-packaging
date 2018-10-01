# Deploy the entire build of OpenCV to a local or remote repository

This assumes you've already built opencv using the `opencv-packaging` project used the option to zip it up. Run maven by supplying the path to the zip file and the version you want it installed as. An example follows:

```
mvn -Dopencv-zip-path=/path/to/opencv.zip -Dopencv-zip-version=3.4.3-cuda9.2 clean [install|deploy]
```


