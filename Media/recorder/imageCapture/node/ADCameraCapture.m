//
//  ADCameraCapture.m
//  Media
//
//  Created by arderbud on 2019/11/5.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <OpenGLES/EAGL.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "ADCameraCapture.h"
#import "ADRenderPipeline.h"
#import "ADFrameBufferTexture2D.h"

static NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

static NSString *const fragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );

static NSString *const YUVVideoRangeConversionForLAFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r - (16.0/255.0);
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );

@interface ADCameraFrameRender : ADRenderPipeline

- (instancetype)initWithVertexShaderSrc:(NSString *)vetextSrc fragmentShaderSrc:(NSString *)fragmentSrc context:(EAGLContext *)context;

- (void)setSampleBuffer:(CMSampleBufferRef)sampleBuffer aspectRatio:(float)aspectRatio preferredConversion:(const GLfloat *)conversion imageRotation:(ADImageRotationMode)rotation;

@end

@implementation ADCameraFrameRender {
    CVOpenGLESTextureCacheRef _textureCache;
    GLuint _luminanceTexture;
    GLuint _chrominanceTexture;
    const GLfloat *_conversion;
    EAGLContext *_context;
}

- (instancetype)initWithVertexShaderSrc:(NSString *)vetextSrc fragmentShaderSrc:(NSString *)fragmentSrc context:(EAGLContext *)context {
    self = [super initWithVertexShaderSrc:vetextSrc fragmentShaderSrc:fragmentSrc];
    if (self) {
        CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, context, NULL, &_textureCache);
        _context = context;
    }
    return self;
}


- (void)setSampleBuffer:(CMSampleBufferRef)sampleBuffer aspectRatio:(float)aspectRatio preferredConversion:(const GLfloat *)conversion imageRotation:(ADImageRotationMode)rotation{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    int bufferWidth = (int) CVPixelBufferGetWidth(imageBuffer);
    int bufferHeight = (int) CVPixelBufferGetHeight(imageBuffer);
    
    glViewport(0, 0, bufferWidth, bufferHeight);
//    glUseProgram(_shaderProgram);
    CVOpenGLESTextureRef luminanceTextureRef = NULL;
    CVOpenGLESTextureRef chrominanceTextureRef = NULL;
//    CVReturn err;
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    // Convert image buffer to texture for OpenGLES
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, imageBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
    _luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
    glBindTexture(GL_TEXTURE_2D, _luminanceTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, imageBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth / 2, bufferHeight / 2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
    _chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
    glBindTexture(GL_TEXTURE_2D, _chrominanceTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    _conversion = conversion;
    
 
    int targetWidth = bufferHeight / aspectRatio;
//    int targetHeight = bufferHeight;
    float fromX = (float)((bufferWidth - targetWidth) / 2) / (float) bufferWidth;
    float toX = 1.0f - fromX;
    
    GLfloat squareVertices[] = {
        -1.0f, -1.0f, fromX, 1.0f,
        1.0f, -1.0f, toX, 1.0f,
        -1.0f,  1.0f, fromX, 0.0f,
        1.0f,  1.0f, toX, 0.0f,
    };
    
    if(rotation == kADImageFlipHorizontal){
        squareVertices[3] = toX;
        squareVertices[7] = fromX;
        squareVertices[11] = toX;
        squareVertices[15] = fromX;
    }
    
    glGenVertexArrays(1, &_VAO);
    glBindVertexArray(_VAO);
    
    glGenBuffers(1, &_VBO);
    glBindBuffer(GL_ARRAY_BUFFER, _VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(squareVertices), squareVertices, GL_STATIC_DRAW);
    
    int posAttribIndex = glGetAttribLocation(_shaderProgram, "position");
    glEnableVertexAttribArray(posAttribIndex);
    glVertexAttribPointer(posAttribIndex, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (const GLvoid *)0);
    int texcoordAttribIndex = glGetAttribLocation(_shaderProgram, "inputTextureCoordinate");
    glEnableVertexAttribArray(texcoordAttribIndex);
    glVertexAttribPointer(texcoordAttribIndex, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (const GLvoid *)(2 * sizeof(GLfloat)));
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
 
}

- (void)draw {
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glUseProgram(_shaderProgram);
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, _luminanceTexture);
    glUniform1i(glGetUniformLocation(_shaderProgram, "luminanceTexture"), 4);
    
    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, _chrominanceTexture);
    glUniform1i(glGetUniformLocation(_shaderProgram, "chrominanceTexture"), 5);
    
    glUniformMatrix3fv(glGetUniformLocation(_shaderProgram, "colorConversionMatrix"), 1, GL_FALSE, _conversion);


    glBindVertexArray(_VAO);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArray(0);
    
}

