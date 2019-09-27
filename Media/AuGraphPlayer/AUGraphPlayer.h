//
//  AUGraphPlayer.h
//  Media
//
//  Created by arderbud on 2019/9/10.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AUGraphPlayer : NSObject

+ (instancetype)sharedInstance;

- (void)playWithFilePath:(NSString *)path;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
