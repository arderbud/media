//
//  ContrastEnhancerFilter.h
//  Media
//
//  Created by arderbud on 2019/10/19.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "RenderPipeline.h"

NS_ASSUME_NONNULL_BEGIN

@interface ContrastEnhancerFilter : RenderPipeline

- (void)inputTexture:(GLuint)texture width:(int)width height:(int)height;

@end

NS_ASSUME_NONNULL_END
