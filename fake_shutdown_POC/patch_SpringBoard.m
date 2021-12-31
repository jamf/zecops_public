//
//  patch_SpringBoard.m
//  patch_SpringBoard
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
#include <arpa/inet.h>
#include <libssh2.h>

void *ssh_connect(char *hostName, in_port_t port,char *user,char *passwd){
    
    LIBSSH2_SESSION *ssh_session = libssh2_session_init_ex(NULL,NULL,NULL,NULL);
    
    in_addr_t hostaddr = inet_addr(hostName);
    CFSocketRef _socket = CFSocketCreate(NULL,AF_INET, SOCK_STREAM, 0, 0, NULL, NULL);
    if (!_socket)
    {
        return NULL;
    }
    
    int yes=1;
    setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(int));
    
    struct sockaddr_in sin;
    
    sin.sin_family = AF_INET;
    sin.sin_port = htons(port);
    sin.sin_addr.s_addr = hostaddr;
    
    CFDataRef addressData = CFDataCreate(NULL, (UInt8 *)&sin, sizeof(struct sockaddr_in));
    CFSocketError socketError = CFSocketConnectToAddress(_socket, addressData, 60.0);
    CFRelease(addressData);
    
    if (socketError != kCFSocketSuccess)
    {
        return NULL;
    }
    
    if (libssh2_session_handshake(ssh_session, CFSocketGetNative(_socket)))
    {
        libssh2_session_free(ssh_session);
        return NULL;
    }
    
    int rc = libssh2_userauth_password(ssh_session, user, passwd);
    if (rc)
    {
        // authentication failed
        return NULL;
    }
    
    return ssh_session;
}

extern CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);
void my_callback(CFNotificationCenterRef center, void *observer, CFNotificationName name, const void *object, CFDictionaryRef userInfo){
    
    FILE *fp = fopen("/tmp/backboardd_camo", "a+");
    fclose(fp);
    
    exit(1);
}

__attribute__((constructor)) static void initialize(void){
    
    if(!access("/tmp/rebooot_userspace", F_OK)){
        
        void *ssh_session = ssh_connect("127.0.0.1", 22, "root", "alpine");
        if(ssh_session){
            LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(ssh_session);
            libssh2_channel_exec(channel, "/bin/rm /tmp/rebooot_userspace && /bin/rm /tmp/backboardd_camo && /bin/launchctl reboot userspace");
            libssh2_channel_free(channel);
        }
        unlink("/tmp/rebooot_userspace");
        unlink("/tmp/backboardd_camo");
    }
    
    if(!access("/tmp/backboardd_camo", F_OK)){
        exit(0);
    }
    
    CFNotificationCenterRef distribute_center = CFNotificationCenterGetDistributedCenter();
    CFNotificationSuspensionBehavior const suspensionBehavior = CFNotificationSuspensionBehaviorDeliverImmediately;
    CFNotificationCenterAddObserver(distribute_center, nil, my_callback, CFSTR("com.ZecOps.backboardd_agent"), NULL, suspensionBehavior);
}
