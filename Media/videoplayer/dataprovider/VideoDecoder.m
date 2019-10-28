//
//  VideoDecoder.m
//  Media
//
//  Created by arderbud on 2019/9/27.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "VideoDecoder.h"
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavutil/pixdesc.h"
//#include "libavcodec/avcodec.h"

static NSData *copyFrameData(UInt8 *src,int linesize, int width,int height) {
    width = MIN(linesize, width);
    NSMutableData *data = [NSMutableData dataWithLength:width * height];
    Byte *dst = data.mutableBytes;
    for (int i = 0; i < height; i++) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return data;
}
static int selectSpecStream(AVFormatContext *formatCtx,enum AVMediaType codecType) {
    for (int i = 0; i < formatCtx->nb_streams; ++i)
        if (codecType == formatCtx->streams[i]->codecpar->codec_type)
            return i;
    return -1;
}

static void AVStreamGetFpsAndTimebase(AVStream *st,AVCodecContext *avCtx, double defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase) {
    double fps,timebase;
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if (avCtx->time_base.den && avCtx->time_base.num)
        timebase = av_q2d(avCtx->time_base);
    else
        timebase = defaultTimeBase;
    
    if (avCtx->ticks_per_frame != 1)
        NSLog(@"WARNING: st.codec.ticks_per_frame=%d",avCtx->ticks_per_frame);
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    if (pFPS)
        *pFPS = fps;
    if (pTimeBase)
        *pTimeBase = timebase;
}


@implementation BuriedPoint

@end

@implementation FrameBase

@end

@implementation AudioFrame

@end

@implementation VideoFrame

@end

@interface VideoDecoderContext : NSObject
@property (nonatomic, assign) int connectionRetry;
@property (nonatomic, assign) int totalVideoFrameCount;
@property (nonatomic, assign) float totalAudioDuration;
@property (nonatomic, assign)long long decodeVideoFrameWasteTimeMills;
@property (nonatomic, assign) int subscribeTimeout;
@property (nonatomic, assign) BOOL interrupted;
@property (nonatomic, assign, getter=isOpenSuccess) BOOL openSuccess;
@property (nonatomic, assign) BOOL isSubcribe;
@property (nonatomic, strong) BuriedPoint *buriedPoint;
@property (nonatomic, assign) AVFormatContext* formatCtx;
@property (nonatomic, assign) SwrContext*      swrContext;
@property (nonatomic, assign) struct SwsContext*      swsContext;
@property (nonatomic, assign) AVCodecContext*  videoCodecCtx;
@property (nonatomic, assign) AVCodecContext*  audioCodecCtx;
@property (nonatomic, assign) unsigned long videoStreamIndex;
@property (nonatomic, assign) unsigned long audioStreamIndex;
@property (nonatomic, assign) int           readLastestFrameTime;
@property (nonatomic, assign) int decodePosition;
@end

@implementation VideoDecoderContext

@end



@interface VideoDecoder ()
@property (nonatomic, strong) VideoDecoderContext *decoderCtx;
@end


NSString *const RtmpTcurlKey = @"RtmpTcurlKey";
NSString *const ProbeSizeKey = @"ProbeSizeKey";
NSString *const MaxAnalyzeDuraionArrayKey = @"MaxAnalyzeDuraionArrayKey";
NSString *const FpsProbeSizeEnableKey = @"FpsProbeSizeEnableKey";

@implementation VideoDecoder {
    void *                      _swrBuffer;
    NSUInteger                  _swrBufferSize;
}


- (instancetype)init {
    @throw [NSException exceptionWithName:@"Unavilabel method" reason:@"Use `-initWithFileURL:` instead." userInfo:nil];
    return nil;
}

+ (instancetype)new {
    @throw [NSException exceptionWithName:@"Unavilabel method" reason:@"Use `-initWithFileURL:` instead." userInfo:nil];
    return nil;
}

- (instancetype)initWithFileURL:(NSURL *)fileURL {
    self = [super init];
    if (self) {
        _fileURL = fileURL;
    }
    return self;
}

