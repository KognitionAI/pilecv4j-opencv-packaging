#include "com_jiminger_image_CvRasterNative.h"

#include <cstdint>
#include <opencv2/core/mat.hpp>

static void throwIllegalStateException( JNIEnv *env, const char* message ) {
  static const char* iseClassName = "java/lang/IllegalStateException";

  jclass exClass = env->FindClass(iseClassName);
  if (exClass == NULL)
    return; // nothing I can do, really.

  env->ThrowNew(exClass, message );
}

JNIEXPORT jobject JNICALL Java_com_jiminger_image_CvRasterNative__1getData(JNIEnv * env, jclass, jlong native) {
  cv::Mat* mat = (cv::Mat*) native;

  if (!mat->isContinuous()) {
    throwIllegalStateException(env, "Cannot create a CvRaster from a Mat without a continuous buffer.");
    return NULL;
  }

  cv::Size size = mat->size();
  jlong capacity = ((jlong)size.width * (jlong)size.height);

  return env->NewDirectByteBuffer(mat->ptr(0), capacity);
}

JNIEXPORT jlong JNICALL Java_com_jiminger_image_CvRasterNative__1getDataAddress(JNIEnv * env, jclass, jlong native) {
  cv::Mat* mat = (cv::Mat*) native;

  if (!mat->isContinuous()) {
    throwIllegalStateException(env, "Cannot extract Mat data address form a Mat without a continuous buffer.");
    return -1;
  }

  jlong ret = (jlong) mat->ptr(0);
  return ret;
}
