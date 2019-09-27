//
//  Mp3Endec.cpp
//  Media
//
//  Created by arderbud on 2019/9/3.
//  Copyright © 2019 arderbud. All rights reserved.
//

#include "Mp3Endec.hpp"

void Mp3Endec::encode() {
    int bufferSize = 1024 * 256;
    short *buffer = new short[bufferSize / 2];
    short *leftBuffer = new short[bufferSize / 4];
    short *rightBuffer = new short[bufferSize / 4];
    unsigned char* mp3Buffer = new unsigned char[bufferSize];
    size_t readBufferSize = 0;
    while ((readBufferSize = fread(buffer, 2, bufferSize/2, pcmFilePtr)) > 0) {
        for (int i = 0; i < readBufferSize; i++) {
            if (i % 2 == 0)
                leftBuffer[i/2] = buffer[i];
            else
                rightBuffer[i/2] = buffer[i];
        }
        size_t writeSize = lame_encode_buffer(lamePtr, leftBuffer, rightBuffer, readBufferSize/2, mp3Buffer, bufferSize);
        fwrite(mp3Buffer, 1, writeSize, mp3FilePtr);
    }
    delete [] buffer;
    delete [] leftBuffer;
    delete [] rightBuffer;
    delete [] mp3Buffer;
}

int Mp3Endec::init(const char *pcmFilePath, const char *mp3FilePath, int sampleRate, int channels, int bRate) {
    int ret = -1;
    pcmFilePtr = fopen(pcmFilePath, "rb");
    if (nullptr == pcmFilePtr) return ret;
    mp3FilePtr = fopen(mp3FilePath, "wb");
    if (nullptr == mp3FilePtr) return ret;
    
    lamePtr = lame_init();
    lame_set_in_samplerate(lamePtr, sampleRate);
    lame_set_out_samplerate(lamePtr, sampleRate);
    lame_set_num_channels(lamePtr, channels);
    lame_set_brate(lamePtr, bRate);
    lame_init_params(lamePtr);
    ret  = 0;
    
    return ret;
}

void Mp3Endec::destroy() {
    if (pcmFilePtr) {
        fclose(pcmFilePtr);
    }
    if (mp3FilePtr) {
        fclose(mp3FilePtr);
        lame_close(lamePtr);
    }
}

Mp3Endec::Mp3Endec() {
    
}

Mp3Endec::~Mp3Endec() {
    
}
