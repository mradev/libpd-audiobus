//
//  ABAppDelegate.m
//  AB Filter
//
//  Created by Michael Tyson on 26/11/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import "ABAppDelegate.h"
#import "ABFilterViewController.h"
#import "ABLogFilter.h"
#import "TheAmazingAudioEngine.h"
#import "Audiobus.h"
#import <Accelerate/Accelerate.h>

@interface ABAppDelegate ()  <UIApplicationDelegate, AEAudioPlayable>
@property (strong, nonatomic) ABFilterViewController *viewController;
@property (strong, nonatomic) AEAudioController *audioController;
@property (strong, nonatomic) ABAudiobusController *audiobusController;
@property (strong, nonatomic) ABAudiobusAudioUnitWrapper *audioUnitWrapper;
@property (strong, nonatomic) ABFilterPort *logFilterPort;
@property (strong, nonatomic) ABFilterPort *bitCrusherFilterPort;
@property (strong, nonatomic) ABLogFilter *logFilter;
@property (strong, nonatomic) ABTrigger *lfoTrigger;
@end

@implementation ABAppDelegate
@synthesize window = _window;
@synthesize viewController = _viewController;
@synthesize audioController = _audioController;
@synthesize audiobusController = _audiobusController;
@synthesize audioUnitWrapper = _audioUnitWrapper;
@synthesize logFilterPort = _logFilterPort;
@synthesize bitCrusherFilterPort = _bitCrusherFilterPort;
@synthesize logFilter = _logFilter;
@synthesize lfoTrigger = _lfoTrigger;

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ABConnectionsChangedNotification object:nil];
    [_window release];
    self.viewController = nil;
    self.audioController = nil;
    self.audiobusController = nil;
    self.audioUnitWrapper = nil;
    self.logFilterPort = nil;
    self.bitCrusherFilterPort = nil;
    self.logFilter = nil;
    self.lfoTrigger = nil;
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    
    // Create an instance of AEAudioController, the audio engine, with input enabled
    // Please note: THIS IS AN EXAMPLE ONLY. The audio engine used here is NOT TO BE USED IN YOUR OWN IMPLEMENTATION. See theamazingaudioengine.com for details on this library.
    self.audioController = [[[AEAudioController alloc] initWithAudioDescription:[AEAudioController nonInterleaved16BitStereoAudioDescription]] autorelease];
    _audioController.preferredBufferDuration = 0.005;
    
    // Create an Audiobus instance
    self.audiobusController = [[[ABAudiobusController alloc] initWithAppLaunchURL:[NSURL URLWithString:@"abfilter.audiobus://"]
                                                                           apiKey:@"MCoqKkFCIEZpbHRlcioqKmFiZmlsdGVyLmF1ZGlvYnVzOi8v:r+RV3VjFuyHUH8D5CosrlUevRw3M/dCmPwN8KQuITvl7aIgKHN1qI75rHVupoT45X7DFzpik+gnOS4YkCjmiKc9GnB4TGZjR4FTKKAWi+75kxYbCmEy03vED24E5mCNg"] autorelease];
    
    // Create an Audio Unit Wrapper instance
    self.audioUnitWrapper = [[[ABAudiobusAudioUnitWrapper alloc] initWithAudiobusController:_audiobusController
                                                                                  audioUnit:_audioController.audioUnit
                                                                                     output:nil
                                                                                      input:nil] autorelease];
    
    // Create the first filter port, passing the filter implementation
    self.logFilter = [[[ABLogFilter alloc] init] autorelease];
    self.logFilterPort = [_audiobusController addFilterPortNamed:@"Log"
                                                           title:NSLocalizedString(@"Log Filter", @"")
                                                    processBlock:^(AudioBufferList* audio, UInt32 frames, AudioTimeStamp *timestamp) {
        [_logFilter filterAudio:audio length:frames];
    }];
    
    // Give the port an icon
    _logFilterPort.icon = [UIImage imageNamed:@"Frequency-Trigger-Fast.png"];
    
    // Tell the filter what our audio format is
    _logFilterPort.clientFormat = [AEAudioController nonInterleavedFloatStereoAudioDescription];
    
    // Create the second filter port, passing the filter implementation
    self.bitCrusherFilterPort = [_audiobusController addFilterPortNamed:@"Bitcrusher"
                                                                  title:NSLocalizedString(@"Bitcrusher Filter", @"")
                                                           processBlock:^(AudioBufferList* audio, UInt32 frames, AudioTimeStamp *timestamp) {
                                                               float multiplier = MAXFLOAT / 50;
                                                               for ( int i=0; i<audio->mNumberBuffers; i++ ) {
                                                                   vDSP_vsdiv((float*)audio->mBuffers[i].mData, 1, &multiplier, (float*)audio->mBuffers[i].mData, 1, frames);
                                                                   vDSP_vsmul((float*)audio->mBuffers[i].mData, 1, &multiplier, (float*)audio->mBuffers[i].mData, 1, frames);
                                                               }
                                                           }];
    
    // Tell the filter what our audio format is
    _bitCrusherFilterPort.clientFormat = [AEAudioController nonInterleavedFloatStereoAudioDescription];
    
    // Pass the filter ports to the Audio Unit Wrapper, to handle the audio output responsibilities for us
    [_audioUnitWrapper addFilterPort:_logFilterPort];
    [_audioUnitWrapper addFilterPort:_bitCrusherFilterPort];
    
    // Add a trigger to toggle the filter's LFO speed
    self.lfoTrigger = [ABTrigger triggerWithTitle:@"Frequency"
                                             icon:[UIImage imageNamed:@"Frequency-Trigger-Fast.png"]
                                            block:^(ABTrigger *trigger, NSSet *ports) {
                                                if ( _logFilter.lfoFrequency == 1.0 ) {
                                                    _logFilter.lfoFrequency = 0.25;
                                                    trigger.state = ABTriggerStateSelected;
                                                } else {
                                                    _logFilter.lfoFrequency = 1.0;
                                                    trigger.state = ABTriggerStateNormal;
                                                }
                                            }];
    [_lfoTrigger setIcon:[UIImage imageNamed:@"Frequency-Trigger-Slow.png"] forState:ABTriggerStateSelected];
    
    self.viewController = [[[ABFilterViewController alloc] init] autorelease];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    // Add a channel (not used here)
    [_audioController addChannels:[NSArray arrayWithObject:self]];
    
    // Start the audio engine
    [_audioController start:NULL];
    
    // Watch for connection changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionsChanged:)
                                                 name:ABConnectionsChangedNotification
                                               object:nil];
    
    return YES;
}

