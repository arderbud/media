//
//  GLView.m
//  Media
//
//  Created by arderbud on 2019/9/18.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "RectangleView.h"

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>


#define STRINGIZE(x)        #x
#define STRINGIZE2(x)       STRINGIZE(x)
#define SHADER_STRING(source) @ STRINGIZE2(source)

NSString *const vertexShaderSource = SHADER_STRING
(
 attribute vec2 position;
 attribute vec3 color;
 varying  highp vec3 Color;
 void main() {
     Color = color;
     gl_Position = vec4(position,0.0,1.0);
  }
 );


NSString *const fragmentShaderSource = SHADER_STRING
(
 varying highp vec3 Color;
 void main() {
     gl_FragColor = vec4(Color, 1.0);
 }
);

@implementation RectangleView {
    EAGLContext *_context;
    GLuint _VAO,_VBO,_EBO;
    GLuint _colorRenderBuffer,_frameBuffer;
    GLuint _shaderProgram;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        if (![self configureOpenGLESContext:frame.size])
            return nil;
        if (![self configureGLProgram])
            return nil;
        [self inputVertexData];
    }
    return self;
}

// https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/WorkingwithEAGLContexts/WorkingwithEAGLContexts.html#//apple_ref/doc/uid/TP40008793-CH103-SW8
- (BOOL)configureOpenGLESContext:(CGSize)size {
    CAEAGLLayer *eaglLayer;
    GLint  renderWidth;
    GLint  renderHeight;
    GLenum status;
    GLenum error;
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:_context];
    
    eaglLayer = (CAEAGLLayer *)[self layer];
    [eaglLayer setOpaque:YES];
    [eaglLayer setDrawableProperties:[NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithBool:NO],kEAGLDrawablePropertyRetainedBacking,
                                      kEAGLColorFormatRGB565,kEAGLDrawablePropertyColorFormat, nil]];
    
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:eaglLayer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderBuffer);
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &renderWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &renderHeight);
//    glViewport(0, 0, size.width, size.height);
    
    status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE)
        return NO;
    
    error = glGetError();
    if (GL_NO_ERROR != error)
        return NO;
    
    return YES;
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (BOOL)configureGLProgram {
    const GLchar *vertexSource = (GLchar *)vertexShaderSource.UTF8String;
    const GLchar *fragmentSource = (GLchar *)fragmentShaderSource.UTF8String;
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
        goto exitPoint;
    }
    
    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentSource, NULL);
    glCompileShader(fragmentShader);
    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &status);
    if (GL_FALSE == status) {
        glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
        NSLog(@"ERROR::SHADER::FRAGMENT::COMPILATION_FAILED-->%s",infoLog);
        success = NO;
        goto exitPoint;
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
    
exitPoint:
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    return success;
}

- (void)inputVertexData {
    
    GLint  posAttribIndex,colAttribIndex;
    GLfloat vertices[] = {
        -0.5f,  0.5f, 1.0f, 0.0f, 0.0f, // Top-left
        0.5f,  0.5f, 0.0f, 1.0f, 0.0f, // Top-right
        0.5f, -0.5f, 0.0f, 0.0f, 1.0f, // Bottom-right
        -0.5f, -0.5f, 1.0f, 1.0f, 1.0f  // Bottom-left
    };
    GLuint elements[] = {
        0, 1, 2,
        2, 3, 0
    };
    /////////////////////////////////////// VAO BEGIN /////////////////////////
    glGenVertexArrays(1, &_VAO);
    glBindVertexArray(_VAO);
    
    // vbo start --------------------------------->
    glGenBuffers(1, &_VBO);
    glBindBuffer(GL_ARRAY_BUFFER, _VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW); // buffer: 80 bytes
    
    posAttribIndex = glGetAttribLocation(_shaderProgram, "position");
    glEnableVertexAttribArray(posAttribIndex);
    glVertexAttribPointer(posAttribIndex, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), (void *)0);
    colAttribIndex = glGetAttribLocation(_shaderProgram, "color");
    glEnableVertexAttribArray(colAttribIndex);
    glVertexAttribPointer(colAttribIndex, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), (void *)(2 * sizeof(GLfloat)));
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    // vbo end ---------------------------------<
    
    glGenBuffers(1, &_EBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(elements), elements, GL_STATIC_DRAW); // buffer: 24 bytes
    
    glBindVertexArray(0);
    /////////////////////////////////////// VAO END /////////////////////////
}

- (void)draw {
    glClearColor(0.2f, 0.2f, 0.2f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glUseProgram(_shaderProgram);
    glBindVertexArray(_VAO);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    
    glBindVertexArray(0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    
}

- (void)clean {
    
    glDeleteProgram(_shaderProgram);
    glDeleteVertexArrays(1, &_VAO);
    glDeleteBuffers(1, &_VBO);
    glDeleteBuffers(1, &_EBO);
    
    glDeleteRenderbuffers(1, &_colorRenderBuffer);
    glDeleteFramebuffers(1, &_frameBuffer);
    
}
@end