static int interruptCallback(void *ctx) {
    if (!ctx)
        return 0;
    __unsafe_unretained VideoDecoder *decoder = (__bridge VideoDecoder*)ctx;
    return [decoder detectInterrupted];;
}


- (void)resetStatus:(VideoDecoderContext *)record {
    record.connectionRetry = 0;
    record.totalVideoFrameCount = 0;
    record.subscribeTimeout = SUBSCRIBE_VIDEO_DATA_TIME_OUT;
    record.openSuccess = NO;
    record.isSubcribe = NO;
    record.interrupted = NO;
    record.videoStreamIndex = -1;
    record.audioStreamIndex = -1;
}


- (VideoDecoderContext *)decoderCtx {
    if (!_decoderCtx) {
        _decoderCtx = [[VideoDecoderContext alloc] init];
    }
    return _decoderCtx;
}

- (BOOL)openFileWithOptions:(NSDictionary *)param error:(NSError **)error; {
    BOOL ret = YES;
    int  errorCode;
    BuriedPoint *buriedPoint;
    if (nil == _fileURL)
        return NO;
    
    [self resetStatus:self.decoderCtx];
    
    self.decoderCtx.readLastestFrameTime = [[NSDate date] timeIntervalSince1970];
    buriedPoint = [[BuriedPoint alloc] init];
    self.decoderCtx.buriedPoint = buriedPoint;
    buriedPoint.beginOpen = [[NSDate date] timeIntervalSince1970] * 1000;
    
    errorCode = [self openInput:[self.fileURL absoluteString] options:param];
    if (errorCode < 0) {
        buriedPoint.failOpen = ([[NSDate date] timeIntervalSince1970] * 1000 - buriedPoint.beginOpen) / 1000.0f;
        buriedPoint.successOpen = 0.0f;
        buriedPoint.failOpenCode = errorCode;
        ret = NO;
    } else {
        buriedPoint.successOpen = ([[NSDate date] timeIntervalSince1970] * 1000 - buriedPoint.beginOpen) / 1000.0f;
        buriedPoint.failOpen = 0.0f;
        buriedPoint.failOpenCode = 0;
        if (![self openVideoStream] || ![self openAudioStream]) {
            [self closeFile];
            ret = NO;
        }
    }
    
    return ret;
}

- (BOOL)openVideoStream {
    int videoStreamIndex;
    AVStream *stream;
    AVCodecContext *avCtx;
    AVCodec *codec;
    int error;
    
    videoStreamIndex = selectSpecStream(self.decoderCtx.formatCtx, AVMEDIA_TYPE_VIDEO);
    if (videoStreamIndex == -1)
        return NO;
    
    stream = self.decoderCtx.formatCtx->streams[videoStreamIndex];
    codec = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!codec) {
        NSLog(@"Find Video Decoder Failed codec_id %d CODEC_ID_H264 is %d", stream->codecpar->codec_id, AV_CODEC_ID_H264);
        return NO;
    }
    avCtx = avcodec_alloc_context3(codec);
    avcodec_parameters_to_context(avCtx, stream->codecpar);
    
    error = avcodec_open2(avCtx, codec, NULL);
    if (error < 0) {
        NSLog(@"open Video Codec Failed openCodecErr is %s", av_err2str(error));
        return NO;
    }
    
    self.decoderCtx.videoStreamIndex = videoStreamIndex;
    self.decoderCtx.videoCodecCtx = avCtx;
    AVStreamGetFpsAndTimebase(stream, avCtx, 0.04, &_fps, &_videoTimebase);
    
    return YES;
}

