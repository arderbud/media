//
//  RGBAFrameRender.h
//  Media
//
//  Created by arderbud on 2019/10/18.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RGBAFrameRender : NSObject

- (void)inputRGBAFrame:(uint8_t *)frame width:(int)width height:(int)height;

- (void)draw;

- (void)clean;

@end

NS_ASSUME_NONNULL_END