@end

static GLfloat colorConversion601Default[] = {
    1.164,  1.164, 1.164,
    0.0, -0.392, 2.017,
    1.596, -0.813,   0.0,
};

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
static GLfloat colorConversion601FullRangeDefault[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

// BT.709, which is the standard for HDTV.
static GLfloat colorConversion709Default[] = {
    1.164,  1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};

static GLfloat *colorConversion601 = colorConversion601Default;
static GLfloat *colorConversion601FullRange = colorConversion601FullRangeDefault;
static GLfloat *colorConversion709 = colorConversion709Default;


@interface ADCameraCapture () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, assign) BOOL shouldEnableOpenGL;
@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureConnection *connection;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, strong) AVCaptureVideoDataOutput *output;

@property (nonatomic, strong) AVCaptureDevice *frontCamera;
@property (nonatomic, strong) AVCaptureDevice *backCamera;

@property (nonatomic, strong) ADCameraFrameRender *frameRender;

@end


@implementation ADCameraCapture {
    ADImageRotationMode    _inputTexRotation;
    BOOL                   _isFullYUVRange;
    dispatch_queue_t       _outputQueue;
    const GLfloat *        _preferredConversion;
    ADFrameBufferTexture2D *_frameBufferTexture2D;
    
}

- (instancetype)initWithFPS:(int)fps shareGroup:(EAGLSharegroup *)group {
    self = [super init];
    if (self) {
        _fps = YES;
        _shouldEnableOpenGL = YES;
        _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3 sharegroup:group];
        _outputQueue = dispatch_queue_create("com.arderbud.captureOutputQueue", DISPATCH_QUEUE_SERIAL);
        [self configureSession];
        [self updateOrientationSendToTargets];
        if (_isFullYUVRange)
            _frameRender = [[ADCameraFrameRender alloc] initWithVertexShaderSrc:vertexShaderString fragmentShaderSrc:fragmentShaderString context:_glContext];
        else
            _frameRender = [[ADCameraFrameRender alloc] initWithVertexShaderSrc:vertexShaderString fragmentShaderSrc:YUVVideoRangeConversionForLAFragmentShaderString context:_glContext];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    }
    return self;
}

- (void)configureSession {
    self.captureSession = [[AVCaptureSession alloc] init];
    self.input = [[AVCaptureDeviceInput alloc] initWithDevice:self.frontCamera error:nil];
    self.output = [[AVCaptureVideoDataOutput alloc] init];
    self.output.alwaysDiscardsLateVideoFrames = YES;
    BOOL supportFullYUVRange = NO;
    NSArray *supportedPixelFormats = _output.availableVideoCVPixelFormatTypes;
    for (NSNumber *format in supportedPixelFormats) {
        if ([format intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            supportFullYUVRange = YES;
            break;
        }
    }
    
    if (supportFullYUVRange) {
        [_output setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)}];
        _isFullYUVRange = YES;
    } else {
        [_output setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)}];
        _isFullYUVRange = NO;
    }
    [_output setSampleBufferDelegate:self queue:_outputQueue];
    if ([self.captureSession canAddInput:self.input])
        [self.captureSession addInput:self.input];
    if ([self.captureSession canAddOutput:self.output])
        [self.captureSession addOutput:self.output];
    
    [_captureSession beginConfiguration];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720])
        [_captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
    else
        [_captureSession setSessionPreset:AVCaptureSessionPreset640x480];
    self.connection = [self.output connectionWithMediaType:AVMediaTypeVideo];
    [self setRelativeVideoOrientation];
    [self setFrameRate];
    [_captureSession commitConfiguration];
   
    
    
}

