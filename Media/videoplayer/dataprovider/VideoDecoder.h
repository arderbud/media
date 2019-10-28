//
//  VideoDecoder.h
//  Media
//
//  Created by arderbud on 2019/9/27.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger,FrameType) {
    FrameTypeVideo,
    FrameTypeAudio
};

@interface BuriedPoint : NSObject
@property (readwrite, nonatomic) long long beginOpen;              // 开始试图去打开一个直播流的绝对时间
@property (readwrite, nonatomic) float successOpen;                // 成功打开流花费时间
@property (readwrite, nonatomic) float firstScreenTimeMills;       // 首屏时间
@property (readwrite, nonatomic) float failOpen;                   // 流打开失败花费时间
@property (readwrite, nonatomic) int failOpenCode;               // 流打开失败类型
@property (readwrite, nonatomic) int retryTimes;                   // 打开流重试次数
@property (readwrite, nonatomic) float duration;                   // 拉流时长
@property (readwrite, nonatomic) NSMutableArray* bufferStatusRecords; // 拉流状态
@end

@interface FrameBase : NSObject
@property (readwrite, nonatomic) FrameType type;
@property (readwrite, nonatomic) CGFloat position;
@property (readwrite, nonatomic) CGFloat duration;
@end

// AudioFormat: sampleFmt :S16 interleaved
//              sampleRate:decodec->sampleRate
//              channels  :2(LAYOUT_STEREO)
@interface AudioFrame : FrameBase
@property (readwrite, nonatomic, strong) NSData *samples;
@end

// YUV format
@interface VideoFrame : FrameBase
@property (readwrite, nonatomic) NSUInteger width;
@property (readwrite, nonatomic) NSUInteger height;
@property (readwrite, nonatomic) NSUInteger linesize;
@property (readwrite, nonatomic, strong) NSData *luma;
@property (readwrite, nonatomic, strong) NSData *chromaB;
@property (readwrite, nonatomic, strong) NSData *chromaR;
@property (readwrite, nonatomic, strong) id imageBuffer;
@end


#ifndef SUBSCRIBE_VIDEO_DATA_TIME_OUT
#define SUBSCRIBE_VIDEO_DATA_TIME_OUT               20
#endif

#ifndef NET_WORK_STREAM_RETRY_TIME
#define NET_WORK_STREAM_RETRY_TIME                  3
#endif

@interface VideoDecoder : NSObject

// File info
@property (nonatomic, strong, readonly) NSURL *fileURL;
@property (nonatomic, assign, readonly) BOOL isEOF;
- (BOOL)isSubscribed;
- (BuriedPoint*)getBuriedPoint;

- (instancetype)int UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;

- (instancetype)initWithFileURL:(NSURL *)fileURL;

- (BOOL)openFileWithOptions:(nullable NSDictionary *)param error:(NSError *_Nullable __autoreleasing*)error;

- (NSArray<FrameBase *> *)decodeFramesWithMinDuration:(CGFloat)minDuration error:(nullable int *)error;

- (void)interrupt;

- (void)closeFile;

- (void)triggerFirstScreen;


// Video info
- (BOOL)validVideo;
@property (nonatomic, assign, readonly) double fps;
@property (nonatomic, assign, readonly) double videoTimebase;
- (int)frameWidth;
- (int)frameHeight;
- (double)duration;

// Audio info
- (BOOL)validAudio;
@property (nonatomic, assign, readonly) double audioTimebase;
- (int)sampleRate;
- (int)channels;


@end


FOUNDATION_EXTERN NSString *const RtmpTcurlKey;
FOUNDATION_EXTERN NSString *const ProbeSizeKey;
FOUNDATION_EXTERN NSString *const MaxAnalyzeDuraionArrayKey;
FOUNDATION_EXTERN NSString *const FpsProbeSizeEnableKey;


NS_ASSUME_NONNULL_END
