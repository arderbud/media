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
    int error = 0;
    AVStream *audioStream = NULL;
    AVCodec *codec = NULL;
    AVCodecContext *audioCodecCtx = NULL;
    int64_t outChannelLayout = AV_CH_LAYOUT_STEREO;
    AVSampleFormat outSampleFmt = AV_SAMPLE_FMT_S16;
    int outSampleRate = 0;
    SwrContext *swrCtx = NULL;
    AVFrame *frame = NULL;
    AVPacket *packet = NULL;
    int outBufferSize = 0;
    uint8_t *buffer = NULL;
    int idx = 0;
    
    audioStream = fmtCtx->streams[index];
    codec = avcodec_find_decoder(audioStream->codecpar->codec_id);
    if (codec == NULL) {
        printf("cannot find decoder");
        error = -1;
        goto exitPoint;
    }
    audioCodecCtx = avcodec_alloc_context3(codec);
    avcodec_parameters_to_context(audioCodecCtx, audioStream->codecpar);
    error = avcodec_open2(audioCodecCtx, codec, NULL);
    if (error < 0) {
        printf("open video codec fail");
        goto exitPoint;
    }
    
//    outSampleRate = audioCodecCtx->sample_rate;
    outSampleRate = 44100;
    swrCtx = swr_alloc_set_opts(NULL,
                                outChannelLayout, outSampleFmt, outSampleRate,
                                audioCodecCtx->channel_layout, audioCodecCtx->sample_fmt, audioCodecCtx->sample_rate,
                                0, NULL);
    swr_init(swrCtx);
    
    packet = av_packet_alloc();
    frame = av_frame_alloc();
    outBufferSize = av_samples_get_buffer_size(NULL,
                                               av_get_channel_layout_nb_channels(outChannelLayout),
                                               audioCodecCtx->frame_size,outSampleFmt,1);
    buffer = (uint8_t *)av_malloc(outBufferSize);
    while (av_read_frame(fmtCtx, packet) == 0) {
        if (packet->stream_index != index ) continue;
        if (0 != avcodec_send_packet(audioCodecCtx, packet)) {
            printf("send packet error");
            error = -3;
            goto exitPoint;
        }
        while (0 == avcodec_receive_frame(audioCodecCtx, frame)) {
            swr_convert(swrCtx,
                        &buffer, frame->nb_samples,
                        (const uint8_t **)frame->data, frame->nb_samples);
            printf("index:%5d\t  pts:%lld frame size:%d\n",idx,frame->pts,frame->pkt_size);
            fwrite(buffer, 1, outBufferSize, pcmFilePtr);
            idx++;
        }
        av_packet_unref(packet);
    }
    
exitPoint:
    if (audioCodecCtx)
        avcodec_free_context(&audioCodecCtx);
    if (swrCtx)
        swr_free(&swrCtx);
    if (packet)
        av_packet_free(&packet);
    if (frame)
        av_frame_free(&frame);
    if (buffer)
        av_free(buffer);

    return error;
    
}
