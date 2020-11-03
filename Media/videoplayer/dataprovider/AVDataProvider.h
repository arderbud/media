//
//  AVDataProvider.h
//  Media
//
//  Created by arderbud on 2019/10/16.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MediaDecoder.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum OpenState{
    OPEN_SUCCESS,
    OPEN_FAILED,
    CLIENT_CANCEL,
} OpenState;

@protocol PlayerStateDelegate <NSObject>

- (void) openSucceed;

- (void) connectFailed;

- (void) hideLoading;

- (void) showLoading;

- (void) onCompletion;

- (void) buriedPointCallback:(BuriedPoint*) buriedPoint;

- (void) restart;

@end

/**
 Data provider.
 Innerly start a producer thread to provide audio/video data.
 */
@interface AVDataProvider : NSObject

@property (nonatomic, assign) float minBufferDuration;
@property (nonatomic, assign) float maxBufferDuration;
@property (nonatomic, strong, readonly) NSURL *fileURL;


- (instancetype)initWithFileURL:(NSURL *)fileURL;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;

- (OpenState)openFileWithOptions:(nullable NSDictionary *)options Error:(NSError **)error;

- (void)fillAudioData:(SInt16 *)outData nbFrames:(UInt32)nbFrames nbChannels:(UInt32)nbChannels;

- (VideoFrame *)getCorrespondVideoFrame;

- (BOOL)run;

- (void)stop;

- (void)closeFile;

@property (nonatomic, readonly) BOOL completed;

- (int)getAudioSampleRate;
- (int)getAudioChannels;
- (double)getVideoFPS;
- (int)getVideoFrameWidth;
- (int)getVideoFrameHeight;
- (double)getDuration;



@end

NS_ASSUME_NONNULL_END
