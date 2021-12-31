//
//  patch_InCallService.c
//  patch_InCallService
//
//  Created by 08tc3wbb on 11/19/21.
//  Copyright © 2021 08tc3wbb. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <sys/event.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <mach/mach.h>
#include <CoreFoundation/CoreFoundation.h>
#include <pthread/pthread.h>
#include <objc/runtime.h>
#import <Foundation/Foundation.h>

extern CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);
void notify_backboardd(){
    CFNotificationCenterRef distribute_center = CFNotificationCenterGetDistributedCenter();
    CFNotificationCenterPostNotification(distribute_center, CFSTR("com.ZecOps.backboardd_agent"), nil, nil, true);
}

@interface myclass : NSObject
-(void)replace_shutdownWithOptions:(id)arg1;
@end
@implementation myclass
-(void)replace_shutdownWithOptions:(id)arg1{
    notify_backboardd();
}
@end

__attribute__((constructor)) static void initialize(void){
    Method orignal = class_getInstanceMethod(objc_getClass("FBSSystemService"), @selector(shutdownWithOptions:));
    Method replace = class_getInstanceMethod(objc_getClass("myclass"), @selector(replace_shutdownWithOptions:));
    method_exchangeImplementations(orignal, replace);
}


