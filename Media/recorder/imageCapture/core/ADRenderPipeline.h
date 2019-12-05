//
//  ADRenderPipeline.h
//  Media
//
//  Created by arderbud on 2019/11/5.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

NS_ASSUME_NONNULL_BEGIN

@interface ADRenderPipeline : NSObject
{
    GLuint _shaderProgram;
    GLuint _VAO,_VBO;
}

- (instancetype)initWithVertexShaderSrc:(NSString *)vetextSrc fragmentShaderSrc:(NSString *)fragmentSrc;

- (void)draw;

- (void)clean;


@end

#define STRINGIZE(x)        #x
#define STRINGIZE2(x)       STRINGIZE(x)
#define SHADER_STRING(source) @ STRINGIZE2(source)

NS_ASSUME_NONNULL_END
