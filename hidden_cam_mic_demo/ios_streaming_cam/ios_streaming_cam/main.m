//
//  main.m
//  ios_streaming_cam
//
//  Created by 08tc3wbb on 1/16/20.
//  Copyright © 2020 08tc3wbb. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#import "AppDelegate.h"
#include "LFLiveKit.h"
#include <ifaddrs.h>
#include <net/if.h>
#include <arpa/inet.h>
#include <dlfcn.h>
#include <objc/runtime.h>


@interface StreamCls : NSObject <LFLiveSessionDelegate>
-(void)golive;
@end
@implementation StreamCls

LFLiveSession *_session;
- (LFLiveSession*)session {
    if (!_session) {
        
        LFLiveAudioConfiguration *audioconf = [LFLiveAudioConfiguration defaultConfigurationForQuality:LFLiveAudioQuality_Default];
        LFLiveVideoConfiguration *videoconf = [LFLiveVideoConfiguration defaultConfigurationForQuality:LFLiveVideoQuality_Default];
        
        _session = [[LFLiveSession alloc] initWithAudioConfiguration:audioconf videoConfiguration:videoconf captureType:LFLiveCaptureMaskAll];
        _session.delegate = self;
        [_session setRunning:YES];
    }
    return _session;
}


char *streaminfo_url = NULL;

-(void) golive{
    LFLiveStreamInfo *streamInfo = [LFLiveStreamInfo new];
    streamInfo.url = [NSString stringWithUTF8String:streaminfo_url];
    printf("streamInfo.url: %s\n", [streamInfo.url UTF8String]);
    LFLiveSession *_session = [self session];
    [_session startLive:streamInfo];
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

@interface TestCapture : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (strong) AVCaptureSession *session;
-(void)gotest;
@end
@implementation TestCapture
-(void)gotest{
    [self setupCaptureSession];
}

- (void)setupCaptureSession
{
    NSError *error = nil;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetLow;
    if([self.session canAddInput:input]){
        [self.session addInput:input];
    }else{
        printf("--- error can't add input\n");
    }
    
    if([self.session canAddOutput:output]){
        [self.session addOutput:output];
    }else{
        printf("--- error can't add output\n");
    }
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:self.session];
    
    do{
        printf("---- Start launching the camera (now running? %d interp? %d)\n", [self.session isRunning], [self.session isInterrupted]);
        [self.session startRunning];
        printf("---- End launching the camera (now running? %d interp? %d)\n", [self.session isRunning], [self.session isInterrupted]);
        printf("---- detecting status...\n");
 
        if([self.session isRunning] == 1){
            printf("Camera is running!\n");
            break;
        }
        printf("pid: %d Trying again in 5 sec...\n", getpid());
        sleep(1);
        printf("  4 sec...\n");
        sleep(1);
        printf("  3 sec...\n");
        sleep(1);
        printf("  2 sec...\n");
        sleep(1);
        printf("  1 sec...\n");
        sleep(1);
        printf("  0 sec...\n");
        sleep(1);
    }while(1);
    printf("---- out of loop now...\n");
}

- (void)sessionRuntimeError:(NSNotification *)notification{
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    //NSLog( @"--- sessionRuntimeError Error: %@", error );
}

- (void)sessionWasInterrupted:(NSNotification *)notification{
    AVCaptureSessionInterruptionReason reason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
    
    //NSLog( @"--- sessionWasInterrupted %ld", (long)reason );
    
    /*
     AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableInBackground               = 1,
     AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient                   = 2,
     AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient                   = 3,
     AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps = 4,
     AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableDueToSystemPressure API_AVAILABLE(ios(11.1)) = 5,
     */
}

- (void)sessionInterruptionEnded:(NSNotification *)notification{
    //NSLog( @"Capture session interruption ended, now continuing capture frames...");
}

-(void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    //printf("=== didDropSampleBuffer called \n");
}

-(void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    //printf("==== Receiving sample buffer...\n");
}

@end


void start_streaming(){
    StreamCls *aaa = [StreamCls new];
    [aaa golive];
}

void check_camera_permission(){
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusNotDetermined:{
            printf("camera access: not determined yet\n");
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if(granted){
                }
            }];
        }
            break;
        case AVAuthorizationStatusAuthorized:
            printf("camera access: authorized\n");
            break;
        case AVAuthorizationStatusDenied:
            printf("camera access: denied\n");
            break;
        case AVAuthorizationStatusRestricted:
            printf("camera access: restricted\n");
            break;
        default:
            break;
    }
}

void check_mic_permission(){
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (status) {
        case AVAuthorizationStatusNotDetermined:{
            printf("mic access: not determined yet\n");
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            }];
        }
            break;
        case AVAuthorizationStatusAuthorized:
            printf("mic access: authorized\n");
            break;
        case AVAuthorizationStatusDenied:
            printf("mic access: denied\n");
            break;
        case AVAuthorizationStatusRestricted:
            printf("mic access: restricted\n");
            break;
        default:
            break;
    }
}

void display_ip_address(){
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    if(getifaddrs(&interfaces) == 0){
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                
                printf("    %s: ", temp_addr->ifa_name);
                char *ip_addr = inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr);
                printf("    %s\n", ip_addr);
            }
            temp_addr = temp_addr->ifa_next;
        }
        freeifaddrs(interfaces);
    }else{
        printf("Error: getifaddrs\n");
    }
}

int main(int argc, char * argv[]) {
    
    printf("argv[1]: %s\n", argv[1]);
    streaminfo_url = argv[1];
    
    check_camera_permission();
    check_mic_permission();
    display_ip_address();
    
    start_streaming();
    
    CFRunLoopRun();
    
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
