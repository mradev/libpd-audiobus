//
//  ABAppDelegate.h
//  AB Torture Test
//
//  Created by Michael Tyson on 25/11/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ABAppDelegate : UIResponder
@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, assign) CGFloat delayProbability;
@property (nonatomic, assign, readonly) BOOL testRunning;

- (void)test;
@end
