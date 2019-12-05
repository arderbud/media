//
//  ADImageOutput.m
//  Media
//
//  Created by arderbud on 2019/11/5.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "ADImageOutput.h"

@implementation ADImageOutput

- (instancetype)init {
    self = [super init];
    if (self) {
        _targets = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setInputTextureForTarget:(id<ADImageInput>)target {
    [target setInputTexture:_outputTexture];
}


- (GLuint)outputTexture {
    return _outputTexture;
}

- (void)addTarget:(id<ADImageInput>)target {
    [_targets addObject:target];
}

- (void)removeTarget:(id<ADImageInput>)target {
    if (![_targets containsObject:target])
        return;
    [_targets removeObject:target];
}

- (void)removeAllTargets {
    [_targets removeAllObjects];
}


@end
