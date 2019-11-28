//
//  ViewController.m
//  ZecOps_PAC_subm
//
//  Created by bb on 11/13/19.
//  Copyright © 2019 bb. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    printf("--- PAC Edition ---\n");
    printf("Ready to pwn!\n");
    printf("  Just click anywhere on the iOS device screen.\n");
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    printf("\nPwnage started...\n");
    
    extern void exp_start(void);
    exp_start();
}

@end
