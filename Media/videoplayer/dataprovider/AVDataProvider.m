//
//  AVDataProvider.m
//  Media
//
//  Created by arderbud on 2019/10/16.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <pthread.h>

#import "AVDataProvider.h"



#define PREPARED_BUFFER_DURATION 0.5
#define AV_SYNC_TOLERANCE        0.05


@interface AVDataProvider ()
@property (nonatomic, assign) BOOL opened;
@end
@implementation AVDataProvider {
    VideoDecoder *_videoDecoder;
    
    pthread_attr_t  _decoderThreadAttr;
    pthread_mutex_t _bufferLock;
    pthread_cond_t  _bufferCond;
    
    BOOL     _stop;
    BOOL     _preparedBufferFinished;
    NSMutableArray<VideoFrame *> *_videoBuffer;
    NSMutableArray<AudioFrame *> *_audioBuffer;
    float           _bufferDuration;
    
    NSData  *_currentAudioSampleData;
    NSUInteger _lastAudioDataReadPos;
    float   _currentAudioPos;
    VideoFrame *_currentVideoFrame;
    
    BOOL _completed;
    CGFloat _syncTolerance;
}

static void *deocoderThreadRoutine(void *arg) {
    AVDataProvider *dataProvider = (__bridge AVDataProvider *)arg;
    pthread_mutex_lock(&dataProvider->_bufferLock);
    while (!dataProvider->_stop) {
        pthread_cond_wait(&dataProvider->_bufferCond, &dataProvider->_bufferLock);
        float needDuration = dataProvider->_maxBufferDuration - dataProvider->_bufferDuration;
        NSLog(@"After wait point -> buffer duration:%f",dataProvider->_bufferDuration);
        [dataProvider decodeFramesWithDuration:needDuration];
    }
    pthread_mutex_unlock(&dataProvider->_bufferLock);
    return NULL;
}

static void *prepareBufferThreadRoutine(void *arg) {
    AVDataProvider *dataProvider = (__bridge AVDataProvider *)arg;
    pthread_mutex_lock(&dataProvider->_bufferLock);
    [dataProvider decodeFramesWithDuration:PREPARED_BUFFER_DURATION];
    dataProvider->_preparedBufferFinished = YES;
    pthread_cond_signal(&dataProvider->_bufferCond);
    pthread_mutex_unlock(&dataProvider->_bufferLock);
    return NULL;
}

- (void)decodeFramesWithDuration:(CGFloat)duration {
    NSArray *frames = [_videoDecoder decodeFramesWithMinDuration:duration error:nil];
    if (frames.count) {
        for (FrameBase *frame in frames) {
            if (frame.type == FrameTypeVideo) {
                [_videoBuffer addObject:(VideoFrame *)frame];
            } else if (frame.type == FrameTypeAudio) {
                [_audioBuffer addObject:(AudioFrame *)frame];
                _bufferDuration += frame.duration;
            }
        }
    }
}

- (instancetype)initWithFileURL:(NSURL *)fileURL {
    if (self = [super init]) {
        _fileURL = fileURL;
        _minBufferDuration = 0.5;
        _maxBufferDuration = 1.0;
        _syncTolerance = AV_SYNC_TOLERANCE;
        _videoBuffer = [NSMutableArray array];
        _audioBuffer = [NSMutableArray array];
        pthread_mutex_init(&_bufferLock, NULL);
        pthread_cond_init(&_bufferCond, NULL);
        pthread_attr_init(&_decoderThreadAttr);
        pthread_attr_setdetachstate(&_decoderThreadAttr, PTHREAD_CREATE_DETACHED);
    }
    return self;
}

- (instancetype)init {
    @throw [NSException exceptionWithName:@"Invalid method call" reason:@"Use `-initWithFileURL:` instead." userInfo:nil];
}

+ (instancetype)new {
    @throw [NSException exceptionWithName:@"Invalid method call" reason:@"Use `-initWithFileURL:` instead." userInfo:nil];
}


-  (OpenState)openFileWithOptions:(NSDictionary *)options Error:(NSError **)error;{
    BOOL ret;
    
    if (nil == _fileURL ) {
        if (error) {
            *error = [NSError errorWithDomain:@"MediaPlayer" code:100 userInfo:nil];
            return OPEN_FAILED;
        }
    }
    
    _videoDecoder = [[VideoDecoder alloc] initWithFileURL:_fileURL];
    ret = [_videoDecoder openFileWithOptions:options error:error];
    if (!ret) {
        return OPEN_FAILED;
    }
    [self prepareBuffer];
    _opened = YES;
    [self run];
    return OPEN_SUCCESS;
}

- (void)prepareBuffer {
    pthread_t tid;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    pthread_create(&tid,&attr , prepareBufferThreadRoutine, (__bridge void *)self);
}

