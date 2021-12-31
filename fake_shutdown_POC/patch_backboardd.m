//
//  patch_backboardd.m
//  patch_backboardd
//
//  Created by 08tc3wbb on 11/21/21.
//  Copyright © 2021 08tc3wbb. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <sys/event.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <mach/mach.h>
#include <spawn.h>
#include <CoreFoundation/CoreFoundation.h>
#include <pthread/pthread.h>
#include <objc/runtime.h>
#import <Foundation/Foundation.h>

extern void* objc_msgSend(id self, SEL op, ...);

@interface BKSDefaults : NSObject
-(int)hideAppleLogoOnLaunch;
-(void)setHideAppleLogoOnLaunch:(int)arg1;
@end

void backboardd_hides_spinningWheel(){
    BKSDefaults *bks = objc_msgSend(objc_getClass("BKSDefaults"), @selector(localDefaults));
    [bks setHideAppleLogoOnLaunch:1];
}

int startMonitoring_powerOn = 0;
extern CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);
void my_callback(CFNotificationCenterRef center, void *observer, CFNotificationName name, const void *object, CFDictionaryRef userInfo){
    backboardd_hides_spinningWheel();
    startMonitoring_powerOn = 1;
}

@interface myclass : NSObject
-(void)replace_setObject:(id)object forSenderID:(uint64_t)forSenderID page:(uint16_t)page usage:(uint16_t)usage;
@end
@implementation myclass

void (*orig_setObject)(id self, SEL selector, id object, uint64_t senderID, uint16_t page, uint16_t usage) = NULL;
-(void)replace_setObject:(id)object forSenderID:(uint64_t)senderID page:(uint16_t)page usage:(uint16_t)usage{

    orig_setObject(self, @selector(setObject:ForSenderID:page:usage:), object, senderID, page, usage);
    
    if(startMonitoring_powerOn == 0)
        return;
    
    if(usage == 0x30){ // Side button: 0x30
        if(object){
            FILE *fp = fopen("/tmp/rebooot_userspace", "a+");
            fclose(fp);
        }
    }
}

@end

__attribute__((constructor)) static void initialize(void){
    
    BKSDefaults *bks = objc_msgSend(objc_getClass("BKSDefaults"), @selector(localDefaults));
    [bks setHideAppleLogoOnLaunch:0];
    
    Method orignal = class_getInstanceMethod(objc_getClass("BKEventSenderUsagePairDictionary"), @selector(setObject:forSenderID:page:usage:));
    orig_setObject = (void(*))method_getImplementation(orignal);
    Method replace = class_getInstanceMethod(objc_getClass("myclass"), @selector(replace_setObject:forSenderID:page:usage:));
    method_exchangeImplementations(orignal, replace);
    
    CFNotificationCenterRef distribute_center = CFNotificationCenterGetDistributedCenter();
    CFNotificationSuspensionBehavior const suspensionBehavior = CFNotificationSuspensionBehaviorDeliverImmediately;
    CFNotificationCenterAddObserver(distribute_center, nil, my_callback, CFSTR("com.ZecOps.backboardd_agent"), NULL, suspensionBehavior);
}
