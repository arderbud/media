//
//  GeometryViewController.m
//  Media
//
//  Created by arderbud on 2019/9/24.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "GeometryViewController.h"
#import "RectangleView.h"
#import "ViewDrawImageOpenGLES.h"
@interface GeometryViewController ()

@end

@implementation GeometryViewController {
    RectangleView *_rectangleView;
    ViewDrawImageOpenGLES *_viewDrawImage;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _rectangleView = [[RectangleView alloc] initWithFrame:CGRectMake(64, 100, 200, 283)];
    [_rectangleView draw];
    [self.view addSubview:_rectangleView];
    
//    _viewDrawImage = [[ViewDrawImageOpenGLES alloc] initWithFrame:CGRectMake(64, 100, 200, 283)];
//    [self.view addSubview:_viewDrawImage];
    
    // Do any additional setup after loading the view.
   
}

- (void)dealloc {
    [_rectangleView clean];
}



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
