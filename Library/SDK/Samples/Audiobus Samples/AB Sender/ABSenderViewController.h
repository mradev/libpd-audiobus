//
//  ABSenderViewController.h
//  Audiobus Samples
//
//  Created by Michael Tyson on 15/12/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ABAudiobusController;
@interface ABSenderViewController : UIViewController
- (id)init;
@property (nonatomic, retain) ABAudiobusController *audiobusController;
@end