- (AVCaptureDevice *)frontCamera {
    if (!_frontCamera) {
        _frontCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
    }
    return _frontCamera;
}

- (AVCaptureDevice *)backCamera {
    if (!_backCamera) {
        _backCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
    }
    return _backCamera;
}

- (int)switchCamera {
    NSUInteger cameraCount = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    int result = -1;
    if (cameraCount > 1) {
        NSError *error;
        AVCaptureDeviceInput *videoInput;
        AVCaptureDevicePosition position = [[self.input device] position];
        
        if (position == AVCaptureDevicePositionBack) {
            videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.frontCamera error:&error];
            result = 0;
        } else if (position == AVCaptureDevicePositionFront) {
            videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.backCamera error:&error];
            result = 1;
        } else {
            return -1;
        }
        if (videoInput != nil) {
            [self.captureSession beginConfiguration];
            [self.captureSession removeInput:self.input];
            if ([self.captureSession canAddInput:videoInput]) {
                [self.captureSession addInput:videoInput];
                self.input = videoInput;
            } else {
                [self.captureSession addInput:self.input];
            }
            
            self.connection = [self.output connectionWithMediaType:AVMediaTypeVideo];
            
            AVCaptureVideoStabilizationMode stabilizationMode = AVCaptureVideoStabilizationModeStandard;
            
            BOOL supportStabilization = [self.input.device.activeFormat isVideoStabilizationModeSupported:stabilizationMode];
            NSLog(@"device active format: %@, 是否支持防抖: %@", self.input.device.activeFormat,
                  supportStabilization ? @"support" : @"not support");
            if ([self.input.device.activeFormat isVideoStabilizationModeSupported:stabilizationMode]) {
                [self.connection setPreferredVideoStabilizationMode:stabilizationMode];
                NSLog(@"===============mode %@", @(self.connection.activeVideoStabilizationMode));
            }
            
            [self setRelativeVideoOrientation];
            [self setFrameRate];
            
            [self.captureSession commitConfiguration];
        } else if (error) {
            result = -1;
        }
        [self updateOrientationSendToTargets];
    }
    
    return result;
}

- (void) updateOrientationSendToTargets {
    if ([self cameraPosition] == AVCaptureDevicePositionBack) {
        _inputTexRotation = kADImageNoRotation;
    } else{
        _inputTexRotation = kADImageFlipHorizontal;
    }
}

- (AVCaptureDevicePosition)cameraPosition {
    return self.input.device.position;
    
}

