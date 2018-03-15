package com.jiminger.image;

import java.nio.ByteBuffer;

public abstract class CvRasterNative {
    /**
     * Get the raw frame data from the Mat as a direct ByteBuffer. This 
     * only works if the underlying Mat's data is contiguous. 
     */
    static native ByteBuffer _getData(long matNativeRef);

    /**
     * This method takes a native object reference to a Mat and returns the 
     * raw data pointer.
     */
    static native long _getDataAddress(long matNativeRef);

    // static native void showImage(long matNativeRef);

    /**
     * This call takes a native object reference to a Mat and constructs and returns
     * a new native object reference to a new Mat constructed using the copy constructor
     * of Mat.
     */
    static native long _copy(long matNativeRef);

    /**
     * Given a pointer to a matrix of raw data, and minimal metadata, instantiate a 
     * native Mat object reference.
     */
    static native long _makeMatFromRawDataReference(int rows, int cols, int type, long rawDataPointer);
}
