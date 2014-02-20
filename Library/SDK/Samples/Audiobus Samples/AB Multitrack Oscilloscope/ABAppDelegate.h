//
//  ABAppDelegate.h
//  AB Receiver
//
//  Created by Michael Tyson on 25/11/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TheAmazingAudioEngine.h"
#import <AudioToolbox/AudioToolbox.h>

@protocol ABAudioReceiver;

@interface ABAppDelegate : UIResponder <UIApplicationDelegate>
- (void)addAudioReceiveTarget:(id<ABAudioReceiver>)target;
- (void)removeAudioReceiveTarget:(id<ABAudioReceiver>)target;
@property (nonatomic, retain) UIWindow *window;
@property (strong, nonatomic) AEAudioController *audioController;
@end

@class ABPort;

@protocol ABAudioReceiver <NSObject>
- (void)inputFromPort:(ABPort*)port audio:(AudioBufferList*)audio length:(UInt32)length timestamp:(AudioTimeStamp*)timestamp;
- (void)reachedEndOfAudioBlock;
@end