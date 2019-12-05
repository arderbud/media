//
//  ADRenderPipeline.m
//  Media
//
//  Created by arderbud on 2019/11/5.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "ADRenderPipeline.h"

static BOOL validateProgram(GLuint program) {
    GLint status;
    glValidateProgram(program);
#ifdef DEBUG
    GLint logLength;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        NSLog(@"Shader compile log:%s",log);
        free(log);
    }
#endif
    
    glGetProgramiv(program, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE)
        return NO;
    return YES;
}

static GLuint compileShader(GLenum type,NSString *shaderString) {
    GLint status;
    GLuint shader;
    const GLchar *src = (GLchar *)shaderString.UTF8String;
    
    shader = glCreateShader(type);
    glShaderSource(shader, 1, &src, NULL);
    glCompileShader(shader);
    
#ifdef DEBUG
    GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        glDeleteShader(shader);
        NSLog(@"Failed to compile shader:\n");
        return -1;
    }
    return shader;
    
}

static GLuint createProgram(NSString *vertexShaderSrc, NSString * fragmentShaderSrc) {
    BOOL result = NO;
    GLint status;
    GLuint program = 0;
    GLuint vertextShader = 0,fragmentShader = 0;
    
    vertextShader = compileShader(GL_VERTEX_SHADER, vertexShaderSrc);
    if (!vertextShader)
        goto exit;
    fragmentShader = compileShader(GL_FRAGMENT_SHADER, fragmentShaderSrc);
    if (!fragmentShader)
        goto exit;
    
    program = glCreateProgram();
    glAttachShader(program, vertextShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (GL_FALSE == status)
        goto exit;
    result = validateProgram(program);
    
exit:
    glDeleteShader(vertextShader);
    glDeleteShader(fragmentShader);
    if (!result) {
        glDeleteProgram(program);
        return -1;
    }
    return program;
}

@implementation ADRenderPipeline

- (instancetype)initWithVertexShaderSrc:(NSString *)vetextSrc fragmentShaderSrc:(NSString *)fragmentSrc {
    self = [super init];
    if (self) {
        _shaderProgram = createProgram(vetextSrc, fragmentSrc);
        if (_shaderProgram < 0)
            return nil;
    }
    return self;
}

- (void)clean {
    if (_shaderProgram) {
        glDeleteProgram(_shaderProgram);
        _shaderProgram = 0;
    }
}



- (void)draw {
    NSLog(@"Should implemetation by subclass");
}


@end