- (BOOL)openAudioStream {
    int audioStreamIndex;
    AVStream *stream;
    AVCodec  *codec;
    AVCodecContext *avCtx;
    SwrContext *swrCtx;
    int error;
    
    audioStreamIndex = selectSpecStream(self.decoderCtx.formatCtx, AVMEDIA_TYPE_AUDIO);
    if (audioStreamIndex == -1)
        return NO;
    stream = self.decoderCtx.formatCtx->streams[audioStreamIndex];
    codec = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!codec) {
        NSLog(@"Find Audio Decoder Failed codec_id %d CODEC_ID_H264 is %d", stream->codecpar->codec_id, AV_CODEC_ID_AAC);
        return NO;
    }
    avCtx = avcodec_alloc_context3(codec);
    avcodec_parameters_to_context(avCtx, stream->codecpar);
    
    error = avcodec_open2(avCtx, codec, NULL);
    if (error < 0) {
        NSLog(@"Open Audio Codec Failed openCodecErr is %s", av_err2str(error));
        return NO;
    }
    if (![self audioCodecIsSupported:avCtx]) {
        NSLog(@"Because of audio Codec Is Not Supported so we will init swresampler...");
        swrCtx = swr_alloc_set_opts(NULL,
                                    AV_CH_LAYOUT_STEREO, AV_SAMPLE_FMT_S16,avCtx->sample_rate,
                                    avCtx->channel_layout, avCtx->sample_fmt, avCtx->sample_rate,
                                    0, NULL);
        if (!swrCtx || swr_init(swrCtx)) {
            if (swrCtx)
                swr_free(&swrCtx);
            avcodec_close(avCtx);
            NSLog(@"init resampler failed...");
            return NO;
        }
        
        self.decoderCtx.audioStreamIndex = audioStreamIndex;
        self.decoderCtx.audioCodecCtx = avCtx;
        self.decoderCtx.swrContext = swrCtx;
        
        AVStreamGetFpsAndTimebase(stream, avCtx, 0.025, 0, &_audioTimebase);
    }
    

    return YES;
}

- (BOOL)audioCodecIsSupported:(AVCodecContext *) audioCodecCtx;
{
    if (audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_S16) {
        return true;
    }
    return false;
}

- (void)closeFile{
    NSLog(@"Enter close file...");
    VideoDecoderContext *decoderCtx = self.decoderCtx;
    BuriedPoint *buriedPoint = decoderCtx.buriedPoint;

    if (buriedPoint.failOpenCode == 0) {
        buriedPoint.duration = ([[NSDate date] timeIntervalSince1970] * 1000 - buriedPoint.beginOpen) / 1000.0f;
    }
    [self interrupt];
    [self closeAudioStream:decoderCtx];
    [self closeVideoStream:decoderCtx];

    if (decoderCtx.formatCtx) {
        AVFormatContext *fmtCtx = decoderCtx.formatCtx;
        fmtCtx->interrupt_callback.opaque = NULL;
        fmtCtx->interrupt_callback.callback = NULL;
        avformat_close_input(&fmtCtx);
        decoderCtx.formatCtx = NULL;
    }
    
    float decodeFrameAVGTimeMills = (double)decoderCtx.decodeVideoFrameWasteTimeMills / (float)decoderCtx.totalVideoFrameCount;
    NSLog(@"Decoder decoder totalVideoFramecount is %d decodeFrameAVGTimeMills is %.3f", decoderCtx.totalVideoFrameCount, decodeFrameAVGTimeMills);
    
}

- (void)closeAudioStream:(VideoDecoderContext *)ctx {
    ctx.audioStreamIndex = -1;
    if (_swrBuffer) {
        av_free(_swrBuffer);
        _swrBuffer = NULL;
        _swrBufferSize = 0;
    }
    
    if (ctx.swrContext) {
        SwrContext *swrCtx = ctx.swrContext;
        swr_free(&swrCtx);
        ctx.swrContext = NULL;
    }

    if (ctx.audioCodecCtx) {
        AVCodecContext *audioCodecCtx = ctx.audioCodecCtx;
        avcodec_close(audioCodecCtx);
        avcodec_free_context(&audioCodecCtx);
        ctx.audioCodecCtx = NULL;
    }
    
}

