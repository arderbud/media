//
//  MvpView.m
//  Media
//
//  Created by bytedance on 2020/11/3.
//  Copyright © 2020 arderbud. All rights reserved.
//

#import "MvpView.h"

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#define STRINGIZE(x)        #x
#define STRINGIZE2(x)       STRINGIZE(x)
#define SHADER_STRING(source) @ STRINGIZE2(source)

static NSString *const kIESGLesTextureRgbaVertString = SHADER_STRING
(
    attribute vec4 aPosition;
    attribute vec2 aSamplerCoord;
    varying vec2 vSamplerCoord;
    uniform mat4 uMVPMatrix;

    void main() {
        gl_Position   = uMVPMatrix * aPosition;
        vSamplerCoord = aSamplerCoord;
    }
 );


static NSString *const kIESGLesTextureRgbaFragString = SHADER_STRING
(
    precision mediump float;
    varying mediump vec2 vSamplerCoord;
    uniform sampler2D uSamplerTexture;

    void main() {
        vec4 textureColor = texture2D(uSamplerTexture, vSamplerCoord);
        gl_FragColor      = textureColor;
    }
 );

@implementation MvpView {
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
        if (![self configureOpenGLESContext])
            return nil;
        if (![self configureGLProgram])
            return nil;
        [self inputVertexData];
    }
    return self;
}

// https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/WorkingwithEAGLContexts/WorkingwithEAGLContexts.html#//apple_ref/doc/uid/TP40008793-CH103-SW8
- (BOOL)configureOpenGLESContext{
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
    
    // 如果没有实现drawRect方法，这里会有问题
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
    const GLchar *vertexSource = (GLchar *)kIESGLesTextureRgbaVertString.UTF8String;
    const GLchar *fragmentSource = (GLchar *)kIESGLesTextureRgbaFragString.UTF8String;
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
    
    GLint  posAttribIndex,samCoordAttribIndex;
    GLfloat vertices[] = {
        -0.5f,  -0.5f, 0.0f, 0.0f, 0.0f, // Top-left
        0.5f,  -0.5f, 0.0f, 1.0f, 0.0f, // Top-right
        -0.5f, 0.5f, 0.0f, 0.0f, 1.0f, // Bottom-right
        0.5f,  0.5f, 0.0f, 1.0f, 1.0f  // Bottom-left
    };
    GLuint elements[] = {
        0, 1, 2,
        1, 2, 3
    };
    /////////////////////////////////////// VAO BEGIN /////////////////////////
    glGenVertexArrays(1, &_VAO);
    glBindVertexArray(_VAO);
    
    // vbo start --------------------------------->
    glGenBuffers(1, &_VBO);
    glBindBuffer(GL_ARRAY_BUFFER, _VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW); // buffer: 80 bytes
    
    posAttribIndex = glGetAttribLocation(_shaderProgram, "aPosition");
    glEnableVertexAttribArray(posAttribIndex);
    glVertexAttribPointer(posAttribIndex, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), (void *)0);
    samCoordAttribIndex = glGetAttribLocation(_shaderProgram, "aSamplerCoord");
    glEnableVertexAttribArray(samCoordAttribIndex);
    glVertexAttribPointer(samCoordAttribIndex, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), (void *)(3 * sizeof(GLfloat)));
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    // vbo end ---------------------------------<
    
    glGenBuffers(1, &_EBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(elements), elements, GL_STATIC_DRAW); // buffer: 24 bytes
    
    glBindVertexArray(0);
    /////////////////////////////////////// VAO END /////////////////////////
}

