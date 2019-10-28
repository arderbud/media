//
//  RenderPipeline.h
//  Media
//
//  Created by arderbud on 2019/10/17.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

NS_ASSUME_NONNULL_BEGIN

@interface RenderPipeline : NSObject
{
    GLuint _shaderProgram;
    GLuint _VAO,_VBO;
}

- (instancetype)initWithVertexShaderSrc:(NSString *)vetextSrc fragmentShaderSrc:(NSString *)fragmentSrc;

- (void)draw;

- (void)clean;

@end

FOUNDATION_EXTERN BOOL validateProgram(GLuint program);
FOUNDATION_EXTERN GLuint compileShader(GLenum type,NSString *shaderString);
FOUNDATION_EXTERN void mat4f_loadOrtho(float left, float right, float bottom, float top, float near, float far, float* mout);
FOUNDATION_EXTERN GLuint createProgram(NSString *vertexShaderSrc, NSString * fragmentShaderSrc);

#define STRINGIZE(x)        #x
#define STRINGIZE2(x)       STRINGIZE(x)
#define SHADER_STRING(source) @ STRINGIZE2(source)

NS_ASSUME_NONNULL_END
