//
//  ABAppDelegate.m
//  AB Receiver
//
//  Created by Michael Tyson on 25/11/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import "ABAppDelegate.h"
#import "ABReceiverViewController.h"
#import "Audiobus.h"
#import <mach/mach_time.h>

static double __hostTimeToSeconds = 0.0;

@interface ABAppDelegate ()
@property (nonatomic, retain) ABReceiverViewController *viewController;
@property (nonatomic, retain) ABAudiobusController *audiobusController;
@property (nonatomic, retain) ABInputPort *input;
@property (nonatomic, retain) ABTrigger *playTrigger;
@property (nonatomic, retain) ABTrigger *recordTrigger;
@property (nonatomic, retain) NSMutableArray *receiveTargets;
@property (nonatomic, retain) AEBlockChannel *channel;
@end

@implementation ABAppDelegate
@synthesize window = _window;
@synthesize audiobusController = _audiobusController;
@synthesize viewController = _viewController;
@synthesize audioController = _audioController;
@synthesize input = _input;
@synthesize receiveTargets = _receiveTargets;
@synthesize channel = _channel;
@synthesize playTrigger = _playTrigger;
@synthesize recordTrigger = _recordTrigger;
@synthesize monitoring = _monitoring;

+(void)initialize {
    mach_timebase_info_data_t tinfo;
    mach_timebase_info(&tinfo);
    __hostTimeToSeconds = ((double)tinfo.numer / tinfo.denom) * 1.0e-9;
}

- (void)dealloc {
    [_viewController removeObserver:self forKeyPath:@"playing"];
    [_viewController removeObserver:self forKeyPath:@"recording"];
    self.window = nil;
    self.viewController = nil;
    self.audiobusController = nil;
    self.audioController = nil;
    self.input = nil;
    self.playTrigger = nil;
    self.recordTrigger = nil;
    self.receiveTargets = nil;
    self.channel = nil;
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    
    self.receiveTargets = [NSMutableArray array];
    
    // Create an audio controller instance.
    // Please note: THIS IS AN EXAMPLE ONLY. The audio engine used here is NOT TO BE USED IN YOUR OWN IMPLEMENTATION. See theamazingaudioengine.com for details on this library.
    self.audioController = [[[AEAudioController alloc] initWithAudioDescription:[AEAudioController nonInterleaved16BitStereoAudioDescription]] autorelease];
    _audioController.preferredBufferDuration = 0.005;
    
    // Create an Audiobus instance
    self.audiobusController = [[[ABAudiobusController alloc] initWithAppLaunchURL:[NSURL URLWithString:@"abreceiver.audiobus://"]
                                                                           apiKey:@"MCoqKkFCIFJlY2VpdmVyKioqYWJyZWNlaXZlci5hdWRpb2J1czovLw==:vLW+ClhJP28hxRD5RDb53YON5tCAorCi74MtXFXHYZjM/5Klx9KkhW3pTPwYJqy/IzHT8cHfowXoL11D+WC5J7t9eSJowH7jOdwDFSKjpw7HaAC79zgX9TK8raG2yvT2"] autorelease];
    
    // Create an input port, to receive audio
    self.input = [_audiobusController addInputPortNamed:@"Main" title:@"Main Input"];
    
    // Configure the input port
    _input.receiveMixedAudio = YES;
    _input.clientFormat = _audioController.audioDescription;
    
    // Provide the input block, for receiving audio
    _input.audioInputBlock = ^(ABInputPort *inputPort, UInt32 lengthInFrames, AudioTimeStamp *nextTimestamp, ABPort *sourcePortOrNil) {
        // Prepare an audio buffer list
        char audioBufferListSpace[sizeof(AudioBufferList) + sizeof(AudioBuffer)];
        AudioBufferList *bufferList = (AudioBufferList*)&audioBufferListSpace;
        bufferList->mNumberBuffers = 2;
        for ( int i=0; i<bufferList->mNumberBuffers; i++ ) {
            bufferList->mBuffers[i].mNumberChannels = 1;
            bufferList->mBuffers[i].mDataByteSize = 0;
            bufferList->mBuffers[i].mData = 0;
        }
        
        // Receive audio
        ABInputPortReceive(inputPort, sourcePortOrNil, bufferList, &lengthInFrames, nextTimestamp, NULL);
        
        // Pass audio to receive targets
        for ( id<ABAudioReceiver> target in _receiveTargets ) {
            [target receiveAudio:bufferList length:lengthInFrames timestamp:nextTimestamp];
        }
    };
    
    // Add triggers for play and record
    self.recordTrigger = [ABTrigger triggerWithSystemType:ABTriggerTypeRecordToggle
                                                    block:^(ABTrigger *trigger, NSSet *ports) { [_viewController toggleRecord]; }];
    self.playTrigger = [ABTrigger triggerWithSystemType:ABTriggerTypePlayToggle
                                                  block:^(ABTrigger *trigger, NSSet *ports) { [_viewController togglePlay]; }];
    [_audiobusController addTrigger:_recordTrigger];
    [_audiobusController addTrigger:_playTrigger];
    
    // Add a channel to the audio controller, for playback
    self.channel = [AEBlockChannel channelWithBlock:^(const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio) {
        // Pull live audio from the port
        ABInputPortReceiveLive(_input, audio, frames, NULL);
    }];
    _channel.volume = 0.3;
    [_audioController addChannels:[NSArray arrayWithObject:_channel]];
    self.monitoring = YES;
    
    [_audioController start:NULL];
    
    
    self.viewController = [[[ABReceiverViewController alloc] init] autorelease];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    [_viewController addObserver:self forKeyPath:@"playing" options:0 context:NULL];
    [_viewController addObserver:self forKeyPath:@"recording" options:0 context:NULL];
    
    return YES;
}

-(void)setMonitoring:(BOOL)monitoring {
    _monitoring = monitoring;
    _channel.channelIsPlaying = monitoring;
    
    // Indicate to the other side that we play the incoming audio live if monitoring is on (they should mute their audio)
    _input.attributes = _monitoring ? ABInputPortAttributePlaysLiveAudio : 0;
}

-(float)monitorVolume {
    return _channel.volume;
}

-(void)setMonitorVolume:(float)monitorVolume {
    _channel.volume = monitorVolume;
}

-(void)applicationDidEnterBackground:(UIApplication *)application {
    if ( !_audiobusController.connected ) {
        // Stop the audio engine, suspending the app, if we're not connected
        // [_audioController stop]; -- Commented out to keep the app running during development
    }
}

-(void)applicationWillEnterForeground:(UIApplication *)application {
    if ( !_audioController.running ) {
        [_audioController start:NULL];
    }
}

- (void)addAudioReceiveTarget:(id<ABAudioReceiver>)target {
    [_receiveTargets addObject:target];
}

- (void)removeAudioReceiveTarget:(id<ABAudioReceiver>)target {
    [_receiveTargets removeObject:target];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ( [keyPath isEqualToString:@"playing"] ) {
        _playTrigger.state = _viewController.playing ? ABTriggerStateSelected : ABTriggerStateNormal;
    } else if ( [keyPath isEqualToString:@"recording"] ) {
        _recordTrigger.state = _viewController.recording ? ABTriggerStateSelected : ABTriggerStateNormal;
    }
}

@end
