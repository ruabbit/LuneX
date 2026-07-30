#import "LuneXAVKitBridge.h"

AVPictureInPictureControllerContentSource * _Nullable
LuneXCreatePictureInPictureContentSource(
    AVSampleBufferDisplayLayer *displayLayer,
    id<AVPictureInPictureSampleBufferPlaybackDelegate> playbackDelegate
) {
    return [[AVPictureInPictureControllerContentSource alloc]
        initWithSampleBufferDisplayLayer:displayLayer
        playbackDelegate:playbackDelegate];
}

AVPictureInPictureController * _Nullable
LuneXCreatePictureInPictureController(
    AVPictureInPictureControllerContentSource *contentSource
) {
    return [[AVPictureInPictureController alloc]
        initWithContentSource:contentSource];
}
