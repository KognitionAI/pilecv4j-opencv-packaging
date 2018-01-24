package com.jiminger.image;

import java.nio.ByteBuffer;

public abstract class CvRasterNative {
    static native ByteBuffer _getData(long matNativeRef);

    static native long _getDataAddress(long matNativeRef);

//    static native void showImage(long matNativeRef);

    static native long _copy(long matNativeRef);
}