- (BOOL)run {
    pthread_t tid;
    if (!_opened) {
        NSLog(@"Must open file before run!");
        return NO;
    }
    pthread_create(&tid, &_decoderThreadAttr, deocoderThreadRoutine, (__bridge void *)self);
    return YES;
}


- (void)fillAudioData:(SInt16 *)outData nbFrames:(UInt32)nbFrames nbChannels:(UInt32)nbChannels {
    BOOL valid = [self checkBufferValid];
    NSUInteger bytesCopied = 0;
    NSUInteger bytesNeeded = sizeof(SInt16) * nbChannels * nbFrames;
    if (!valid) {
        memset(outData, 0, bytesNeeded);
        return;
    }
    
    while (nbFrames > 0) {
        if (!_currentAudioSampleData) {
            pthread_mutex_lock(&_bufferLock);
            NSUInteger count = _audioBuffer.count;
            if (count > 0) {
                AudioFrame *audioFrame = [_audioBuffer firstObject];
                _bufferDuration -= audioFrame.duration;
                [_audioBuffer removeObjectAtIndex:0];
                _currentAudioPos = audioFrame.position;
                _currentAudioSampleData = audioFrame.samples;
                _lastAudioDataReadPos = 0;
            }
            pthread_mutex_unlock(&_bufferLock);
        }
        if (_currentAudioSampleData) {
            const void *start = (Byte *)_currentAudioSampleData.bytes + _lastAudioDataReadPos;
            const NSUInteger bytesLeft = _currentAudioSampleData.length - _lastAudioDataReadPos;
            const NSUInteger bytesPerFrame = nbChannels * sizeof(SInt16);
            const NSUInteger bytesToCopy = MIN(nbFrames * bytesPerFrame,bytesLeft);
            const NSUInteger framesToCopy = bytesToCopy / bytesPerFrame;
            memcpy(outData, start, bytesToCopy);
            bytesCopied += bytesToCopy;
            nbFrames -= framesToCopy;
            outData += framesToCopy * nbChannels;
            
            if (bytesToCopy < bytesLeft)
                _lastAudioDataReadPos += bytesToCopy;
            else
                _currentAudioSampleData = nil;
        } else {
            memset(outData, 0, bytesNeeded - bytesCopied);
            break;
        }
    }

}

- (VideoFrame *)getCorrespondVideoFrame {
    VideoFrame *videoFrame = nil;
    pthread_mutex_lock(&_bufferLock);
    while (_videoBuffer.count > 0) {
        videoFrame = [_videoBuffer firstObject];
        CGFloat delta = _currentAudioPos - videoFrame.position;
        if (delta < -_syncTolerance) {
            NSLog(@"Audio slower than video, render pre video frame.");
            videoFrame = nil;
            break;
        }
        [_videoBuffer removeObjectAtIndex:0];
        if (delta > _syncTolerance) {
            NSLog(@"Video slower than audio,skip the video frame.");
            videoFrame = nil;
            continue;
        } else {
            break;
        }
    }
    pthread_mutex_unlock(&_bufferLock);
    
    if (videoFrame)
        _currentVideoFrame = videoFrame;
    
    return videoFrame;
    
}

- (BOOL)checkBufferValid {
    BOOL valid = NO;
    int leftVideoFrames,leftAudioFrames;
    if (nil == _videoDecoder)
        return NO;
    
    leftVideoFrames = _videoDecoder.validVideo ? (int)_videoBuffer.count : 0;
    leftAudioFrames = _videoDecoder.validAudio ? (int)_audioBuffer.count : 0;
    if (0 == leftAudioFrames /*|| 0 == leftVideoFrames*/) {
        if ([_videoDecoder isEOF]) {
            // Notify completion
            _completed = YES;
            NSLog(@"file is EOF!!");
            valid = NO;
        } else {
            valid = NO;
        }
    } else {
        valid = YES;
    }
    
    pthread_mutex_lock(&_bufferLock);
    if (_preparedBufferFinished && (_bufferDuration < _minBufferDuration)) {
        NSLog(@"Signal point -> buffer duraion:%f %f %d",_bufferDuration,_minBufferDuration,_bufferDuration < _minBufferDuration);
        pthread_cond_signal(&_bufferCond);
    }
    pthread_mutex_unlock(&_bufferLock);
    return valid;
}


- (int)getAudioSampleRate {
    return _videoDecoder ? [_videoDecoder sampleRate] : -1;
}

- (int)getAudioChannels {
    return _videoDecoder ? [_videoDecoder channels] : -1;
}

- (double)getVideoFPS {
    return _videoDecoder ? [_videoDecoder fps] : 0;
}

- (int)getVideoFrameWidth {
    return _videoDecoder ? [_videoDecoder frameWidth] : 0;
}

- (int)getVideoFrameHeight {
    return _videoDecoder ? [_videoDecoder frameHeight] : 0;
}

- (double)getDuration {
    return _videoDecoder ? [_videoDecoder duration] : 0;
}

- (BOOL)completed {
    return _completed;
}

@end
