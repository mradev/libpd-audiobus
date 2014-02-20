//
//  ABReceiverViewController.m
//  Audiobus Samples
//
//  Created by Michael Tyson on 15/12/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import "ABReceiverViewController.h"
#import "TheAmazingAudioEngine.h"
#import "ABAppDelegate.h"
#import "TPOscilloscopeView.h"

@interface ABReceiverViewController () <ABAudioReceiver>
@property (nonatomic, retain) AEAudioController *audioController;
@property (nonatomic, retain) AEAudioFileWriter *writer;
@property (nonatomic, retain) AEAudioFilePlayer *player;
@property (nonatomic, retain) UIButton *playButton;
@property (nonatomic, retain) UIButton *recordButton;
@property (nonatomic, retain) TPOscilloscopeView *oscilloscopeView;
@property (nonatomic, readwrite) BOOL recording;
@property (nonatomic, readwrite) BOOL playing;
@end

@implementation ABReceiverViewController
@synthesize audioController = _audioController;
@synthesize writer = _writer;
@synthesize player = _player;
@synthesize playButton = _playButton;
@synthesize recordButton = _recordButton;
@synthesize oscilloscopeView = _oscilloscopeView;
@synthesize recording = _recording;
@synthesize playing = _playing;

- (id)init {
    if ( !(self = [super init]) ) return nil;
    ABAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    self.audioController = appDelegate.audioController;
    return self;
}

-(void)dealloc {
    self.audioController = nil;
    self.writer = nil;
    self.player = nil;
    self.playButton = nil;
    self.recordButton = nil;
    self.oscilloscopeView = nil;
    [super dealloc];
}

- (void)loadView {
    self.view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)] autorelease];
    self.view.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    UIImageView *image = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Speaker.png"]] autorelease];
    image.frame = CGRectMake(floor((self.view.bounds.size.width-image.frame.size.width)/2.0), 
                             floor((self.view.bounds.size.height-image.frame.size.height)/2.0), 
                             image.frame.size.width, 
                             image.frame.size.height);
    image.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:image];
    
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setBackgroundImage:[UIImage imageNamed:@"Button-Background.png"] forState:UIControlStateNormal];
    [button setBackgroundImage:[UIImage imageNamed:@"Button-Background-Selected.png"] forState:UIControlStateSelected];
    [button setBackgroundImage:[UIImage imageNamed:@"Button-Background-Selected.png"] forState:UIControlStateHighlighted];
    [button setImage:[UIImage imageNamed:@"Record.png"] forState:UIControlStateNormal];
    [button sizeToFit];
    button.frame = CGRectMake(20,
                              self.view.bounds.size.height - button.frame.size.height - 20,
                    
                              button.frame.size.width, button.frame.size.height);
    [button addTarget:self action:@selector(toggleRecord) forControlEvents:UIControlEventTouchUpInside];
    button.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:button];
    self.recordButton = button;
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setBackgroundImage:[UIImage imageNamed:@"Button-Background.png"] forState:UIControlStateNormal];
    [button setBackgroundImage:[UIImage imageNamed:@"Button-Background-Selected.png"] forState:UIControlStateSelected];
    [button setBackgroundImage:[UIImage imageNamed:@"Button-Background-Selected.png"] forState:UIControlStateHighlighted];
    [button setImage:[UIImage imageNamed:@"Play.png"] forState:UIControlStateNormal];
    [button sizeToFit];
    button.frame = CGRectMake(self.view.bounds.size.width - button.frame.size.width - 20,
                              self.view.bounds.size.height - button.frame.size.height - 20,
                              button.frame.size.width, button.frame.size.height);
    [button addTarget:self action:@selector(togglePlay) forControlEvents:UIControlEventTouchUpInside];
    button.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:button];
    self.playButton = button;
    
    self.oscilloscopeView = [[[TPOscilloscopeView alloc] init] autorelease];
    _oscilloscopeView.frame = CGRectMake(0, 0, self.view.bounds.size.width, 200);
    _oscilloscopeView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _oscilloscopeView.lineColor = [UIColor grayColor];
    [self.view addSubview:_oscilloscopeView];
    
    ABAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
    UIView *monitorView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 50)] autorelease];
    monitorView.backgroundColor = [UIColor clearColor];
    monitorView.frame = CGRectMake(round((self.view.bounds.size.width - monitorView.frame.size.width)/2.0),
                                     self.view.bounds.size.height - monitorView.frame.size.height - 50,
                                     monitorView.frame.size.width, monitorView.frame.size.height);
    monitorView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin;
    
    UISwitch *monitorSwitch = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
    UISlider *monitorVolume = [[[UISlider alloc] initWithFrame:CGRectMake(0, 0, 100, 50)] autorelease];
    
    monitorSwitch.frame = CGRectMake(0,
                                     round((monitorView.bounds.size.height - monitorSwitch.frame.size.height)/2.0),
                                     monitorSwitch.frame.size.width, monitorSwitch.frame.size.height);
    [monitorSwitch addTarget:self action:@selector(monitorSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    monitorSwitch.on = appDelegate.monitoring;
    [monitorView addSubview:monitorSwitch];
    
    monitorVolume.frame = CGRectMake(CGRectGetMaxX(monitorSwitch.frame) + 10,
                                     round((monitorView.bounds.size.height - monitorVolume.frame.size.height)/2.0),
                                     monitorView.bounds.size.width - (CGRectGetMaxX(monitorSwitch.frame) + 10),
                                     monitorVolume.frame.size.height);
    monitorVolume.maximumValue = 1.0;
    monitorVolume.minimumValue = 0.0;
    monitorVolume.value = appDelegate.monitorVolume;
    [monitorVolume addTarget:self action:@selector(monitorVolumeChanged:) forControlEvents:UIControlEventValueChanged];
    [monitorView addSubview:monitorVolume];
    
    [self.view addSubview:monitorView];
    
    UILabel *monitorLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    monitorLabel.text = @"Monitoring";
    monitorLabel.textColor = [UIColor grayColor];
    monitorLabel.shadowColor = [UIColor whiteColor];
    monitorLabel.shadowOffset = CGSizeMake(0, 1);
    [monitorLabel sizeToFit];
    monitorLabel.backgroundColor = [UIColor clearColor];
    monitorLabel.frame = CGRectMake(round((self.view.bounds.size.width - monitorLabel.frame.size.width)/2.0),
                                     self.view.bounds.size.height - monitorLabel.frame.size.height - 90,
                                     monitorLabel.frame.size.width, monitorLabel.frame.size.height);
    monitorLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:monitorLabel];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    ABAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
    [appDelegate addAudioReceiveTarget:self];
    [_oscilloscopeView start];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [_oscilloscopeView stop];
    
    ABAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
    [appDelegate removeAudioReceiveTarget:self];
}

