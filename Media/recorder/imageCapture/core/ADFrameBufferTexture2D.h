//
//  ADFrameBufferTexture2D.h
//  Media
//
//  Created by arderbud on 2019/11/5.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct TextureOptions {
    GLenum minFilter;
    GLenum magFilter;
    GLenum wrapS;
    GLenum wrapT;
    GLenum internalFormat;
    GLenum format;
    GLenum type;
} ADTexture2DOptions;

@interface ADFrameBufferTexture2D : NSObject

- (instancetype)initWithWidth:(int)width height:(int)height;

- (instancetype)initWithWidth:(int)width height:(int)height texture2DOptions:(ADTexture2DOptions *)options;

- (void)bindFrameBuffer;

- (void)unbindFrameBuffer;

- (GLuint)outputTexture;

@end

NS_ASSUME_NONNULL_END
