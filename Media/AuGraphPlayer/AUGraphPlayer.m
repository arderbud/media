//
//  AUGraphPlayer.m
//  Media
//
//  Created by arderbud on 2019/9/10.
//  Copyright © 2019 arderbud. All rights reserved.
//  Refer to: https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitHostingGuide_iOS/AudioUnitHostingFundamentals/AudioUnitHostingFundamentals.html#//apple_ref/doc/uid/TP40009492-CH3-SW43
//

#import "AUGraphPlayer.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

static void CheckStatus(OSStatus status, NSString *message, BOOL fatal) {
    if(status != noErr) {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';
        
        if(isprint(fourCC[0]) && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[3]))
            NSLog(@"%@: %s", message, fourCC);
        else
            NSLog(@"%@: %d", message, (int)status);
        
        if(fatal)
            exit(-1);
    }
}


@implementation AUGraphPlayer {
    AUGraph   _playerGraph;
    
    AUNode    _remoteIONode,_playerNode,_splitterNode,_accMixerNode,_vocalMixerNode;
    AudioUnit _remoteIOUnit,_playerUnit,_splitterUnit,_accMixerUnit,_vocalMixerUnit;
    
    NSURL*    _palyFileURL;
}

+ (instancetype)sharedInstance {
    static AUGraphPlayer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AUGraphPlayer alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self prepareAudioSession];
        [self initGraph];
    }
    return self;
}

- (void)prepareAudioSession {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [session setPreferredSampleRate:44100 error:&error];
    [session setActive:YES error:&error];
    [self removeAudioSessionInterruptedObserver];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
}
- (void)initGraph {
    OSStatus status = noErr;
    AudioComponentDescription ioDesc;
    AudioComponentDescription playerDesc;
    AudioComponentDescription splitterDesc;
    AudioComponentDescription mixerDesc;
    AudioStreamBasicDescription asbd = {0};
    UInt32 bytesPerSample = sizeof(Float32);
    int vocalMixerElementCount = 1, accMixerElementCount = 2;
  
    status = NewAUGraph(&_playerGraph);
    CheckStatus(status, @"Could not create a new graph", YES);
    
    ioDesc = (AudioComponentDescription){
        .componentType         = kAudioUnitType_Output,
        .componentSubType      = kAudioUnitSubType_RemoteIO,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags        = 0,
        .componentFlagsMask    = 0
    };
    status = AUGraphAddNode(_playerGraph, &ioDesc, &_remoteIONode);
    CheckStatus(status, @"Could not add I/O node to AUGraph", YES);
    
    playerDesc = (AudioComponentDescription) {
        .componentType         = kAudioUnitType_Generator,
        .componentSubType      = kAudioUnitSubType_AudioFilePlayer,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags        = 0,
        .componentFlagsMask    = 0
    };
    status = AUGraphAddNode(_playerGraph, &playerDesc, &_playerNode);
    CheckStatus(status, @"Could not add player node to AUGraph", YES);
    
    splitterDesc = (AudioComponentDescription) {
        .componentType         = kAudioUnitType_FormatConverter,
        .componentSubType      = kAudioUnitSubType_Splitter,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags        = 0,
        .componentFlagsMask    = 0
    };
    status = AUGraphAddNode(_playerGraph, &splitterDesc, &_splitterNode);
    CheckStatus(status, @"Could not add splitter node to AUGraph", YES);
    
    mixerDesc = (AudioComponentDescription) {
        .componentType         = kAudioUnitType_Mixer,
        .componentSubType      = kAudioUnitSubType_MultiChannelMixer,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags        = 0,
        .componentFlagsMask    = 0
    };
    status = AUGraphAddNode(_playerGraph, &mixerDesc, &_vocalMixerNode);
    CheckStatus(status, @"Could not add VocalMixer node to AUGraph", YES);
    status = AUGraphAddNode(_playerGraph, &mixerDesc, &_accMixerNode);
    CheckStatus(status, @"Could not add AccMixer node to AUGraph", YES);
    
    status = AUGraphOpen(_playerGraph);
    CheckStatus(status, @"Could not open AUGraph", YES);
    status = AUGraphNodeInfo(_playerGraph, _remoteIONode, NULL, &_remoteIOUnit);
    CheckStatus(status, @"Could not retrieve node info for I/O node", YES);
    status = AUGraphNodeInfo(_playerGraph, _playerNode, NULL, &_playerUnit);
    CheckStatus(status, @"Could not retrieve node info for Player node", YES);
    status = AUGraphNodeInfo(_playerGraph, _splitterNode, NULL, &_splitterUnit);
    CheckStatus(status, @"Could not retrieve node info for Splitter node", YES);
    status = AUGraphNodeInfo(_playerGraph, _vocalMixerNode, NULL, &_vocalMixerUnit);
    CheckStatus(status, @"Could not retrieve node info for VocalMixer node", YES);
    status = AUGraphNodeInfo(_playerGraph, _accMixerNode, NULL, &_accMixerUnit);
    CheckStatus(status, @"Could not retrieve node info for AccMixer node", YES);
    
    asbd.mSampleRate       = 44100;
    asbd.mFormatID         = kAudioFormatLinearPCM;
    asbd.mFormatFlags      = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    asbd.mBytesPerFrame    = bytesPerSample;
    asbd.mFramesPerPacket  = 1;
    asbd.mBytesPerPacket   = bytesPerSample;
    asbd.mChannelsPerFrame = 2;
    asbd.mBitsPerChannel   = 8 * bytesPerSample;
    
    status = AudioUnitSetProperty(_playerUnit,     kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &asbd, sizeof(asbd));
    CheckStatus(status, @"Could not Set StreamFormat for Player Unit", YES);
    
    status = AUGraphConnectNodeInput(_playerGraph, _playerNode, 0, _splitterNode, 0);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    status = AUGraphConnectNodeInput(_playerGraph, _splitterNode, 0, _vocalMixerNode, 0);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    status = AUGraphConnectNodeInput(_playerGraph, _splitterNode, 1, _accMixerNode, 0);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    status = AUGraphConnectNodeInput(_playerGraph, _vocalMixerNode, 0, _accMixerNode, 1);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    AUGraphConnectNodeInput(_playerGraph, _accMixerNode, 0, _remoteIONode, 0);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    
    status = AUGraphInitialize(_playerGraph);
    CheckStatus(status, @"Couldn't Initialize the graph", YES);
    CAShow(_playerGraph);

}