- (void)closeVideoStream:(VideoDecoderContext *)ctx {
    ctx.videoStreamIndex = -1;
    
    if (ctx.swsContext) {
        sws_freeContext(ctx.swsContext);
        ctx.swsContext = NULL;
    }

    if (ctx.videoCodecCtx) {
        AVCodecContext *videoCodecCtx = ctx.videoCodecCtx;
        avcodec_close(videoCodecCtx);
        avcodec_free_context(&videoCodecCtx);
        ctx.videoCodecCtx = NULL;
    }

}

- (NSArray<FrameBase *> *)decodeFramesWithMinDuration:(CGFloat)minDuration error:(int *)error {
    NSLog(@"Need duration:%f decode thread:%@",minDuration, [NSThread currentThread]);
    NSMutableArray <FrameBase *>*result = [NSMutableArray array];
//    AVPacket *packet;
    CGFloat  decodedDuration = 0;
    BOOL     finished = NO;
    int ret;
    VideoDecoderContext *decoderCtx = self.decoderCtx;
    
    if (decoderCtx.videoStreamIndex == -1 && decoderCtx.audioStreamIndex == -1)
        return nil;
//    packet = av_packet_alloc();
//    frame  = av_frame_alloc();
    av_init_packet(&pktBuffer);
    pktBuffer.size = 0;
    pktBuffer.data = NULL;
    
    while (!finished) {
        if ((ret = av_read_frame(decoderCtx.formatCtx, &pktBuffer)) < 0) {
            NSLog(@"Docode file to EOF!");
            _isEOF = YES;
            break;
        }
        double startDecodeTimeMills = 0;
        startDecodeTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
        if (pktBuffer.stream_index == decoderCtx.videoStreamIndex) {
            /*
            startDecodeTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
            VideoFrame *videoFrame = [self decodeVideoPacket:&pktBuffer];
            int wasteTimeMills = CFAbsoluteTimeGetCurrent() * 1000 - startDecodeTimeMills;
            decoderCtx.decodeVideoFrameWasteTimeMills += wasteTimeMills;
            if (videoFrame) {
                [result addObject:videoFrame];
                decoderCtx.totalVideoFrameCount++;
            }*/
        } else if (pktBuffer.stream_index == decoderCtx.audioStreamIndex) {
            float duration = 0;
            NSArray *audioFrames = [self decodeAuidoPacket:&pktBuffer totalDuration:&duration];
            if (audioFrames && [audioFrames count] > 0) {
                [result addObjectsFromArray:audioFrames];
                self.decoderCtx.decodePosition = ((AudioFrame *)[audioFrames lastObject]).position;
                self.decoderCtx.totalAudioDuration += duration;
                NSLog(@"total audio duration:%f",self.decoderCtx.totalAudioDuration);
                decodedDuration += duration;
            }
        }
        if (decodedDuration > minDuration)
            finished = YES;
        av_packet_unref(&pktBuffer);
    }
    
end:

    return [result copy];
}

- (VideoFrame *)decodeVideoPacket:(AVPacket *)packet {
    AVFrame *frame;
    VideoFrame *videoFrame;
    int ret;
    ret = avcodec_send_packet(self.decoderCtx.videoCodecCtx, packet);
    if (ret < 0) {
        NSLog(@"video send packet error");
        return nil;
    }
    frame = av_frame_alloc();
    while (0 == avcodec_receive_frame(self.decoderCtx.videoCodecCtx, frame)) {
        videoFrame= [self convertAVFrameToVideoFrame:frame];
        av_frame_unref(frame);
    }
    av_frame_free(&frame);
    return  videoFrame;
}

static AVPacket pktBuffer;

