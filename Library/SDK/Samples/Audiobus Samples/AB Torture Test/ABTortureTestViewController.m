//
//  ABTortureTestViewController.m
//  Audiobus Samples
//
//  Created by Michael Tyson on 15/12/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import "ABTortureTestViewController.h"
#import "Audiobus.h"
#import "ABAppDelegate.h"

static int kDelayProbabilityChangedNotification;
static int kTestRunningChangedNotification;

@interface ABTortureTestViewController () {
    float _preTestValue;
    float _currentTestValue;
}
@property (nonatomic, retain) UISlider *slider;
@property (nonatomic, retain) UIButton *testButton;
@end

@implementation ABTortureTestViewController

- (id)init {
    if ( !(self = [super init]) ) return nil;
    return self;
}

-(void)setAppDelegate:(ABAppDelegate *)appDelegate {
    if ( _appDelegate ) {
        [_appDelegate removeObserver:self forKeyPath:@"delayProbability"];
        [_appDelegate removeObserver:self forKeyPath:@"testRunning"];
    }
    
    _appDelegate = appDelegate;
    
    if ( _appDelegate ) {
        [_appDelegate addObserver:self forKeyPath:@"delayProbability" options:0 context:&kDelayProbabilityChangedNotification];
        [_appDelegate addObserver:self forKeyPath:@"testRunning" options:0 context:&kTestRunningChangedNotification];
    }
}

-(void)dealloc {
    self.appDelegate = nil;
    self.slider = nil;
    self.testButton = nil;
    [super dealloc];
}

- (void)loadView {
    self.view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)] autorelease];
    self.view.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    UIImageView *image = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Comfy-Chair.png"]] autorelease];
    image.frame = CGRectMake(floor((self.view.bounds.size.width-image.frame.size.width)/2.0), 
                             floor((self.view.bounds.size.height-image.frame.size.height)/2.0), 
                             image.frame.size.width, 
                             image.frame.size.height);
    image.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:image];
    
    self.testButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_testButton setTitle:@"Start Test" forState:UIControlStateNormal];
    [_testButton sizeToFit];
    _testButton.frame = CGRectMake(floor((self.view.bounds.size.width-_testButton.frame.size.width)/2.0),
                                  self.view.bounds.size.height-_testButton.frame.size.height-200,
                                  _testButton.frame.size.width,
                                  _testButton.frame.size.height);
    _testButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin;
    [_testButton addTarget:self action:@selector(test) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_testButton];
    
    self.slider = [[[UISlider alloc] initWithFrame:CGRectMake(0, 0, 200, 50)] autorelease];
    _slider.frame = CGRectMake(floor((self.view.bounds.size.width-_slider.frame.size.width)/2.0),
                              self.view.bounds.size.height-_slider.frame.size.height-100,
                              _slider.frame.size.width,
                              _slider.frame.size.height);
    _slider.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin;
    _slider.minimumValue = 0;
    _slider.maximumValue = 0.95;
    _slider.value = _appDelegate.delayProbability;
    [_slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_slider];
}

- (void)sliderChanged:(UISlider*)slider {
    _appDelegate.delayProbability = slider.value;
}

- (void)test {
    [_appDelegate test];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ( context == &kDelayProbabilityChangedNotification ) {
        _slider.value = _appDelegate.delayProbability;
    } else if ( context == &kTestRunningChangedNotification ) {
        _testButton.enabled = !_appDelegate.testRunning;
    }
}

@end