-(void)applicationDidEnterBackground:(UIApplication *)application {
    if ( !_audiobusController.connected ) {
        // Stop the audio engine, suspending the app, if we're not connected
        //[_audioController stop]; -- Commented out to keep the app running during development
    }
}

-(void)applicationWillEnterForeground:(UIApplication *)application {
    if ( !_audioController.running ) {
        [_audioController start:NULL];
    }
}

- (void)connectionsChanged:(NSNotification*)notification {
    if ( ABFilterPortIsConnected(_logFilterPort) ) {
        [_audiobusController addTrigger:_lfoTrigger];
    } else {
        [_audiobusController removeTrigger:_lfoTrigger];
    }
}

static OSStatus renderCallback(id                        channel,
                               AEAudioController        *audioController,
                               const AudioTimeStamp     *time,
                               UInt32                    frames,
                               AudioBufferList          *audio) {
    
    /*
     * A real app might generate audio here. We'll just be silent.
     *
     * If we hadn't added the filter port to the Audio Unit Wrapper, we
     * would want to pull audio from the filter port(s) here, if connected...
     *
    ABAppDelegate *THIS = (ABAppDelegate*)channel;
    if ( ABFilterPortIsConnected(THIS->_logFilterPort) ) {
       // Pull output audio from the filter port
       ABFilterPortGetOutput(THIS->_logFilterPort, audio, frames, NULL);
       return noErr;
    }
    if ( ABFilterPortIsConnected(THIS->_bitCrusherFilterPort) ) {
        // Pull output audio from the filter port
        ABFilterPortGetOutput(THIS->_bitCrusherFilterPort, audio, frames, NULL);
        return noErr;
    }
     *
     *
     */
    
    return noErr;
}

-(AEAudioControllerRenderCallback)renderCallback {
    return renderCallback;
}

@end