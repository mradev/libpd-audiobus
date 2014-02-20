//
//  ABAppDelegate.m
//  AB Receiver
//
//  Created by Michael Tyson on 25/11/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import "ABAppDelegate.h"
#import "ABMultitrackOscilloscopeViewController.h"
#import "Audiobus.h"
#import <mach/mach_time.h>

static double __hostTimeToSeconds = 0.0;

@interface ABAppDelegate () <AEAudioPlayable>
@property (nonatomic, retain) ABMultitrackOscilloscopeViewController *viewController;
@property (nonatomic, retain) ABAudiobusController *audiobusController;
@property (nonatomic, retain) ABInputPort *input;
@property (nonatomic, retain) NSMutableArray *receiveTargets;
@property (nonatomic, retain) ABLiveBuffer *liveBuffer;
@end

@implementation ABAppDelegate
@synthesize window = _window;
@synthesize audiobusController = _audiobusController;
@synthesize viewController = _viewController;
@synthesize audioController = _audioController;
@synthesize input = _input;
@synthesize receiveTargets = _receiveTargets;
@synthesize liveBuffer = _liveBuffer;

+(void)initialize {
    mach_timebase_info_data_t tinfo;
    mach_timebase_info(&tinfo);
    __hostTimeToSeconds = ((double)tinfo.numer / tinfo.denom) * 1.0e-9;
}

- (void)dealloc {
    self.window = nil;
    self.viewController = nil;
    self.audiobusController = nil;
    self.audioController = nil;
    self.input = nil;
    self.receiveTargets = nil;
    self.liveBuffer = nil;
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    
    self.receiveTargets = [NSMutableArray array];
    
    // Create an audio controller instance
    // Please note: THIS IS AN EXAMPLE ONLY. The audio engine used here is NOT TO BE USED IN YOUR OWN IMPLEMENTATION. See theamazingaudioengine.com for details on this library.
    self.audioController = [[[AEAudioController alloc] initWithAudioDescription:[AEAudioController nonInterleaved16BitStereoAudioDescription]] autorelease];
    _audioController.preferredBufferDuration = 0.005;
    
    // Create an Audiobus instance
    self.audiobusController = [[[ABAudiobusController alloc] initWithAppLaunchURL:[NSURL URLWithString:@"abmultitrackoscilloscope.audiobus://"]
                                                                           apiKey:@"MCoqKkFCIE11bHRpdHJhY2sgT3NjaWxsb3Njb3BlKioqYWJtdWx0aXRyYWNrb3NjaWxsb3Njb3BlLmF1ZGlvYnVzOi8v:T4txx2/pYVWpLtHvW8CDf/bAa+FCXc6xxWwlYIia6U7nWu8Gor9B9wzw6ZX/GM4Ew+fBGHf5kgQOnI+6Gaqov80QNe0P0wx4MTVYRSxJ/ErAKGUb/JNj79n16BPf5kKR"] autorelease];
    _audiobusController.connectionPanelPosition = ABAudiobusConnectionPanelPositionBottom;
    
    // Create our own live buffer, which we'll use for live monitoring. This is optional - you can still use
    // ABInputPortReceiveLive to receive live audio straight from Audiobus, but if you wish to manipulate the audio
    // and provide live monitoring of the manipulated audio, the live buffer provides for this functionality.
    self.liveBuffer = [[[ABLiveBuffer alloc] initWithClientFormat:_audioController.audioDescription] autorelease];
    
    // Create an input port, to receive audio
    self.input = [_audiobusController addInputPortNamed:@"Main" title:@"Main Input"];
    
    // Configure the input port (receive audio as separate streams)
    _input.receiveMixedAudio = NO;
    _input.clientFormat = _audioController.audioDescription;
    
    // Indicate to the other side that we play the incoming audio live (they should mute their audio)
    _input.attributes = ABInputPortAttributePlaysLiveAudio;
    
    // Provide the input block, for receiving audio
    _input.audioInputBlock = ^(ABInputPort *inputPort, UInt32 lengthInFrames, AudioTimeStamp *nextTimestamp, ABPort *sourcePort) {
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
        ABInputPortReceive(inputPort, sourcePort, bufferList, &lengthInFrames, NULL, NULL);
        
        // Pass audio to receive targets
        for ( id<ABAudioReceiver> target in _receiveTargets ) {
            [target inputFromPort:sourcePort audio:bufferList length:lengthInFrames timestamp:nextTimestamp];
        }
        
        // Enqueue on live buffer (as above, this is optional, but useful if you're manipulating the
        // audio and want to offer live monitoring of the manipulated audio)
        ABLiveBufferEnqueue(_liveBuffer, sourcePort, bufferList, lengthInFrames, nextTimestamp);
    };
    
    _input.endOfAudioTimeIntervalBlock = ^(AudioTimeStamp *timeStamp) {
        // Inform receive targets that we've finished a block
        for ( id<ABAudioReceiver> target in _receiveTargets ) {
            [target reachedEndOfAudioBlock];
        }
    };
    
    self.viewController = [[[ABMultitrackOscilloscopeViewController alloc] init] autorelease];
    _viewController.inputPort = _input;
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    // Add ourselves as a channel to the audio controller, for live playback
    [_audioController addChannels:[NSArray arrayWithObject:self]];
    [_audioController start:NULL];

    return YES;
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

static OSStatus renderCallback(id                        channel,
                               AEAudioController        *audioController,
                               const AudioTimeStamp     *time,
                               UInt32                    frames,
                               AudioBufferList          *audio) {

    ABAppDelegate *THIS = (ABAppDelegate*)channel;
    
    if ( !THIS->_input ) return noErr;
    
    // Pull audio from our live buffer. We could also use the normal Audiobus live buffer,
    // ABInputPortReceiveLive, if we weren't interested in buffering audio manually.
    ABLiveBufferDequeue(THIS->_liveBuffer, audio, frames, NULL);
    
    return noErr;
}

-(AEAudioControllerRenderCallback)renderCallback {
    return renderCallback;
}

@end
