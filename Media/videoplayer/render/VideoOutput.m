//
//  VideoOutput.m
//  Media
//
//  Created by arderbud on 2019/10/17.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "VideoOutput.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import "YUVFrameRender.h"
#import "ContrastEnhancerFilter.h"
#import "PassthroughFilter.h"

@interface VideoOutput ()
@property (atomic) BOOL readyToRender;
@property (nonatomic, assign) BOOL openGLEnable;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) NSOperationQueue *renderOperationQueue;
@end

@implementation VideoOutput {
    EAGLContext *_glContext;
    GLuint  _displayFrameBuffer;
    GLuint  _renderBuffer;
    GLint   _backingWidth;
    GLint   _backingHeight;
    
    BOOL    _stop;
    
    YUVFrameRender   *_yuvRender;
    PassthroughFilter *_PassthroughFilter;
    ContrastEnhancerFilter *_contrastFilter;
    
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithFrame:CGRectZero shareGroup:nil];
}


- (instancetype)initWithFrame:(CGRect)frame{
    return [self initWithFrame:frame shareGroup:nil];
}

- (instancetype)initWithFrame:(CGRect)frame shareGroup:(EAGLSharegroup *)shareGroup {
    self = [super initWithFrame:frame];
    if (self) {
        _lock = [[NSLock alloc] init];
        [_lock lock];
        _openGLEnable = [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
        _readyToRender = YES;
        [_lock unlock];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];
        _renderOperationQueue = [[NSOperationQueue alloc] init];
        _renderOperationQueue.maxConcurrentOperationCount = 1;
        _renderOperationQueue.name = @"com.arderbud.videoPlayer.videoRenderQueue";
        
        __weak VideoOutput *weakSelf = self;
        [_renderOperationQueue addOperationWithBlock:^{
            if (!weakSelf)
                return;
            __strong VideoOutput *strongSelf = weakSelf;
            [strongSelf configureOpenGLESContext:shareGroup];
            [strongSelf createRenderPipeline];
            
        }];
    }
    return  self;
}

- (BOOL)configureOpenGLESContext:(EAGLSharegroup *)shareGroup {
    
    GLenum status;
    if (shareGroup)
        _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3 sharegroup:shareGroup];
    else
        _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:_glContext];
    
    glGenFramebuffers(1, &_displayFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFrameBuffer);
    
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [_glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Fail to complete framebuffer.");
        return NO;
    }
    
    status = glGetError();
    if (status != GL_NO_ERROR) {
        NSLog(@"Fail to setup framebuffer %x",status);
        return NO;
    }
    
    return YES;
}

- (void)createRenderPipeline {
    _PassthroughFilter = [[PassthroughFilter alloc] init];
    _yuvRender = [[YUVFrameRender alloc] init];
    _contrastFilter = [[ContrastEnhancerFilter alloc] init];
}

static const NSInteger kMaxOperationQueueCount = 3;

- (void)presentVideoFrame:(VideoFrame *)frame width:(int)width height:(int)height {
    NSInteger operationsCount = _renderOperationQueue.operationCount;
    
    if (operationsCount > kMaxOperationQueueCount) {
        [_renderOperationQueue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx < operationsCount - kMaxOperationQueueCount)
                [obj cancel];
            else
                *stop = YES;
        }];
    }
    __weak VideoOutput* weakSelf = self;
    [_renderOperationQueue addOperationWithBlock:^{
        __strong VideoOutput *strongSelf = weakSelf;
        GLuint yuvTexture,contrastTexure;
        if (!strongSelf)
            return;
        
        [strongSelf.lock lock];
        if (!strongSelf.readyToRender || !strongSelf.openGLEnable) {
            glFinish();
            [strongSelf.lock unlock];
            return;
        }
        [strongSelf.lock unlock];
        
        [EAGLContext setCurrentContext:strongSelf->_glContext];
        
        yuvTexture = [strongSelf genYUVTexture:frame width:width height:height];
        contrastTexure = [strongSelf contrastFilterTexutre:yuvTexture width:width height:height];
        [strongSelf presentTexure:contrastTexure width:strongSelf->_backingWidth height:strongSelf->_backingHeight];
        
    }];
}

- (GLuint)genYUVTexture:(VideoFrame *)frame width:(int)width height:(int)height {
    GLuint frameBuffer;
    GLuint outputTexture;
    
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    
    glGenTextures(1, &outputTexture);
    glBindTexture(GL_TEXTURE_2D, outputTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, outputTexture, 0);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", status);
    }
    
    [_yuvRender inputVideoFrame:frame width:width height:height];
    [_yuvRender draw];
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &frameBuffer);
    return outputTexture;
}

- (GLuint)contrastFilterTexutre:(GLuint)texture width:(int)width height:(int)height {
    GLuint frameBuffer;
    GLuint outputTexture;
    
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    
    glGenTextures(1, &outputTexture);
    glBindTexture(GL_TEXTURE_2D, outputTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, outputTexture, 0);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
    [_contrastFilter inputTexture:texture width:width height:height];
    [_contrastFilter draw];
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &frameBuffer);
    
    return outputTexture;
}

- (void)presentTexure:(GLuint)texure width:(int)width height:(int)height {
    
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFrameBuffer);
    [_PassthroughFilter inputTexture:texure width:width height:height];
    [_PassthroughFilter draw];
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [_glContext presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)destroy {
    _stop = YES;
    __weak VideoOutput *weakSelf = self;
    [self.renderOperationQueue addOperationWithBlock:^{
        __strong VideoOutput *strongSelf = weakSelf;
        if (!strongSelf)
            return ;
        [strongSelf->_contrastFilter clean];
        [strongSelf->_yuvRender clean];
        [strongSelf->_PassthroughFilter clean];
        glDeleteBuffers(1, &strongSelf->_displayFrameBuffer);
        glDeleteBuffers(1, &strongSelf->_renderBuffer);
    }];
}

/*
 // Only override drawRect: if you perform custom drawing.
 // An empty implementation adversely affects performance during animation.
 - (void)drawRect:(CGRect)rect {
 // Drawing code
 }
 */

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

@end
