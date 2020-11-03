//
//  ShaderOperations.h
//  OpenGLDemo
//
//  Created by Chris Hu on 15/7/30.
//  Copyright (c) 2015年 Chris Hu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

@interface ShaderOperations : NSObject

+ (GLuint)compileShader:(NSString*)shaderName withType:(GLenum)shaderType;

+ (GLuint)compileShaders:(NSString *)shaderVertex shaderFragment:(NSString *)shaderFragment;

@end