- (void)monitorSwitchChanged:(UISwitch*)monitorSwitch {
    ABAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    appDelegate.monitoring = monitorSwitch.isOn;
}

- (void)monitorVolumeChanged:(UISlider*)slider {
    ABAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    appDelegate.monitorVolume = slider.value;
}

- (void)toggleRecord {
    if ( _writer ) {
        @synchronized ( self ) {
            [_writer finishWriting];
            self.writer = nil;
        }
        _recordButton.selected = NO;
        self.recording = NO;
    } else {
        @synchronized ( self ) {
            self.writer = [[[AEAudioFileWriter alloc] initWithAudioDescription:_audioController.audioDescription] autorelease];
            [_writer beginWritingToFileAtPath:[self recordingPath] fileType:kAudioFileAIFFType error:NULL];
        }
        _recordButton.selected = YES;
        _recordButton.selected = YES;
        self.recording = YES;
    }
}

- (void)receiveAudio:(AudioBufferList*)audio length:(UInt32)length timestamp:(AudioTimeStamp*)timestamp {
    [_oscilloscopeView addAudio:audio length:length];
    
    if ( _writer ) {
        @synchronized ( self ) {
            if ( _writer ) {
                AEAudioFileWriterAddAudio(_writer, audio, length);
            }
        }
    }
}

- (void)togglePlay {
    if ( _player ) {
        [_audioController removeChannels:[NSArray arrayWithObject:_player]];
        self.player = nil;
        _playButton.selected = NO;
        self.playing = NO;
    } else if ( !_writer ) {
        NSString *path = [self recordingPath];
        if ( [[NSFileManager defaultManager] fileExistsAtPath:path] ) {
            self.player = [AEAudioFilePlayer audioFilePlayerWithURL:[NSURL fileURLWithPath:path] audioController:_audioController error:NULL];
            _player.removeUponFinish = YES;
            _player.completionBlock = ^{
                self.player = nil;
                _playButton.selected = NO;
                self.playing = NO;
            };
            [_audioController addChannels:[NSArray arrayWithObject:_player]];
            _playButton.selected = YES;
            self.playing = YES;
        }
    }
}
         
- (NSString*)recordingPath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Recording.aiff"];
}

@end