- (NSArray *)decodeAuidoPacket:(AVPacket *)packet totalDuration:(float *)duration {
    AVFrame *frame;
    AudioFrame *audioFrame;
    NSMutableArray *result;
    float durationStat = 0;
    if (0 != avcodec_send_packet(self.decoderCtx.audioCodecCtx, packet)) {
        NSLog(@"send packet error");
        return nil;
    }
    frame = av_frame_alloc();
    result = [NSMutableArray array];
    
    while (0 == avcodec_receive_frame(self.decoderCtx.audioCodecCtx, frame)) {
        audioFrame = [self convertAVFrameToAudioFrame:frame];
        if (audioFrame) {
            [result addObject:audioFrame];
            durationStat += audioFrame.duration;
        }
        av_frame_unref(frame);
    }
    *duration = durationStat;
    av_frame_free(&frame);
    return result;
}



- (AudioFrame *)convertAVFrameToAudioFrame:(AVFrame *)frame{
    AudioFrame *audioFrame = nil;
    int64_t    outChannelLayout = AV_CH_LAYOUT_STEREO;
    void       *audioData;
    int        numSamples;
    int        numElements;
    NSMutableData *pcmData;
    VideoDecoderContext *ctx = self.decoderCtx;
    
    if (!frame->data[0])
        return nil;
    if (ctx.swrContext) {
        const int bufSize = av_samples_get_buffer_size(NULL,
                                                       av_get_channel_layout_nb_channels(outChannelLayout),
                                                       ctx.audioCodecCtx->frame_size,
                                                       AV_SAMPLE_FMT_S16,
                                                       1);
        if (!_swrBuffer || _swrBufferSize < bufSize) {
            _swrBufferSize = bufSize;
            _swrBuffer = av_realloc(_swrBuffer, _swrBufferSize);
        }
        numSamples = swr_convert(ctx.swrContext, (uint8_t **)&_swrBuffer, frame->nb_samples,
                    (const uint8_t **)frame->data, frame->nb_samples);
        if (numSamples < 0) {
            NSLog(@"fail resample audio");
            return nil;
        }
        audioData = _swrBuffer;
    } else {
        if (ctx.audioCodecCtx->sample_fmt != AV_SAMPLE_FMT_S16) {
            NSLog(@"audio format is invalid");
            return nil;
        }
        audioData = frame->data[0];
        numSamples = frame->nb_samples;
    }
    
    
    numElements = numSamples * av_get_channel_layout_nb_channels(outChannelLayout);
    pcmData = [NSMutableData dataWithLength:numElements * sizeof(SInt16)];
    memcpy(pcmData.mutableBytes, audioData, numElements * sizeof(SInt16));
    audioFrame = [[AudioFrame alloc] init];
    audioFrame.position = frame->best_effort_timestamp * _audioTimebase;
    audioFrame.duration = frame->pkt_duration * _audioTimebase;
    audioFrame.samples  = pcmData;
    audioFrame.type     = FrameTypeAudio;
    
    return audioFrame;
}

