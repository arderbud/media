//
//  MediaDecomposer.hpp
//  Media
//
//  Created by arderbud on 2019/9/4.
//  Copyright © 2019 arderbud. All rights reserved.
//

#ifndef MediaDecomposer_hpp
#define MediaDecomposer_hpp

#include <stdio.h>


// decompose media to `pcm` and `yuv` file.
class MediaDecomposer {
public:
    MediaDecomposer();
    ~MediaDecomposer();
    int init();
    int decompose(const char *mediaFilePath,const char *pcmFilePath,const char *yuvFilePath);
    
    
};
#endif /* MediaDecomposer_hpp */
