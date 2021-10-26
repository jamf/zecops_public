//
//  ViewController.m
//  ios_streaming_cam
//
//  Created by 08tc3wbb on 1/16/20.
//  Copyright © 2020 08tc3wbb. All rights reserved.
//

#import "ViewController.h"
#include "LFLiveKit.h"

@interface ViewController () <LFLiveSessionDelegate>
@end

@implementation ViewController{
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)requestAccessForVideo{
    __weak typeof(self) _self = self;
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusNotDetermined:
        {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if(granted){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        //[_self.session setRunning:YES];
                    });
                }
            }];
            break;
        }
        case AVAuthorizationStatusAuthorized:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                //[_self.session setRunning:YES];
            });
            break;
        }
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
            break;
        default:
            break;
    }
}

-(void)requestAccessForAudio{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (status) {
        case AVAuthorizationStatusNotDetermined:{
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            }];
        }
            break;
            
        case AVAuthorizationStatusAuthorized:
            break;
        case AVAuthorizationStatusRestricted:
        case AVAuthorizationStatusDenied:
            break;
        default:
            break;
    }
    
}

- (void)stopLive {
    //[_session stopLive];
}

-(void)liveSession:(LFLiveSession *)session liveStateDidChange:(LFLiveState)state{
    switch (state) {
        case LFLiveReady:
            printf("unconnected.\n");
            break;
        case LFLivePending:
            printf("pending before esta conn...\n");
            break;
        case LFLiveStart:
            printf("connecting...\n");
            break;
        case LFLiveStop:
            printf("disconnected.\n");
            break;
        case LFLiveError:
            printf("error occurred while connecting.\n");
        default:
            break;
    }
}

-(void)liveSession:(LFLiveSession *)session debugInfo:(LFLiveDebug *)debugInfo{
    NSLog(@"bugInfo:%@",debugInfo);
}

- (void)liveSession:(nullable LFLiveSession*)session errorCode:(LFLiveSocketErrorCode)errorCode{
    NSLog(@"errorCode: %ld", errorCode);
}

@end