- (VideoFrame *)convertAVFrameToVideoFrame:(AVFrame *)frame{
    VideoFrame *videoFrame;
    VideoDecoderContext *ctx = self.decoderCtx;
    if (!frame->data[0])
        return nil;
    videoFrame = [[VideoFrame alloc] init];
    if (ctx.videoCodecCtx->pix_fmt == AV_PIX_FMT_YUV420P ||
        ctx.videoCodecCtx->pix_fmt == AV_PIX_FMT_YUVJ420P) {
        videoFrame.luma = copyFrameData(frame->data[0],
                                        frame->linesize[0],
                                        ctx.videoCodecCtx->width,
                                        ctx.videoCodecCtx->height); // Y
        videoFrame.chromaB = copyFrameData(frame->data[1],
                                           frame->linesize[1],
                                           ctx.videoCodecCtx->width / 2,
                                           ctx.videoCodecCtx->height / 2 ); // U
        videoFrame.chromaR = copyFrameData(frame->data[2],
                                           frame->linesize[2],
                                           ctx.videoCodecCtx->width / 2 ,
                                           ctx.videoCodecCtx->height / 2); // V
        
    } else {
        AVFrame *swsFrame = av_frame_alloc();
        ctx.swsContext = sws_getCachedContext(ctx.swsContext,
                                           ctx.videoCodecCtx->width,
                                           ctx.videoCodecCtx->height,
                                           ctx.videoCodecCtx->pix_fmt,
                                           ctx.videoCodecCtx->width,
                                           ctx.videoCodecCtx->height,
                                           AV_PIX_FMT_YUV420P,
                                           SWS_FAST_BILINEAR,
                                           NULL, NULL, NULL);
        sws_scale(ctx.swsContext, (const uint8_t **)frame->data, frame->linesize, 0, ctx.videoCodecCtx->height, swsFrame->data, swsFrame->linesize);
        
        videoFrame.luma = copyFrameData(swsFrame->data[0],
                                        swsFrame->linesize[0],
                                        ctx.videoCodecCtx->width,
                                        ctx.videoCodecCtx->height);
        
        videoFrame.chromaR = copyFrameData(swsFrame->data[1],
                                           swsFrame->linesize[1],
                                           ctx.videoCodecCtx->width / 2,
                                           ctx.videoCodecCtx->height / 2);
        videoFrame.chromaB = copyFrameData(swsFrame->data[2],
                                           swsFrame->linesize[2],
                                           ctx.videoCodecCtx->width / 2,
                                           ctx.videoCodecCtx->height / 2);
        
    }
    
    videoFrame.width    = ctx.videoCodecCtx->width;
    videoFrame.height   = ctx.videoCodecCtx->height;
    videoFrame.linesize = frame->linesize[0];
    videoFrame.type     = FrameTypeVideo;
    videoFrame.position = frame->best_effort_timestamp * _videoTimebase;
    
    if (frame->pkt_duration) {
        videoFrame.duration = frame->pkt_duration * _videoTimebase;
        videoFrame.duration += frame->repeat_pict * _videoTimebase * 0.5;
    } else
        videoFrame.duration = 1.0 / _fps;
    
    return videoFrame;
}


/**
 @return 0 on success,fail on other.
 */
- (int)openInput:(NSString *)path options:(NSDictionary *)param {
    AVFormatContext *fmtCtx;
    int errorCode = 0;
    
    fmtCtx = avformat_alloc_context();
    fmtCtx->interrupt_callback = (AVIOInterruptCB){
        .callback = interruptCallback,
        .opaque   = (__bridge void *)self
    };
    errorCode = [self openFormatInput:&fmtCtx path:path options:param];
    if (errorCode < 0) {
        NSLog(@"Video decoder open input file failed... videoSourceURI is %@ openInputErr is %s", path, av_err2str(errorCode));
        goto fail;
    }
retry:
    [self setAnalyzeParameterForContext:fmtCtx options:param];
    errorCode = avformat_find_stream_info(fmtCtx, NULL);
    if (errorCode < 0) {
        NSLog(@"Video decoder find stream info failed... find stream ErrCode is %s", av_err2str(errorCode));
        goto fail;
    }
    if (fmtCtx->streams[0]->codecpar->codec_id == AV_CODEC_ID_NONE) {
        NSLog(@"Video decoder First Stream Codec ID Is UnKnown...");
        if ([self isNeedRetry])
            goto retry;
        else {
            errorCode = -33;
            goto fail;
        }
        
    }
    self.decoderCtx.formatCtx = fmtCtx;
    return 0;
    
fail:
    avformat_close_input(&fmtCtx);
    avformat_free_context(fmtCtx);
    return errorCode;
}

- (BOOL)isNeedRetry {
    return ++self.decoderCtx.connectionRetry <= NET_WORK_STREAM_RETRY_TIME;
}

