//
//  RectangleLayer.m
//  Media
//
//  Created by 杜德强 on 2019/9/26.
//  Copyright © 2019 杜德强. All rights reserved.
//

#import "RectangleLayer.h"
#import <OpenGLES/ES3/gl.h>
//#import <OpenGLES/ES3/glext.h>

@implementation RectangleLayer

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setOpaque:YES];
        [self setDrawableProperties:[NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithBool:NO],kEAGLDrawablePropertyRetainedBacking,
                                          kEAGLColorFormatRGB565,kEAGLDrawablePropertyColorFormat, nil]];
        [self initEAGLContext];
    }
    return self;
}

- (void)initEAGLContext {
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:context];
    
    GLuint frameBuffer;
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    
    GLuint colorRenderBuffer;
    glGenRenderbuffers(1, &colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderBuffer);
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderBuffer);
    

}


@end
