//
//  AudioPlayerViewController.m
//  Media
//
//  Created by arderbud on 2019/9/11.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import "AudioPlayerViewController.h"
#import "AuGraphPlayer.h"

@interface AudioPlayerViewController ()

@end

@implementation AudioPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}
- (IBAction)play:(id)sender {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"audio" ofType:@"m4a"];
    [[AUGraphPlayer sharedInstance] playWithFilePath:filePath];
}
- (IBAction)stop:(id)sender {
    [[AUGraphPlayer sharedInstance] stop];
    
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
