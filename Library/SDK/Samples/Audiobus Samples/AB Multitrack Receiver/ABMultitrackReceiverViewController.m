//
//  ABMultitrackReceiverViewController.m
//  Audiobus Samples
//
//  Created by Michael Tyson on 15/12/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import "ABMultitrackReceiverViewController.h"
#import "ABAppDelegate.h"

@interface ABMultitrackReceiverViewController ()
@property (nonatomic, retain) UIImageView *watermark;
@end

@implementation ABMultitrackReceiverViewController
@synthesize watermark = _watermark;

- (id)init {
    if ( !(self = [super init]) ) return nil;
    return self;
}

-(void)dealloc {
    self.watermark = nil;
    [super dealloc];
}

- (void)loadView {
    self.view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)] autorelease];
    self.view.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    self.watermark = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Multitrack.png"]] autorelease];
    _watermark.frame = CGRectMake(floor((self.view.bounds.size.width-_watermark.frame.size.width)/2.0),
                                  floor((self.view.bounds.size.height-_watermark.frame.size.height)/2.0),
                                  _watermark.frame.size.width,
                                  _watermark.frame.size.height);
    _watermark.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:_watermark];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

@end
