//
//  ViewController.m
//  Media
//
//  Created by arderbud on 2019/9/3.
//  Copyright © 2019 arderbud. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <OpenGLES/ES3/gl.h>
#import <pthread.h>

#import "ViewController.h"
#import "Mp3Endec.hpp"
#import "MediaDecomposer.hpp"
#import "AudioPlayerViewController.h"
#import "RectangleView.h"
#import "GeometryViewController.h"
#import "VideoDecoder.h"
#import "AVDataProvider.h"


static void CheckStatus(OSStatus status,NSString *message,BOOL fatal) {
    if (status != noErr) {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';
        if (isprint(fourCC[0]) &&
            isprint(fourCC[1]) &&
            isprint(fourCC[2]) &&
            isprint(fourCC[3]))
            NSLog(@"%@:%s",message,fourCC);
        else
            NSLog(@"%@:%d",message,(int)status);
        if (fatal)
            exit(-1);
    }
    
}

static void * decodeRoutine(void *arg) {
    /*
    NSArray *frames;
    NSString *flvPath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"flv"];
    VideoDecoder *decoder = [[VideoDecoder alloc] initWithFileURL:[NSURL URLWithString:flvPath]];
    [decoder openFileWithOptions:nil error:nil];
    
    do {
        frames = [decoder decodeFramesWithMinDuration:CGFLOAT_MAX error:NULL];
    } while (frames.count > 0);*/
    
    NSString *flvPath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"flv"];
    AVDataProvider *provider = [[AVDataProvider alloc] initWithFileURL:[NSURL URLWithString:flvPath]];
    [provider openFileWithOptions:nil Error:nil];
    SInt16 *buffer = (SInt16 *)calloc(2048, 2);
    int i = 0;
    do {
        [provider fillAudioData:buffer nbFrames:1024 nbChannels:2];
        i++;
        NSLog(@"i:%d",i);
        usleep(100);
    } while (i < 2000);
    return  NULL;
}

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    /*
    pthread_t tid;
    pthread_create(&tid, NULL, decodeRoutine, NULL);*/
    /*
    NSString *flvPath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"flv"];
    AVDataProvider *provider = [[AVDataProvider alloc] initWithFileURL:[NSURL URLWithString:flvPath]];
    [provider openFileWithOptions:nil Error:nil];
    SInt16 *buffer = (SInt16 *)calloc(2048, 2);
    int i = 0;
    do {
        [provider fillAudioData:buffer nbFrames:1024 nbChannels:2];
        i++;
        NSLog(@"i:%d",i);
        usleep(100);
    } while (i < 2000);*/
    self.title = @"MediaDemo";
}

- (IBAction)startEncode:(id)sender {
    NSString *pcmFilePath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"pcm"];
    NSString *mp3FilePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"test.mp3"];
    Mp3Endec *endec = new Mp3Endec();
    endec->init([pcmFilePath
                 cStringUsingEncoding:NSUTF8StringEncoding], [mp3FilePath cStringUsingEncoding:NSUTF8StringEncoding], 44100, 2, 11);
    endec->encode();
    endec->destroy();
    delete endec;
}

- (IBAction)decompose:(id)sender {
    NSString *mediaFilePath = [[NSBundle mainBundle] pathForResource:@"party" ofType:@"mp4"];
    NSString *pcmFilePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"party.pcm"];
    MediaDecomposer *mediaDecomposer = new MediaDecomposer();
    mediaDecomposer->decompose([mediaFilePath cStringUsingEncoding:NSUTF8StringEncoding], [pcmFilePath cStringUsingEncoding:NSUTF8StringEncoding], NULL);
    delete mediaDecomposer;
}

- (IBAction)openAudioUnit:(id)sender {
    UIViewController *vc = [[AudioPlayerViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
    
}

- (IBAction)openGL:(id)sender {
    GeometryViewController *triangleVC = [[GeometryViewController alloc] init];
    [self.navigationController pushViewController:triangleVC animated:YES];
}


@end
