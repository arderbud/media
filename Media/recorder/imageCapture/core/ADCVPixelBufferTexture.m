//
//  ADCVPixelBufferTexture.m
//  Media
//
//  Created by arderbud on 2019/11/4.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "ADCVPixelBufferTexture.h"
#import <CoreVideo/CoreVideo.h>

@implementation ADCVPixelBufferTexture {
    GLuint _frameBuffer;
    GLuint _texture;
    
    CVPixelBufferRef _pixelBuffer;
    CVOpenGLESTextureRef _image;
    
}

- (instancetype)initWithWidth:(int)width height:(int)height EAGLContext:(EAGLContext *)context {
    ADTextureOptions defaultTextureOptions = {0};
    defaultTextureOptions.minFilter = GL_LINEAR;
    defaultTextureOptions.magFilter = GL_LINEAR;
    defaultTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.internalFormat = GL_RGBA;
    defaultTextureOptions.format = GL_RGBA;
    defaultTextureOptions.type = GL_UNSIGNED_BYTE;
    
    return [self initWithWidth:width height:height EAGLContext:context options:&defaultTextureOptions];
}

- (instancetype)initWithWidth:(int)width height:(int)height EAGLContext:(EAGLContext *)context options:(ADTextureOptions *)options {
    self = [super init];
    if (self) {
        _width = width;
        _height = height;
        [self genFrameBufferWithEAGLContext:context options:options];
    }
    return self;
}

- (void)genFrameBufferWithEAGLContext:(EAGLContext *)context options:(ADTextureOptions *)options {
    CVOpenGLESTextureCacheRef textureCache;

    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    
    CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, context, NULL, &textureCache);
    CVPixelBufferCreate(kCFAllocatorDefault, _width, _height, kCVPixelFormatType_32BGRA, NULL, &_pixelBuffer);
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, _pixelBuffer, NULL, GL_TEXTURE_2D, options->internalFormat, _width, _height, options->format, options->type, 0, &_image);
    
    _texture = CVOpenGLESTextureGetName(_image);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, options->wrapS);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, options->wrapT);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _texture, 0);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
    glViewport(0, 0, _width, _height);
}

- (void)activeFrameBuffer {
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
}

- (GLubyte *)pixelbBuffer {
    CVPixelBufferLockBaseAddress(_pixelBuffer, 0);
    GLubyte *buffer = CVPixelBufferGetBaseAddress(_pixelBuffer);
    CVPixelBufferUnlockBaseAddress(_pixelBuffer, 0);
    return buffer;
}


- (void)destroyFrameBuffer {
    glDeleteFramebuffers(1, &_frameBuffer);
    CFRelease(_pixelBuffer);
    CFRelease(_image);
    
}
@end
