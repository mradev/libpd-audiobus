//
//  ABAppDelegate.m
//  AB Sender
//
//  Created by Michael Tyson on 25/11/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import "ABAppDelegate.h"
#import "ABSenderViewController.h"
#import "TheAmazingAudioEngine.h"
#import "Audiobus.h"

@interface ABAppDelegate ()  <UIApplicationDelegate, AEAudioReceiver>
@property (strong, nonatomic) ABSenderViewController *viewController;
@property (strong, nonatomic) AEAudioController *audioController;
@property (strong, nonatomic) ABAudiobusController *audiobusController;
@property (strong, nonatomic) ABOutputPort *output;
@property (strong, nonatomic) ABOutputPort *alternativeOutput;
@end

@implementation ABAppDelegate
@synthesize window = _window;
@synthesize viewController = _viewController;
@synthesize audioController = _audioController;
@synthesize audiobusController = _audiobusController;
@synthesize output = _output;
@synthesize alternativeOutput = _alternativeOutput;

- (void)dealloc {
    [_window release];
    [_viewController release];
    [_audioController release];
    [_audiobusController release];
    [_output release];
    [_alternativeOutput release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    
    // Create an instance of AEAudioController, the audio engine, with input enabled
    // Please note: THIS IS AN EXAMPLE ONLY. The audio engine used here is NOT TO BE USED IN YOUR OWN IMPLEMENTATION. See theamazingaudioengine.com for details on this library.
    self.audioController = [[[AEAudioController alloc] initWithAudioDescription:[AEAudioController interleaved16BitStereoAudioDescription] 
                                                                   inputEnabled:YES] autorelease];
    _audioController.preferredBufferDuration = 0.005;
    
    // We want to receive input
    [_audioController addInputReceiver:self];
    
    // Create an Audiobus instance
    self.audiobusController = [[[ABAudiobusController alloc] initWithAppLaunchURL:[NSURL URLWithString:@"absender.audiobus://"]
                                                                           apiKey:@"MCoqKkFCIFNlbmRlcioqKmFic2VuZGVyLmF1ZGlvYnVzOi8v:cRQbpH4Id+tjCW/V6VXvXFXaci8buTx9mwKKEMU13C6TEPexxK/WrImoBzOQQ23cpynYdKOB97BH6OnPxNd5RdJj5ocGnGOpbqlkc+TwoQP07pbA396pI5gfdIQd7aQH"] autorelease];
    
    // Create an output port
    self.output = [_audiobusController addOutputPortNamed:@"Mic" title:@"Microphone Input"];
    
    // Create an alternate output port
    self.alternativeOutput = [_audiobusController addOutputPortNamed:@"Mic + Tone" title:@"Microphone + Tone"];
    _alternativeOutput.icon = [UIImage imageNamed:@"Tone-Port.png"];
    
    // Tell the sender what our audio format is
    _output.clientFormat = _audioController.audioDescription;
    
    self.viewController = [[[ABSenderViewController alloc] init] autorelease];
    _viewController.audiobusController = _audiobusController;
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    // Start the engine
    [_audioController start:NULL];
        
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

// C input callback to receive audio from the microphone
static void audioInputAvailable (id                        receiver,
                                 AEAudioController        *audioController,
                                 void                     *source,
                                 const AudioTimeStamp     *time,
                                 UInt32                    frames,
                                 AudioBufferList          *audioBuffer) {
    ABAppDelegate *THIS = (ABAppDelegate*)receiver;
    
    // Bombs away!
    ABOutputPortSendAudio(THIS->_output, audioBuffer, frames, time, NULL);
    
    // Send secondary channel, with a tone added
    static float lfoPosition = 0;
    const float lfoAdvanceRate = 500/44100.0;
    
    SInt16 *audio = (SInt16*)audioBuffer->mBuffers[0].mData;
    SInt16 *audioEnd = audio + (frames * 2);
    for ( ; audio < audioEnd; audio+=2 ) {
        lfoPosition += lfoAdvanceRate;
        if ( lfoPosition > 1.0 ) lfoPosition -= 2.0;
        float x = lfoPosition;
        x *= x; x -= 1.0; x *= x; // Quick sin-esque LFO - x is now in the range 0-1
        x -= 0.5; x *= 16384;
        
        // Left channel
        *audio += x;
        // Right channel
        *(audio+1) += x;
    }
    
    ABOutputPortSendAudio(THIS->_alternativeOutput, audioBuffer, frames, time, NULL);
}

-(AEAudioControllerAudioCallback)receiverCallback {
    // Tells AEAudioController about our C input callback
    return audioInputAvailable;
}

@end