- (void)setupFilePlayer:(NSString *)path {
    
    OSStatus status = noErr;
    AudioFileID audioFile;
    CFURLRef audioURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (__bridge CFStringRef)path, kCFURLPOSIXPathStyle,false);
    AudioStreamBasicDescription fileASBD = {0};
    UInt32 filePropSize = sizeof(fileASBD);
    UInt64 packetCount;
    UInt32 packetPropSize = sizeof(packetCount);
    ScheduledAudioFileRegion safr = {0};
    UInt32 defaultVal = 0;
    AudioTimeStamp startTime = {0};
    
    
    status = AudioFileOpenURL(audioURL, kAudioFileReadPermission, 0, &audioFile);
    CheckStatus(status, @"Open AudioFile... ", YES);
    status = AudioUnitSetProperty(_playerUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &audioFile, sizeof(audioFile));
    CheckStatus(status, @"Tell AudioFile Player Unit Load Which File... ", YES);
    
    status = AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &filePropSize, &fileASBD);
    CheckStatus(status, @"get the audio data format from the file... ", YES);
    status = AudioFileGetProperty(audioFile, kAudioFilePropertyAudioDataPacketCount,&packetPropSize, &packetCount);
    CheckStatus(status, @"get the audio data packet count from the file... ", YES);
    
    safr.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    safr.mTimeStamp.mSampleTime = 0;
    safr.mCompletionProc = NULL;
    safr.mCompletionProcUserData = NULL;
    safr.mAudioFile = audioFile;
    safr.mLoopCount = 0;
    safr.mStartFrame = 0;
    safr.mFramesToPlay = (UInt32)packetCount * fileASBD.mFramesPerPacket;
    status = AudioUnitSetProperty(_playerUnit, kAudioUnitProperty_ScheduledFileRegion,
                                  kAudioUnitScope_Global, 0,&safr, sizeof(safr));
    CheckStatus(status, @"Set Region... ", YES);
    status = AudioUnitSetProperty(_playerUnit, kAudioUnitProperty_ScheduledFilePrime,
                                  kAudioUnitScope_Global, 0, &defaultVal, sizeof(defaultVal));
    CheckStatus(status, @"Prime Player Unit With Default Value... ", YES);
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    status = AudioUnitSetProperty(_playerUnit, kAudioUnitProperty_ScheduleStartTimeStamp,
                                  kAudioUnitScope_Global, 0, &startTime, sizeof(startTime));
    CheckStatus(status, @"set Player Unit Start Time... ", YES);
    
    CFRelease(audioURL);
}


- (void)setInputSource:(BOOL)isAcc {
    OSStatus status = noErr;
    AudioUnitParameterValue value;
    status = AudioUnitGetParameter(_vocalMixerUnit, kMultiChannelMixerParam_Volume,kAudioUnitScope_Input, 0, &value);
    CheckStatus(status, @"get parameter fail", YES);
    NSLog(@"Vocal Mixer %lf", value);
    status = AudioUnitGetParameter(_accMixerUnit,   kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, &value);
    CheckStatus(status, @"get parameter fail", YES);
    NSLog(@"Acc Mixer 0 %lf", value);
    status = AudioUnitGetParameter(_accMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 1, &value);
    CheckStatus(status, @"get parameter fail", YES);
    NSLog(@"Acc Mixer 1 %lf", value);
    
    if(isAcc) {
        status = AudioUnitSetParameter(_accMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 0.1, 0);
        CheckStatus(status, @"set parameter fail", YES);
        status = AudioUnitSetParameter(_accMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 1, 1,   0);
        CheckStatus(status, @"set parameter fail", YES);
    } else {
        status = AudioUnitSetParameter(_accMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1,   0);
        CheckStatus(status, @"set parameter fail", YES);
        status = AudioUnitSetParameter(_accMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 1, 0.1, 0);
        CheckStatus(status, @"set parameter fail", YES);
    }
}

// AudioSession 被打断的通知
- (void)addAudioSessionInterruptedObserver
{
    [self removeAudioSessionInterruptedObserver];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
}

- (void)removeAudioSessionInterruptedObserver
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:nil];
}

- (void)onNotificationAudioInterrupted:(NSNotification *)sender {
    AVAudioSessionInterruptionType interruptionType = [[[sender userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    switch (interruptionType) {
        case AVAudioSessionInterruptionTypeBegan:
            [self stop];
            break;
        case AVAudioSessionInterruptionTypeEnded:
            [self play];
            break;
        default:
            break;
    }
}

- (void)playWithFilePath:(NSString *)path {
    [self setupFilePlayer:path];
    [self play];
}

- (void)stop {
    Boolean isRunning = false;
    OSStatus status = AUGraphIsRunning(_playerGraph, &isRunning);
    if (isRunning) {
        status = AUGraphStop(_playerGraph);
        CheckStatus(status, @"Could not stop AUGraph", YES);
    }
}

- (void)play {
    OSStatus status = AUGraphStart(_playerGraph);
    CheckStatus(status, @"Could not start AUGraph", YES);
}


@end
