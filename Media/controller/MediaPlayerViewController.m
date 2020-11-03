//
//  MediaPlayerViewController.m
//  Media
//
//  Created by bytedance on 2020/3/28.
//  Copyright © 2020 arderbud. All rights reserved.
//

#import "MediaPlayerViewController.h"
#import "AudioOutput.h"
#import "VideoOutput.h"
#import "AVDataProvider.h"
@interface MediaPlayerViewController () <AudioOutputDataSource>
@property (nonatomic, strong) AudioOutput *audioOutput;
@property (nonatomic, strong) VideoOutput *videoOutput;
@property (nonatomic, strong) AVDataProvider *dataProvider;
@end




@implementation MediaPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.view.backgroundColor = [UIColor whiteColor];
    [self initPlayer];
    [self initUI];
}

- (void)initPlayer {
    self.audioOutput = [[AudioOutput alloc] initWithBytesPerSample:2 sampleteRate:44100 nbChannels:2];
    NSString *mediaPath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"flv"];
    self.dataProvider = [[AVDataProvider alloc] initWithFileURL:[NSURL fileURLWithPath:mediaPath]];
    [self.dataProvider openFileWithOptions:nil Error:nil];
    [self.dataProvider run];
    self.audioOutput.dataSource = self;

    
}

- (void)initUI {
    UIButton *playBt = [UIButton buttonWithType:UIButtonTypeCustom];
    playBt.frame = CGRectMake(10, 120, 80, 30);
    playBt.backgroundColor = [UIColor purpleColor];
    [playBt setTitle:@"play" forState:UIControlStateNormal];
    [playBt addTarget:self action:@selector(playAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:playBt];
    
    VideoOutput *videoOutput = [[VideoOutput alloc] initWithFrame:CGRectMake(0, 200, 500, 300) shareGroup:nil];
    [self.view addSubview:videoOutput];
    self.videoOutput = videoOutput;
}


- (void)fillAudioData:(SInt16 *)outData nbFrames:(UInt32)nbFrames nbChannels:(UInt32)nbChannels {
    [self.dataProvider fillAudioData:outData nbFrames:nbFrames nbChannels:nbChannels];
    VideoFrame *videoFrame = [self.dataProvider getCorrespondVideoFrame];
    [self.videoOutput presentVideoFrame:videoFrame width:videoFrame.width height:videoFrame.height];
}

- (void)playAction {
    [self.audioOutput play];
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
