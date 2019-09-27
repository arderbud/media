//
//  Mp3Endec.hpp
//  Media
//
//  Created by arderbud on 2019/9/3.
//  Copyright © 2019 arderbud. All rights reserved.
//

#ifndef Mp3Endec_hpp
#define Mp3Endec_hpp

#include <stdio.h>
#include "lame.h"

class Mp3Endec {
    FILE *pcmFilePtr;
    FILE *mp3FilePtr;
    lame_t lamePtr;
    
public:
    Mp3Endec();
    ~Mp3Endec();
    int init(const char* pcmFilePath,const char* mp3FilePath,int sampleRate,int channels,int bRate);
    void encode();
    void destroy();
};

#endif /* Mp3Endec_hpp */
