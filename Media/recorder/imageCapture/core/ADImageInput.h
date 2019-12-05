//
//  ADImageInput.h
//  Media
//
//  Created by arderbud on 2019/11/4.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES3/gl.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ADImageInput <NSObject>

- (void)setInputTexture:(GLuint)texture;


@end
NS_ASSUME_NONNULL_END
