//
//  VideoOutput.h
//  Media
//
//  Created by arderbud on 2019/10/17.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <UIKit/UIKit.h>


#import "MediaDecoder.h"

NS_ASSUME_NONNULL_BEGIN

@interface VideoOutput : UIView

- (instancetype)initWithFrame:(CGRect)frame shareGroup:(nullable EAGLSharegroup *)shareGroup NS_DESIGNATED_INITIALIZER;

- (void)presentVideoFrame:(VideoFrame *)frame width:(int)width height:(int)height;

- (void)destroy;


@end

NS_ASSUME_NONNULL_END
