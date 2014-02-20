//
//  ABMultitrackOscilloscopeViewController.h
//  Audiobus Samples
//
//  Created by Michael Tyson on 15/12/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import "ABMultitrackOscilloscopeViewController.h"
#import "TheAmazingAudioEngine.h"
#import "ABAppDelegate.h"
#import "TPOscilloscopeView.h"
#import "Audiobus.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

static const int kIconTag = 5888;
static const int kOscilloscopeTag = 5889;

static const CGFloat kTrackHeight = 200;
static const CGFloat kTrackIconPadding = 50;
static const CGFloat kTrackMargin = 10;

@interface ABMultitrackOscilloscopeViewController () <ABAudioReceiver> {
    BOOL _freeze;
}
@property (nonatomic, retain) NSMutableDictionary *trackViews;
@property (nonatomic, retain) UIImageView *watermark;
@end

@interface ABMultitrackOscilloscopeHoldRecognizer : UIGestureRecognizer
@end

@implementation ABMultitrackOscilloscopeViewController
@synthesize inputPort = _inputPort;
@synthesize trackViews = _trackViews;
@synthesize watermark = _watermark;

- (id)init {
    if ( !(self = [super init]) ) return nil;
    
    self.trackViews = [NSMutableDictionary dictionary];
    
    // Watch for connection changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionsChanged:)
                                                 name:ABConnectionsChangedNotification
                                               object:nil];

    
    return self;
}

-(void)dealloc {
    self.trackViews = nil;
    self.watermark = nil;
    self.inputPort = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ABConnectionsChangedNotification object:nil];
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
    
    UIGestureRecognizer *holdRecognizer = [[[ABMultitrackOscilloscopeHoldRecognizer alloc] initWithTarget:self action:@selector(hold:)] autorelease];
    [self.view addGestureRecognizer:holdRecognizer];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    ABAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate addAudioReceiveTarget:self];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[_trackViews allValues] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.trackViews = nil;
    
    ABAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate removeAudioReceiveTarget:self];
}

- (void)hold:(UIGestureRecognizer*)recogniser {
    _freeze = recogniser.state == UIGestureRecognizerStateBegan;
    if ( recogniser.state == UIGestureRecognizerStateEnded ) {
        @synchronized ( _trackViews ) {
            for ( UIView *view in [_trackViews allValues] ) {
                TPOscilloscopeView *oscilloscope = (TPOscilloscopeView*)[view viewWithTag:kOscilloscopeTag];
                oscilloscope.freeze = NO;
            }
        }
    }
}

- (void)inputFromPort:(ABPort*)port audio:(AudioBufferList*)audio length:(UInt32)length timestamp:(AudioTimeStamp*)timestamp {
    NSValue *portKey = [NSValue valueWithPointer:port];
    @synchronized ( _trackViews ) { // Ensure mutually exclusive access to the mapping dictionary
        UIView *view = [_trackViews objectForKey:portKey];
        if ( !view ) return;
        
        TPOscilloscopeView *oscilloscope = (TPOscilloscopeView*)[view viewWithTag:kOscilloscopeTag];
        
        [oscilloscope addAudio:audio length:length];
    }
}

-(void)reachedEndOfAudioBlock {
    if ( _freeze ) {
        _freeze = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            @synchronized ( _trackViews ) {
                for ( UIView *view in [_trackViews allValues] ) {
                    TPOscilloscopeView *oscilloscope = (TPOscilloscopeView*)[view viewWithTag:kOscilloscopeTag];
                    oscilloscope.freeze = YES;
                }
            }
        });
    }
}

// Monitor connections, and add or remove trackViews as necessary
- (void)connectionsChanged:(NSNotification*)notification {
    _watermark.hidden = [_inputPort.sources count] > 0;
    
    for ( ABPort *port in _inputPort.sources ) {
        NSValue *portKey = [NSValue valueWithPointer:port];
        if ( ![_trackViews objectForKey:portKey] ) {
            // This is a new source connection. Create a view for this source.
            UIView *view = [[[UIView alloc] initWithFrame:CGRectInset(CGRectMake(0, 0, self.view.bounds.size.width, kTrackHeight), kTrackMargin, kTrackMargin)] autorelease];
            view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            view.backgroundColor = [UIColor colorWithWhite:0.685 alpha:1.000];
            view.layer.cornerRadius = 10.0;
            view.layer.shadowColor = [[UIColor whiteColor] CGColor];
            view.layer.shadowOpacity = 0.8;
            view.layer.shadowOffset = CGSizeMake(0, 1);
            view.layer.shadowRadius = 1.0;
            
            TPOscilloscopeView *oscilloscope = [[[TPOscilloscopeView alloc] initWithFrame:CGRectMake(kTrackHeight, 0, view.bounds.size.width-kTrackHeight, view.bounds.size.height)] autorelease];
            oscilloscope.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
            oscilloscope.tag = kOscilloscopeTag;
            [view addSubview:oscilloscope];
            UIImageView *iconView = [[[UIImageView alloc] initWithImage:port.peer.icon] autorelease];
            iconView.frame = CGRectMake(kTrackIconPadding,
                                        kTrackIconPadding,
                                        kTrackHeight-(2*kTrackMargin)-(2*kTrackIconPadding),
                                        kTrackHeight-(2*kTrackMargin)-(2*kTrackIconPadding));
            iconView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
            iconView.tag = kIconTag;
            iconView.layer.cornerRadius = iconView.frame.size.width * (10.0/57.0);
            iconView.layer.masksToBounds = YES;
            [view addSubview:iconView];
            
            [self.view addSubview:view];
            [oscilloscope start];
            
            @synchronized ( _trackViews ) { // Ensure mutually exclusive access to the mapping dictionary
                [_trackViews setObject:view forKey:portKey];
            }
        }
    }
    
    // Find old sources no longer connected
    for ( NSValue *portKey in [_trackViews allKeys] ) {
        ABPort *port = (ABPort*)[portKey pointerValue];
        if ( ![_inputPort.sources containsObject:port] ) {
            // This port is no longer connected
            UIView *view = [_trackViews objectForKey:portKey];
            [view removeFromSuperview];
            @synchronized ( _trackViews ) { // Ensure mutually exclusive access to the mapping dictionary
                [_trackViews removeObjectForKey:portKey];
            }
        }
    }
    
    [self layout];
}

- (void)layout {
    // Layout
    CGFloat origin = 0;
    for ( UIView *view in [_trackViews allValues] ) {
        view.frame = CGRectInset(CGRectMake(0, origin, self.view.bounds.size.width, kTrackHeight), kTrackMargin, kTrackMargin);
        origin += kTrackHeight;
    }
}

@end

@implementation ABMultitrackOscilloscopeHoldRecognizer

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    self.state = UIGestureRecognizerStateBegan;
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    self.state = UIGestureRecognizerStateEnded;
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    self.state = UIGestureRecognizerStateEnded;
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
}

@end
