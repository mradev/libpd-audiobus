//
//  AppDelegate.h
//  AudioBuslibpd
//
//  Created by paul adams on 19/02/2014.
//  Copyright (c) 2014 mra. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (readonly, nonatomic)NSInteger ticks;
@property (strong,nonatomic)ViewController *rootController;

@end
