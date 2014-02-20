//
//  ABFilterViewController.m
//  Audiobus Samples
//
//  Created by Michael Tyson on 31/12/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import "ABFilterViewController.h"

@implementation ABFilterViewController
@synthesize audiobusController=_audiobusController;

- (id)init {
    if ( !(self = [super init]) ) return nil;
    return self;
}

- (void)dealloc {
    self.audiobusController = nil;
    [super dealloc];
}

#pragma mark - View lifecycle

- (void)loadView {
    self.view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)] autorelease];
    self.view.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    UIImageView *image = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Echo.png"]] autorelease];
    image.frame = CGRectMake(floor((self.view.bounds.size.width-image.frame.size.width)/2.0), 
                             floor((self.view.bounds.size.height-image.frame.size.height)/2.0), 
                             image.frame.size.width, 
                             image.frame.size.height);
    image.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:image];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

@end