- (void)setAnalyzeParameterForContext:(AVFormatContext *)fmtCtx options:(NSDictionary *)param {
    int64_t probeSize;
    NSArray* durations;
    BOOL fpsProbeSizeEnable;
    
    probeSize = [param[ProbeSizeKey] unsignedIntegerValue];
    fmtCtx->probesize = probeSize ?: 10 * 4096;
    
    durations = param[MaxAnalyzeDuraionArrayKey];
    if (durations && durations.count > self.decoderCtx.connectionRetry)
        fmtCtx->max_analyze_duration = [durations[self.decoderCtx.connectionRetry] unsignedIntegerValue];
    else {
        float multiplier = 0.5 + (double)pow(2.0, (double)self.decoderCtx.connectionRetry) * 0.25;
        fmtCtx->max_analyze_duration = multiplier * AV_TIME_BASE;
    }
    
    fpsProbeSizeEnable = [param[FpsProbeSizeEnableKey] boolValue];
    if (fpsProbeSizeEnable)
        fmtCtx->fps_probe_size = 3;
}

- (int)openFormatInput:(AVFormatContext **)ps path:(NSString *)path options:(NSDictionary *)param {
    const char* videoSourceURI = [path cStringUsingEncoding:NSUTF8StringEncoding];
    AVDictionary *options = NULL;
    NSString *rtmpTcurl = param[RtmpTcurlKey];
    if ([rtmpTcurl length] > 0) {
        const char *rtmp_tcurl = [rtmpTcurl cStringUsingEncoding:NSUTF8StringEncoding];
        av_dict_set(&options, "rtmp_tcurl", rtmp_tcurl, 0);
    }
    return avformat_open_input(ps, videoSourceURI, NULL, &options);
    
}

- (BOOL)detectInterrupted {
    if ([[NSDate date] timeIntervalSince1970] - self.decoderCtx.readLastestFrameTime > self.decoderCtx.subscribeTimeout) {
        return YES;
    }
    return self.decoderCtx.interrupted;
}

- (void)interrupt {
    VideoDecoderContext *record = self.decoderCtx;
    record.subscribeTimeout = -1;
    record.interrupted = YES;
    record.isSubcribe = NO;
}


- (int)frameWidth {
    return self.decoderCtx.videoCodecCtx ? self.decoderCtx.videoCodecCtx->width : 0;
}

- (int)frameHeight {
    return self.decoderCtx.videoCodecCtx ? self.decoderCtx.videoCodecCtx->height : 0;
}


- (int)sampleRate {
    return self.decoderCtx.audioCodecCtx ? self.decoderCtx.audioCodecCtx->sample_rate : 0;
}

- (int)channels {
    return self.decoderCtx.audioCodecCtx ? self.decoderCtx.audioCodecCtx->channels : 0;
}

- (BOOL)validVideo {
    return self.decoderCtx.videoStreamIndex != -1;
}

- (BOOL)validAudio {
    return self.decoderCtx.audioStreamIndex != -1;
}

- (double)duration {
    if (self.decoderCtx.formatCtx) {
        if (self.decoderCtx.formatCtx->duration == AV_NOPTS_VALUE)
            return -1;
        else
            return self.decoderCtx.formatCtx->duration / AV_TIME_BASE;
        
    }
    return -1;
}

- (BOOL)isSubscribed {
    return self.decoderCtx.isSubcribe;
}

- (BuriedPoint*)getBuriedPoint {
    return self.decoderCtx.buriedPoint;
}

- (void)triggerFirstScreen {
    if (self.decoderCtx.buriedPoint.failOpenCode == 1) {
        self.decoderCtx.buriedPoint.firstScreenTimeMills = ([[NSDate date] timeIntervalSince1970] * 1000 - self.decoderCtx.buriedPoint.beginOpen) / 1000.0f;
    }
}

- (void)addBufferStatusRecord:(NSString*)statusFlag
{
    if ([@"F" isEqualToString:statusFlag] && [[self.decoderCtx.buriedPoint.bufferStatusRecords lastObject] hasPrefix:@"F_"]) {
        return;
    }
    float timeInterval = ([[NSDate date] timeIntervalSince1970] * 1000 - self.decoderCtx.buriedPoint.beginOpen) / 1000.0f;
    [self.decoderCtx.buriedPoint.bufferStatusRecords addObject:[NSString stringWithFormat:@"%@_%.3f", statusFlag, timeInterval]];
}
@end
