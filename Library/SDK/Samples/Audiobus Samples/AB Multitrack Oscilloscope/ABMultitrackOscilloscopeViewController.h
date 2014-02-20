//
//  ABMultitrackOscilloscopeViewController.h
//  Audiobus Samples
//
//  Created by Michael Tyson on 15/12/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ABInputPort;

@interface ABMultitrackOscilloscopeViewController : UIViewController
- (id)init;

@property (nonatomic, retain) ABInputPort *inputPort;
@end
