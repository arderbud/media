//
//  YUVFrameRender.m
//  Media
//
//  Created by arderbud on 2019/10/17.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "YUVFrameRender.h"

static NSString *const yuvVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 uniform mat4 modelViewProjectMatrix;
 varying vec2 v_texcoord;
 
 void main() {
     gl_Position = modelViewProjectMatrix * position;
     v_texcoord = texcoord.xy;
 }
);

static NSString *const yuvFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D texY;
 uniform sampler2D texU;
 uniform sampler2D texV;
 void main() {
     highp float y = texture2D(texY, v_texcoord).r;
     highp float u = texture2D(texU, v_texcoord).r - 0.5;
     highp float v = texture2D(texV, v_texcoord).r - 0.5;
     
     highp float r = y +             1.402 * v;
     highp float g = y - 0.344 * u - 0.714 * v;
     highp float b = y + 1.772 * u;
     
     gl_FragColor = vec4(r,g,b,1.0);
 }
 );


@implementation YUVFrameRender {
    GLuint _inputTextures[3];
}

- (instancetype)init {
    self = [super initWithVertexShaderSrc:yuvVertexShaderString fragmentShaderSrc:yuvFragmentShaderString];
    
    return self;
}

// prepare data
- (void)inputVideoFrame:(VideoFrame *)frame width:(float)width height:(float)height {

    glViewport(0, 0, width, height);
    
    GLuint posAttrIndex,texcoordAttrIndex;
    static const GLfloat imageVertices[] = {
        -1.0f, -1.0f, 0.0f, 1.0f,
        1.0f,  -1.0f, 1.0f, 1.0f,
        -1.0f,  1.0f, 0.0f, 0.0f,
        1.0f,   1.0f, 1.0f, 0.0f
    };
    
    const UInt8 *pixels[3] = { frame.luma.bytes, frame.chromaB.bytes, frame.chromaR.bytes };
    const NSUInteger widths[3]  = { width,  width / 2,  width / 2 };
    const NSUInteger heights[3] = { height, height / 2, height / 2 };
    
    glGenVertexArrays(1, &_VAO);
    glBindVertexArray(_VAO);
    
    glGenBuffers(1, &_VBO);
    glBindBuffer(GL_ARRAY_BUFFER, _VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(imageVertices), imageVertices, GL_STATIC_DRAW);
    
    posAttrIndex = glGetAttribLocation(_shaderProgram, "position");
    glEnableVertexAttribArray(posAttrIndex);
    glVertexAttribPointer(posAttrIndex, 2, GL_FLOAT, 0, 4 * sizeof(GLfloat), (void *)0);
    texcoordAttrIndex = glGetAttribLocation(_shaderProgram, "texcoord");
    glEnableVertexAttribArray(texcoordAttrIndex);
    glVertexAttribPointer(texcoordAttrIndex, 2, GL_FLOAT, 0, 4 * sizeof(GLfloat), (void *)(2 * sizeof(GLfloat)));
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    
    glGenTextures(3, _inputTextures);
    for (int i = 0; i < 3; ++i) {
        glBindTexture(GL_TEXTURE_2D, _inputTextures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, (int)widths[i], (int)heights[i],
                     0, GL_LUMINANCE, GL_UNSIGNED_BYTE, pixels[i]);
        glBindTexture(GL_TEXTURE_2D, 0);
    }

}

// 
- (void)draw {
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glUseProgram(_shaderProgram);
    
    GLfloat modelviewProj[16];
    mat4f_loadOrtho(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f, modelviewProj);
    glUniformMatrix4fv(glGetUniformLocation(_shaderProgram, "modelViewProjectMatrix"), 1, GL_FALSE, modelviewProj);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _inputTextures[0]);
    glUniform1i(glGetUniformLocation(_shaderProgram, "texY"), 0);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _inputTextures[1]);
    glUniform1i(glGetUniformLocation(_shaderProgram, "texU"), 1);
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, _inputTextures[2]);
    glUniform1i(glGetUniformLocation(_shaderProgram, "texV"), 2);
    
    glBindVertexArray(_VAO);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindVertexArray(0);

}



@end
