//
//  RGBAFrameRender.m
//  Media
//
//  Created by arderbud on 2019/10/18.
//  Copyright © 2019 arderbud. All rights reserved.
//

// OpenGL Render 3 steps:
//  1. create program
//  2. input vertext data
//  3. draw

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import "RGBAFrameRender.h"

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 varying vec2 v_texcoord;
 
 void main()
 {
     gl_Position = position; // [pipeline] 2.vertext shader output
     v_texcoord = texcoord.xy;
 }
 );

// [pipeline] 3. primitive assembly
// [pipeline] 4. rasterization

NSString *const rgbFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D inTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inTexture, v_texcoord); // 5 . fragment shader output
 }
 );


@implementation RGBAFrameRender {
    GLuint _shaderProgram;
    GLuint _VAO,_VBO;
    GLuint _inputTexture;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self configureGLProgram];
    }
    return self;
}
- (BOOL)configureGLProgram {
    const GLchar *vertexSource = (GLchar *)vertexShaderString.UTF8String;
    const GLchar *fragmentSource = (GLchar *)rgbFragmentShaderString.UTF8String;
    GLuint vertexShader,fragmentShader = 0;
    GLint  status;
    char   infoLog[512];
    BOOL   success = YES;
    
    vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexSource, NULL);
    glCompileShader(vertexShader);
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &status);
    if (GL_FALSE == status) {
        glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
        NSLog(@"ERROR::SHADER::VERTEX::COMPILATION_FAILED-->%s",infoLog);
        success = NO;
        goto exit;
    }
    
    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentSource, NULL);
    glCompileShader(fragmentShader);
    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &status);
    if (GL_FALSE == status) {
        glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
        NSLog(@"ERROR::SHADER::FRAGMENT::COMPILATION_FAILED-->%s",infoLog);
        success = NO;
        goto exit;
    }
    
    _shaderProgram = glCreateProgram();
    glAttachShader(_shaderProgram, vertexShader);
    glAttachShader(_shaderProgram, fragmentShader);
    glLinkProgram(_shaderProgram);
    glGetProgramiv(_shaderProgram, GL_LINK_STATUS, &status);
    if (GL_FALSE == status) {
        glGetProgramInfoLog(_shaderProgram, 512, NULL, infoLog);
        NSLog(@"ERROR::SHADER::PROGRAM::LINKING_FAILED-->%s",infoLog);
        success = NO;
    }
    
exit:
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    return success;
}
- (void)inputRGBAFrame:(uint8_t *)frame width:(int)width height:(int)height {
    GLint posAttrIndex,texcoordAttrIndex,inTextureLocation;
    
    const GLfloat imageVertices[] = {
        -1.0f, -1.0f, 0.0f, 1.0f,
        1.0f , -1.0f, 1.0f, 1.0f,
        -1.0f,  1.0f, 0.0f, 0.0f,
        1.0f ,  1.0f, 1.0f, 0.0f
    };
    
    glGenVertexArrays(1, &_VAO);
    glBindVertexArray(_VAO);
    
    glGenBuffers(1, &_VBO);
    glBindBuffer(GL_ARRAY_BUFFER, _VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(imageVertices), imageVertices, GL_STATIC_DRAW); // [pipeline] 1. vertex specification
    posAttrIndex = glGetAttribLocation(_shaderProgram, "position");
    glEnableVertexAttribArray(posAttrIndex);
    glVertexAttribPointer(posAttrIndex, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (void*)0);
    texcoordAttrIndex = glGetAttribLocation(_shaderProgram, "texcoord");
    glEnableVertexAttribArray(texcoordAttrIndex);
    glVertexAttribPointer(texcoordAttrIndex, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (void *)(2 * sizeof(GLfloat)));
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    glBindVertexArray(0);
    
    glGenTextures(1, &_inputTexture);
    glBindTexture(GL_TEXTURE_2D, _inputTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, frame);
    //    glGenerateMipmap(GL_TEXTURE_2D);
    inTextureLocation = glGetUniformLocation(_shaderProgram, "inTexture");
    glUniform1i(inTextureLocation, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    
}

- (void)draw {
    glClearColor(0.0f, 0.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glUseProgram(_shaderProgram);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _inputTexture);
    
    glBindVertexArray(_VAO);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
}

- (void)clean {
    if (_shaderProgram) {
        glDeleteProgram(_shaderProgram);
        _shaderProgram = 0;
    }
    if (_inputTexture) {
        glDeleteTextures(1, &_inputTexture);
    }
}

@end

