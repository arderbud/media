//
//  AudioOutput.h
//  Media
//
//  Created by arderbud on 2019/10/15.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AudioOutputDataSource <NSObject>

// interleaved 
- (NSInteger)fillAudioData:(UInt8 *)buffer
            bytesPerSample:(UInt8)bytesPerSample
                  nbFrames:(UInt32)frames
                nbChannels:(UInt32)channels;

@end

@interface AudioOutput : NSObject

@property (nonatomic, readonly, assign) UInt32 sampleRate;
@property (nonatomic, readonly, assign) UInt32 channels;
@property (nonatomic, readonly, assign) UInt32 bytesPerSample;
@property (nonatomic, weak) id<AudioOutputDataSource> dataSource;

// interger format
- (instancetype)initWithBytesPerSample:(UInt32)bytes
                          sampleteRate:(UInt32)samplteRate
                            nbChannels:(UInt32)channels;

- (void)play;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
