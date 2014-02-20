//
//  ABReceiverViewController.h
//  Audiobus Samples
//
//  Created by Michael Tyson on 15/12/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ABReceiverViewController : UIViewController
- (id)init;

- (void)toggleRecord;
- (void)togglePlay;

@property (nonatomic, readonly) BOOL recording;
@property (nonatomic, readonly) BOOL playing;
@end
