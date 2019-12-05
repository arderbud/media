//
//  ADImageOutput.h
//  Media
//
//  Created by arderbud on 2019/11/5.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import "ADImageInput.h"

NS_ASSUME_NONNULL_BEGIN

@interface ADImageOutput : NSObject
{
    NSMutableArray<id<ADImageInput>> *_targets;
    GLuint _outputTexture;
}

- (void)setInputTextureForTarget:(id<ADImageInput>)target;

- (void)addTarget:(id<ADImageInput>)target;

- (GLuint)outputTexture;

- (NSArray<id<ADImageInput>> *)targets;

- (void)removeTarget:(id<ADImageInput>)target;

- (void)removeAllTargets;


@end

NS_ASSUME_NONNULL_END
