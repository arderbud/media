//
//  MediaDecomposer.cpp
//  Media
//
//  Created by arderbud on 2019/9/4.
//  Copyright © 2019 arderbud. All rights reserved.
//

#include "MediaDecomposer.hpp"

extern "C" {
    #include "libavformat/avformat.h"
    #include "libswscale/swscale.h"
    #include "libswresample/swresample.h"
    #include "libavutil/pixdesc.h"
}


int execAudioDecode(AVFormatContext * fmtCtx,int index,FILE *pcmFilePtr);

MediaDecomposer::MediaDecomposer( ){
}

MediaDecomposer::~MediaDecomposer() {
    
}
int MediaDecomposer::init() {
//    avformat_network_init(); 
//    av_register_all();
    return 0;
}

int interruptCallback(void* opaque) {
    return 0;
}

int MediaDecomposer::decompose(const char *mediaFilePath, const char *pcmFilePath, const char *yuvFilePath) {
    int ret = 0;
    FILE *pcmFilePtr = fopen(pcmFilePath, "wb+");
    if (NULL == pcmFilePtr) {
        printf("FILE open error");
        return -1;
    }
    // open media file
    AVFormatContext *formatCtx = avformat_alloc_context();
    formatCtx->interrupt_callback = {
        .callback = interruptCallback,
        .opaque   = (void*)this
    };
    
    ret = avformat_open_input(&formatCtx, mediaFilePath, NULL, NULL);
    if (ret != 0 ) {
        printf("can't open an input file stream:%s\n", mediaFilePath);
        return -1;
    };
    ret = avformat_find_stream_info(formatCtx, NULL);
    if (ret != 0) {
        printf("can't find stream information\n");
        return -1;
    }
    // find stream
    int audioStreamIndex = -1,videoStreamIndex = -1;
    for (int i = 0; i < formatCtx->nb_streams; ++i) {
        AVStream *stream = formatCtx->streams[i];
        if (AVMEDIA_TYPE_VIDEO == stream->codecpar->codec_type) {
            printf("video stream index:[%d]\n",i);
            videoStreamIndex = i;
        } else if (AVMEDIA_TYPE_AUDIO == stream->codecpar->codec_type){
            printf("audio stream index:[%d]\n",i);
            audioStreamIndex = i;
            ret = execAudioDecode(formatCtx, i, pcmFilePtr);
        }
    }
    
    avformat_close_input(&formatCtx);
    avformat_free_context(formatCtx);
    
    return ret;
}


int execAudioDecode(AVFormatContext * fmtCtx,int index,FILE *pcmFilePtr) {
    AVStream *audioStream = NULL;
    AVCodec *codec = NULL;
    AVCodecContext *audioCodecCtx = NULL;
    
    int64_t outChannelLayout = AV_CH_LAYOUT_STEREO;
    AVSampleFormat outSampleFmt = AV_SAMPLE_FMT_S16;
    int outSampleRate = 44100;
    int outNumberChannels = 0;
    int outLinesize;
    int outBufferSize = 0;
    int outNumberSamples, maxOutNumberSamples;
    uint8_t **outBuffer = NULL;
    
    SwrContext *swrCtx = NULL;
    AVFrame *frame = NULL;
    AVPacket *packet = NULL;
    int ret = 0;
    int idx = 0;
    
    audioStream = fmtCtx->streams[index];
    codec = avcodec_find_decoder(audioStream->codecpar->codec_id);
    if (codec == NULL) {
        fprintf(stderr,"cannot find decoder");
        ret = -1;
        goto end;
    }
    audioCodecCtx = avcodec_alloc_context3(codec);
    avcodec_parameters_to_context(audioCodecCtx, audioStream->codecpar);
    ret = avcodec_open2(audioCodecCtx, codec, NULL);
    if (ret < 0) {
        fprintf(stderr,"open video codec fail");
        goto end;
    }
    
    swrCtx = swr_alloc_set_opts(NULL,
                                outChannelLayout, outSampleFmt, outSampleRate,
                                audioCodecCtx->channel_layout, audioCodecCtx->sample_fmt, audioCodecCtx->sample_rate,
                                0, NULL);
    swr_init(swrCtx);
    
    maxOutNumberSamples = outNumberSamples = (int)av_rescale_rnd(audioCodecCtx->frame_size, outSampleRate, audioCodecCtx->sample_rate, AV_ROUND_UP);
    fprintf(stdout,"max out nb samples %d  ",maxOutNumberSamples);
    
    outNumberChannels = av_get_channel_layout_nb_channels(outChannelLayout);
    ret = av_samples_alloc_array_and_samples(&outBuffer, &outLinesize, outNumberChannels, outNumberSamples, outSampleFmt, 0);
    if (ret < 0) {
        printf("alloc out buffer fail");
        goto end;
    }
    packet = av_packet_alloc();
    frame = av_frame_alloc();
    while (av_read_frame(fmtCtx, packet) == 0) {
        if (packet->stream_index != index ) continue;
        if (0 != avcodec_send_packet(audioCodecCtx, packet)) {
            printf("send packet error");
            ret = -3;
            goto end;
        }
        while (0 == avcodec_receive_frame(audioCodecCtx, frame)) {
            outNumberSamples = (int)av_rescale_rnd(swr_get_delay(swrCtx, frame->sample_rate) + frame->nb_samples, outSampleRate, frame->sample_rate, AV_ROUND_UP);
            fprintf(stdout, "out nb samples:%d   ",outNumberSamples);
            if (outNumberSamples > maxOutNumberSamples) {
                av_freep(&outBuffer[0]);
                ret = av_samples_alloc(outBuffer, &outLinesize, outNumberChannels, outNumberSamples, outSampleFmt, 1);
                maxOutNumberSamples = outNumberSamples;
            }
            ret = swr_convert(swrCtx,
                        outBuffer, outNumberSamples,
                        (const uint8_t **)frame->data, frame->nb_samples);
            if (ret < 0) {
                fprintf(stderr, "Error while converting\n");
                goto end;
            }
            outBufferSize = av_samples_get_buffer_size(&outLinesize, outNumberChannels, ret, outSampleFmt, 1);
            fprintf(stdout,"index:%5d\t  pts:%lld frame size:%d\n",idx,frame->pts,frame->pkt_size);
            fwrite(outBuffer[0], 1, outBufferSize, pcmFilePtr);
            idx++;
        }
        av_packet_unref(packet);
    }
    
end:
    if (audioCodecCtx)
        avcodec_free_context(&audioCodecCtx);
    if (swrCtx)
        swr_free(&swrCtx);
    if (packet)
        av_packet_free(&packet);
    if (frame)
        av_frame_free(&frame);
    if (outBuffer)
        av_freep(&outBuffer[0]);
    av_freep(&outBuffer);
    
    return ret;
    
}
