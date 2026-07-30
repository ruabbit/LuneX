#ifndef LUNEX_AVKIT_BRIDGE_H
#define LUNEX_AVKIT_BRIDGE_H

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

NS_ASSUME_NONNULL_BEGIN

AVPictureInPictureControllerContentSource * _Nullable
LuneXCreatePictureInPictureContentSource(
    AVSampleBufferDisplayLayer *displayLayer,
    id<AVPictureInPictureSampleBufferPlaybackDelegate> playbackDelegate
);

AVPictureInPictureController * _Nullable
LuneXCreatePictureInPictureController(
    AVPictureInPictureControllerContentSource *contentSource
);

NS_ASSUME_NONNULL_END

#endif
