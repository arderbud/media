//
//  AudioOutput.m
//  Media
//
//  Created by arderbud on 2019/10/15.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "AudioOutput.h"
#import <AudioToolbox/AudioToolbox.h>

#ifndef PAGE_SIZE
#define PAGE_SIZE 4096
#endif

static OSStatus inputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData);

@implementation AudioOutput {
    AUGraph _processingGraph;
    AUNode  _ioNode,_convertNode;
    AudioUnit _ioUnit,_convertUnit;
    UInt8 *_outData;
    
}

OSStatus inputRenderCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    AudioOutput *audioOutput = (__bridge id)inRefCon;
    return [audioOutput renderData:ioData atTimeStamP:inTimeStamp forElement:inBusNumber numberFrames:inNumberFrames flags:ioActionFlags];
                        
}

- (instancetype)initWithBytesPerSample:(UInt32)bytes sampleteRate:(UInt32)samplteRate nbChannels:(UInt32)channels {
    self = [super init];
    if (self) {
        _channels = channels;
        _bytesPerSample = bytes;
        _sampleRate = samplteRate;
        _outData = (UInt8 *)malloc(PAGE_SIZE);
        [self _constructProcessingGraph];
    }
    return self;
}

- (void)_constructProcessingGraph {
    [self _createNodes];
    [self _connetNodes];
    [self _setNodesProperty];
    
    AUGraphInitialize(_processingGraph);
    CAShow(_processingGraph);
}

- (void)_createNodes {
    NewAUGraph(&_processingGraph);
    AudioComponentDescription ioUnitDesc;
    AudioComponentDescription convertUnitDesc;
    
    ioUnitDesc.componentType         = kAudioUnitType_Output;
    ioUnitDesc.componentSubType      = kAudioUnitSubType_RemoteIO;
    ioUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioUnitDesc.componentFlags        = 0;
    ioUnitDesc.componentFlagsMask    = 0;
    AUGraphAddNode(_processingGraph, &ioUnitDesc, &_ioNode);
    
    convertUnitDesc.componentType         = kAudioUnitType_FormatConverter;
    convertUnitDesc.componentSubType      = kAudioUnitSubType_AUConverter;
    convertUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    convertUnitDesc.componentFlags        = 0;
    convertUnitDesc.componentFlagsMask    = 0;
    AUGraphAddNode(_processingGraph, &convertUnitDesc, &_convertNode);

    AUGraphOpen(_processingGraph);
    AUGraphNodeInfo(_processingGraph, _ioNode, NULL, &_ioUnit);
    AUGraphNodeInfo(_processingGraph, _convertNode, NULL, &_convertUnit);
}

- (void)_connetNodes {
    AUGraphConnectNodeInput(_processingGraph, _convertNode, 0, _ioNode, 0);
}

- (void)_setNodesProperty {
    AURenderCallbackStruct renderCallback;
    AudioStreamBasicDescription stereoStreamFormat = {0};
    AudioStreamBasicDescription clientStreamFormat = {0};
    int stereoBytesPerSample = sizeof(Float32);
    
    renderCallback.inputProc = &inputRenderCallback;
    renderCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(_convertUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderCallback, sizeof(renderCallback));
    
    clientStreamFormat.mFormatID         = kAudioFormatLinearPCM;
    clientStreamFormat.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked; // interleaved
    clientStreamFormat.mBytesPerPacket   = _bytesPerSample * _channels;
    clientStreamFormat.mBytesPerFrame    = _bytesPerSample * _channels;
    clientStreamFormat.mFramesPerPacket  = 1;
    clientStreamFormat.mBitsPerChannel   = 8 * _bytesPerSample;
    clientStreamFormat.mChannelsPerFrame = _channels;
    clientStreamFormat.mSampleRate       = _sampleRate;
    AudioUnitSetProperty(_convertUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &clientStreamFormat, sizeof(clientStreamFormat));// 指定格式
    
    stereoStreamFormat.mFormatID         = kAudioFormatLinearPCM;
    stereoStreamFormat.mFormatFlags      = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    stereoStreamFormat.mBytesPerPacket   = stereoBytesPerSample;
    stereoStreamFormat.mBytesPerFrame    = stereoBytesPerSample;
    stereoStreamFormat.mFramesPerPacket  = 1;
    stereoStreamFormat.mBitsPerChannel   = 8 *stereoBytesPerSample;
    stereoStreamFormat.mChannelsPerFrame = 2;
    stereoStreamFormat.mSampleRate       = _sampleRate;
    AudioUnitSetProperty(_convertUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &stereoStreamFormat, sizeof(stereoStreamFormat)); // 指定格式
    

}

- (OSStatus)renderData:(AudioBufferList *)ioData
           atTimeStamP:(const AudioTimeStamp *)inTimeStamp
            forElement:(UInt32)inBusNumber
          numberFrames:(UInt32)inNumberFrames
                 flags:(AudioUnitRenderActionFlags *)ioActionsFlags {
    if (ioData->mNumberBuffers != 1) {
        NSLog(@"AudioUnit error");
        return -1;
    }
    if (_dataSource) {
        int needSize = inNumberFrames * _bytesPerSample * _channels;
        if (needSize > PAGE_SIZE)
            _outData = realloc(_outData, needSize);
        [_dataSource fillAudioData:_outData nbFrames:inNumberFrames nbChannels:_channels];
        // 需要数据
        memcpy((UInt8 *)ioData->mBuffers[0].mData, (UInt8 *)_outData, ioData->mBuffers[0].mDataByteSize);
        return noErr;
    } else {
        NSLog(@"Can't provide audio data");
        return -1;
    }
    
}

- (void)play {
    AUGraphStart(_processingGraph);
}

- (void)stop {
    AUGraphStop(_processingGraph);
}


@end
