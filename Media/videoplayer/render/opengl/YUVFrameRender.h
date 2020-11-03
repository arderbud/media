//
//  YUVFrameRender.h
//  Media
//
//  Created by arderbud on 2019/10/17.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "RenderPipeline.h"
#import "MediaDecoder.h"

NS_ASSUME_NONNULL_BEGIN

@interface YUVFrameRender : RenderPipeline

- (void)inputVideoFrame:(VideoFrame *)frame width:(float)width height:(float)height;

@end

NS_ASSUME_NONNULL_END
