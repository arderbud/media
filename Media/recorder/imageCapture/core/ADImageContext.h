//
//  ADImageContext.h
//  Media
//
//  Created by arderbud on 2019/11/6.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@interface ADImageContext : NSObject

@property (nonatomic, readonly, strong) dispatch_queue_t contextQueue;
@property (nonatomic, readonly, retain) EAGLContext *context;
@property (readonly) CVOpenGLESTextureCacheRef coreVideoTextureCache;

+ (void *)contextKey;

+ (ADImageContext *)sharedImageProcessingContext;



@end

NS_ASSUME_NONNULL_END
