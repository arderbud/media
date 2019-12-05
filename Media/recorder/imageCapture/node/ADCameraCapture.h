//
//  ADCameraCapture.h
//  Media
//
//  Created by arderbud on 2019/11/5.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "ADImageOutput.h"
#import <OpenGLES/EAGL.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    kADImageNoRotation,
    kADImageFlipHorizontal
} ADImageRotationMode;

#define TEXTURE_FRAME_ASPECT_RATIO                                  16.0/9.0f

@interface ADCameraCapture : ADImageOutput

@property (nonatomic, readonly) int fps; 

- (instancetype)initWithFPS:(int)fps shareGroup:(EAGLSharegroup *)group NS_DESIGNATED_INITIALIZER;

- (void)startRunning;

- (void)stopRunning;

- (int)switchCamera;

- (void)swichResolution;


@end


NS_ASSUME_NONNULL_END
