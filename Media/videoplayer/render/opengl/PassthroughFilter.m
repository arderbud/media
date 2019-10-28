//
//  PassthroughFilter.m
//  Media
//
//  Created by arderbud on 2019/10/19.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "PassthroughFilter.h"

static NSString *const kPassthroughVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = texcoord;
 }
 );

static NSString *const kPassthroughFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
 );

@implementation PassthroughFilter {
    GLuint _texture;
}

- (instancetype)init {
    self = [super initWithVertexShaderSrc:kPassthroughVertexShaderString fragmentShaderSrc:kPassthroughFragmentShaderString];
    return self;
}

- (void)inputTexture:(GLuint)texture width:(int)width height:(int)height {
   
    
    int posAttribIndex,texcoordAttribIndex;
    
    static const GLfloat imageVertices[] = {
        -1.0f, -1.0f, 0.0f, 0.0f,
         1.0f, -1.0f, 1.0f, 0.0f,
        -1.0f,  1.0f, 0.0f, 1.0f,
         1.0f,  1.0f, 1.0f, 1.0f
    };
    
    glViewport(0, 0, width, height);
    
    glGenVertexArrays(1, &_VAO);
    glBindVertexArray(_VAO);
    
    glGenBuffers(1, &_VBO);
    glBindBuffer(GL_ARRAY_BUFFER, _VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(imageVertices), imageVertices, GL_STATIC_DRAW);
    posAttribIndex = glGetAttribLocation(_shaderProgram, "position");
    glEnableVertexAttribArray(posAttribIndex);
    glVertexAttribPointer(posAttribIndex, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (const GLvoid *)0);
    texcoordAttribIndex = glGetAttribLocation(_shaderProgram, "texcoord");
    glEnableVertexAttribArray(texcoordAttribIndex);
    glVertexAttribPointer(texcoordAttribIndex, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (const GLvoid *)(2 * sizeof(GLfloat)));
   
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    _texture = texture;
}

- (void)draw {
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glUseProgram(_shaderProgram);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glUniform1i(glGetUniformLocation(_shaderProgram, "inputImageTexture"), 0);
    
    glBindVertexArray(_VAO);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindVertexArray(0);
}

@end
