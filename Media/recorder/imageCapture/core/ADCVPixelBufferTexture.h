//
//  ADCVPixelBufferTexture.h
//  Media
//
//  Created by arderbud on 2019/11/4.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import <CoreGraphics/CGGeometry.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>


typedef struct TextureOptions {
    GLenum minFilter;
    GLenum magFilter;
    GLenum wrapS;
    GLenum wrapT;
    GLenum internalFormat;
    GLenum format;
    GLenum type;
} ADTextureOptions;

NS_ASSUME_NONNULL_BEGIN

@interface ADCVPixelBufferTexture : NSObject

@property (nonatomic, readonly) int width;
@property (nonatomic, readonly) int height;

- (instancetype)initWithWidth:(int)width height:(int)height EAGLContext:(EAGLContext *)context;

- (instancetype)initWithWidth:(int)width height:(int)height EAGLContext:(EAGLContext *)context options:(ADTextureOptions *)options NS_DESIGNATED_INITIALIZER;

- (void)activeFrameBuffer;

- (GLuint)texture;

- (GLubyte *)pixelbBuffer;

@end

NS_ASSUME_NONNULL_END