- (void)setFrameRate;
{
    if (_fps > 0)
    {
        if ([self.input.device respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
            [self.input.device respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
            
            NSError *error;
            [self.input.device lockForConfiguration:&error];
            if (error == nil) {
#if defined(__IPHONE_7_0)
                [self.input.device setActiveVideoMinFrameDuration:CMTimeMake(1, _fps)];
                [self.input.device setActiveVideoMaxFrameDuration:CMTimeMake(1, _fps)];
                
                // 对焦模式
                if ([self.input.device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                    [self.input.device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
                } else if ([self.input.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
                    [self.input.device setFocusMode:AVCaptureFocusModeAutoFocus];
                }
#endif
            }
            [self.input.device unlockForConfiguration];
            
        } else {
            
            for (AVCaptureConnection *connection in self.output.connections)
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                    connection.videoMinFrameDuration = CMTimeMake(1, _fps);
                
                if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
                    connection.videoMaxFrameDuration = CMTimeMake(1, _fps);
#pragma clang diagnostic pop
            }
        }
        
    }
    else
    {
        if ([self.input.device respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
            [self.input.device respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
            
            NSError *error;
            [self.input.device lockForConfiguration:&error];
            if (error == nil) {
#if defined(__IPHONE_7_0)
                [self.input.device setActiveVideoMinFrameDuration:kCMTimeInvalid];
                [self.input.device setActiveVideoMaxFrameDuration:kCMTimeInvalid];
                
                // 对焦模式
                if ([self.input.device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                    [self.input.device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
                } else if ([self.input.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
                    [self.input.device setFocusMode:AVCaptureFocusModeAutoFocus];
                }
#endif
            }
            [self.input.device unlockForConfiguration];
            
        } else {
            
            for (AVCaptureConnection *connection in self.output.connections)
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                    connection.videoMinFrameDuration = kCMTimeInvalid; // This sets videoMinFrameDuration back to default
                
                if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
                    connection.videoMaxFrameDuration = kCMTimeInvalid; // This sets videoMaxFrameDuration back to default
#pragma clang diagnostic pop
            }
        }
        
    }
}

- (void)setRelativeVideoOrientation {
    self.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
}


#pragma mark - 获得摄像头
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            NSError *error = nil;
            if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] && [device lockForConfiguration:&error]){
                [device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
                if ([device isFocusPointOfInterestSupported])
                    [device setFocusPointOfInterest:CGPointMake(0.5f,0.5f)];
                [device unlockForConfiguration];
            }
            return device;
        }
    }
    return nil;
}

#pragma mark - 切换分辨率
- (void)switchResolution {
    // begin configuration for the AVCaptureSession
    [_captureSession beginConfiguration];
    // picture resolution
    if([_captureSession.sessionPreset isEqualToString:[NSString stringWithString:AVCaptureSessionPreset640x480]])
    {
        [_captureSession setSessionPreset:[NSString stringWithString:AVCaptureSessionPreset1280x720]];
    }
    else
    {
        [_captureSession setSessionPreset:[NSString stringWithString:AVCaptureSessionPreset640x480]];
    }
    [_captureSession commitConfiguration];
}

- (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFTypeRef colorAttachment = CVBufferGetAttachment(imageBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachment != NULL) {
        if (CFStringCompare(colorAttachment, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo) {
            if (_isFullYUVRange)
                _preferredConversion = colorConversion601FullRange;
            else
                _preferredConversion = colorConversion601;
        } else {
            _preferredConversion = colorConversion709;
        }
    } else {
        if (_isFullYUVRange)
            _preferredConversion = colorConversion601FullRange;
        else
            _preferredConversion = colorConversion601;
    }
    
    [EAGLContext setCurrentContext:_glContext];
    [[self frameBufferTexture2DWithSampleBuffer:imageBuffer aspectRatio:TEXTURE_FRAME_ASPECT_RATIO] bindFrameBuffer];
    [self.frameRender setSampleBuffer:sampleBuffer aspectRatio:TEXTURE_FRAME_ASPECT_RATIO preferredConversion:_preferredConversion imageRotation:_inputTexRotation];
    [self.frameRender draw];
    [_frameBufferTexture2D unbindFrameBuffer];
    for (id<ADImageInput> target in _targets) {
        [target setInputTexture:_frameBufferTexture2D.outputTexture];
    }
    
    
}


- (ADFrameBufferTexture2D *)frameBufferTexture2DWithSampleBuffer:(CVImageBufferRef)imageBuffer aspectRatio:(float)aspectRatio {
    if (!_frameBufferTexture2D) {
        int targetHeigth = (int)CVPixelBufferGetHeight(imageBuffer);
        int targetWidth = targetHeigth / aspectRatio;
        _frameBufferTexture2D = [[ADFrameBufferTexture2D alloc] initWithWidth:targetWidth height:targetHeigth];
    }
    return _frameBufferTexture2D;
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    self.shouldEnableOpenGL = NO;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    self.shouldEnableOpenGL = YES;
}

- (void)startRunning {
    if (!_captureSession.isRunning)
        [_captureSession startRunning];
}

- (void)stopRunning {
    if (_captureSession.isRunning)
        [_captureSession stopRunning];
}





#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (self.shouldEnableOpenGL)
        [self processVideoSampleBuffer:sampleBuffer];
    
}



@end