- (void)drawImage:(UIImage *)image {
    
    
    glUseProgram(_shaderProgram);
    
    CGFloat scale = UIScreen.mainScreen.scale;
    glViewport(0, 0, CGRectGetWidth(self.bounds) * scale, CGRectGetHeight(self.bounds) * scale);
    glClearColor(0.2f, 0.2f, 0.2f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  
    const GLfloat mvpMatrix[] = {
            2, 0,    0, 0,
            0, 2,    0, 0,
            0, 0, -0.5, 0,
            0, 0,  0.5, 1,
    };
    glUniformMatrix4fv(glGetUniformLocation(_shaderProgram, "uMVPMatrix"), 1, GL_FALSE, mvpMatrix);
    
    GLuint textureId = [self setupTexture:image];
    glActiveTexture(GL_TEXTURE5); // 指定纹理单元GL_TEXTURE5
    glBindTexture(GL_TEXTURE_2D, textureId); // 绑定，即可从_textureID中取出图像数据。
    glUniform1i(glGetUniformLocation(_shaderProgram, "uSamplerTexture"), 5); // 与纹理单元的序号对应
    
//    [self renderVertices];
    
    
    glBindVertexArray(_VAO);
    
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

    glBindVertexArray(0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    
}

/*
- (void)renderVertices {
    GLuint posAttrIndex,samCoordAttribIndex;
    GLfloat texCoords[] = {
        0, 0,//左下
        1, 0,//右下
        0, 1,//左上
        1, 1,//右上
    };
    samCoordAttribIndex = glGetAttribLocation(_shaderProgram, "aSamplerCoord");
    glEnableVertexAttribArray(samCoordAttribIndex);
    glVertexAttribPointer(samCoordAttribIndex, 2, GL_FLOAT, GL_FALSE,0, texCoords);

    
    GLfloat vertices[] = {
        -0.5, -0.5, 0,   //左下
        0.5,  -0.5, 0,   //右下
        -0.5, 0.5,  0,   //左上
        0.5,  0.5,  0 }; //右上
    posAttrIndex = glGetAttribLocation(_shaderProgram, "aPosition");
    glEnableVertexAttribArray(posAttrIndex);
    glVertexAttribPointer(posAttrIndex, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    
    // 一旦纹理数据准备好，两个坐标系的顶点位置一一对应好。
    // 就直接绘制顶点即可, 具体的绘制方式就与纹理坐标和纹理数据没有关系了。
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}
 */

- (GLuint)setupTexture:(UIImage *)image {
    CGImageRef cgImageRef = [image CGImage];
    GLuint width = (GLuint)CGImageGetWidth(cgImageRef);
    GLuint height = (GLuint)CGImageGetHeight(cgImageRef);
    CGRect rect = CGRectMake(0, 0, width, height);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    void *imageData = malloc(width * height * 4);
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, rect);
    CGContextDrawImage(context, rect, cgImageRef);
    
    glEnable(GL_TEXTURE_2D);
    
    /**
     *  GL_TEXTURE_2D表示操作2D纹理
     *  创建纹理对象，
     *  绑定纹理对象，
     */
    
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    
    /**
     *  纹理过滤函数
     *  图象从纹理图象空间映射到帧缓冲图象空间(映射需要重新构造纹理图像,这样就会造成应用到多边形上的图像失真),
     *  这时就可用glTexParmeteri()函数来确定如何把纹理象素映射成像素.
     *  如何把图像从纹理图像空间映射到帧缓冲图像空间（即如何把纹理像素映射成像素）
     */
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); // S方向上的贴图模式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); // T方向上的贴图模式
    // 线性过滤：使用距离当前渲染像素中心最近的4个纹理像素加权平均值
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    /**
     *  将图像数据传递给到GL_TEXTURE_2D中, 因其于textureID纹理对象已经绑定，所以即传递给了textureID纹理对象中。
     *  glTexImage2d会将图像数据从CPU内存通过PCIE上传到GPU内存。
     *  不使用PBO时它是一个阻塞CPU的函数，数据量大会卡。
     */
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    // 结束后要做清理
    glBindTexture(GL_TEXTURE_2D, 0); //解绑
    CGContextRelease(context);
    free(imageData);
    
    return textureID;
}


- (void)clean {
    
    glDeleteProgram(_shaderProgram);
    glDeleteVertexArrays(1, &_VAO);
    glDeleteBuffers(1, &_VBO);
    glDeleteBuffers(1, &_EBO);
    
    glDeleteRenderbuffers(1, &_colorRenderBuffer);
    glDeleteFramebuffers(1, &_frameBuffer);
    
}

- (void)drawRect:(CGRect)rect {
    
}
@end
