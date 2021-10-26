//
//  mediaserverd_patch.m
//  mediaserverd_patchUITests
//
//  Created by 08tc3wbb on 10/15/21.
//  Copyright © 2021 08tc3wbb. All rights reserved.
//

/*
 
 clang -arch arm64 -isysroot /Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk -framework CoreFoundation mediaserverd_patch.m -shared -o mediaserverd_patch.dylib
 
 codesign -f -s <YOUR IDENTITY> --entitlements </path/to/ent.txt> mediaserverd_patch.dylib
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/event.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <mach/mach.h>
#include <CoreFoundation/CoreFoundation.h>
#include <pthread/pthread.h>
#include <objc/runtime.h>

@interface FigCaptureClientSessionMonitor : NSObject
-(NSString*)applicationID;
-(void)_updateClientStateCondition:(id)arg1 newValue:(id)arg2;
@end

@interface myclass : NSObject
-(void)replace_updateClientStateCondition:(id)arg1 newValue:(id)arg2;
@end
@implementation myclass
-(void)replace_updateClientStateCondition:(id)arg1 newValue:(id)arg2{
    
    FigCaptureClientSessionMonitor *cast_self = self;
    if([[cast_self applicationID] isEqualToString:@"ios_streaming_cam_bin"]){
        return;
    }
    [self replace_updateClientStateCondition: arg1 newValue:arg2];
}
@end


__attribute__((constructor)) static void initialize(void){
    Method orignal = class_getInstanceMethod(objc_getClass("FigCaptureClientSessionMonitor"), @selector(_updateClientStateCondition:newValue:));
    Method replace = class_getInstanceMethod(objc_getClass("myclass"), @selector(replace_updateClientStateCondition:newValue:));
    method_exchangeImplementations(orignal, replace);
}
