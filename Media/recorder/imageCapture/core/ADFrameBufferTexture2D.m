//
//  ADFrameBufferTexture2D.m
//  Media
//
//  Created by arderbud on 2019/11/5.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "ADFrameBufferTexture2D.h"

@implementation ADFrameBufferTexture2D {
    GLuint _frameBuffer;
    GLuint _texture2D;
}

- (instancetype)initWithWidth:(int)width height:(int)height {
    ADTexture2DOptions defaultTextureOptions = {0};
    defaultTextureOptions.minFilter = GL_LINEAR;
    defaultTextureOptions.magFilter = GL_LINEAR;
    defaultTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.internalFormat = GL_RGBA;
    defaultTextureOptions.format = GL_RGBA;
    defaultTextureOptions.type = GL_UNSIGNED_BYTE;
    
    return [self initWithWidth:width height:height texture2DOptions:&defaultTextureOptions];
}

- (instancetype)initWithWidth:(int)width height:(int)height texture2DOptions:(ADTexture2DOptions *)options {
    self = [super init];
    if (self) {
        glGenFramebuffers(1, &_frameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
        
        glGenTextures(1, &_texture2D);
        glBindTexture(GL_TEXTURE_2D, _texture2D);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, options->minFilter);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, options->magFilter);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, options->wrapS);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, options->wrapT);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _texture2D, 0);
        
        glBindTexture(GL_TEXTURE_2D, 0);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
    return self;
}

- (void)bindFrameBuffer {
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
}

- (void)unbindFrameBuffer {
    glBindTexture(GL_FRAMEBUFFER, 0);
}

- (void)dealloc {
    glDeleteFramebuffers(1, &_frameBuffer);
    glDeleteTextures(1, &_texture2D);
}

- (GLuint)outputTexture{
    return _texture2D;
}



@end
