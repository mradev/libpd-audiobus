//
//  ABAppDelegate.m
//  AB Torture Test
//
//  Created by Michael Tyson on 25/11/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import "ABAppDelegate.h"
#import "ABTortureTestViewController.h"
#import "TheAmazingAudioEngine.h"
#import "Audiobus.h"
#import "TPCircularBuffer+AudioBufferList.h"

@interface ABAppDelegate ()  <UIApplicationDelegate, AEAudioReceiver> {
    TPCircularBuffer _buffer;
    float _preTestDelayProbabilityValue;
}
@property (strong, nonatomic) ABTortureTestViewController *viewController;
@property (strong, nonatomic) AEAudioController *audioController;
@property (strong, nonatomic) ABAudiobusController *audiobusController;
@property (strong, nonatomic) ABOutputPort *output;
@property (strong, nonatomic) ABTrigger *testTrigger;
@property (nonatomic, assign, readwrite) BOOL testRunning;
@end

@implementation ABAppDelegate
@synthesize audioController = _audioController;
@synthesize audiobusController = _audiobusController;
@synthesize output = _output;
@synthesize delayProbability = _delayProbability;

- (void)dealloc {
    TPCircularBufferCleanup(&_buffer);
    self.window = nil;
    self.viewController = nil;
    self.audioController = nil;
    self.audiobusController = nil;
    self.output = nil;
    self.testTrigger = nil;
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
    self.audiobusController = [[[ABAudiobusController alloc] initWithAppLaunchURL:[NSURL URLWithString:@"abtorturetest.audiobus://"]
                                                                           apiKey:@"MCoqKkFCIFRvcnR1cmUgVGVzdCoqKmFidG9ydHVyZXRlc3QuYXVkaW9idXM6Ly8=:FyEOYb7G2LRBfiIh3qBEVGer0EHVOcNbpOunDf5kA699b6lFUGpkdO5WOe+MgBSnShdtc+F6+0J+m1pOO63RYo8HBl+IqDkqA84Dy3+1rfqgopYr2PrMBAHszRIf79N5"] autorelease];
    
    // Create an output port
    self.output = [_audiobusController addOutputPortNamed:@"Mic+Tone" title:@"Microphone Input with Tone"];
    
    // Tell the sender what our audio format is
    _output.clientFormat = _audioController.audioDescription;

    // Add a trigger
    self.testTrigger = [ABTrigger triggerWithTitle:@"Test" icon:[UIImage imageNamed:@"Test.png"] block:^(ABTrigger *trigger, NSSet *ports) {
        [self test];
    }];
    [_audiobusController addTrigger:_testTrigger];
    
    // Init the circular buffer we'll use for holding up the audio output, and init the random generator delay probability setting
    TPCircularBufferInit(&_buffer, 88200 * _audioController.audioDescription.mBytesPerFrame);
    _delayProbability = 0.1;
    srand(0);
    
    self.viewController = [[[ABTortureTestViewController alloc] init] autorelease];
    _viewController.appDelegate = self;
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

- (void)test {
    if ( _testRunning ) return;
    
    self.testRunning = YES;
    _preTestDelayProbabilityValue = _delayProbability;
    
    self.delayProbability = 0;
    
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(incrementTest:) userInfo:nil repeats:YES];
}

-(void)setTestRunning:(BOOL)testRunning {
    _testRunning = testRunning;
    _testTrigger.state = testRunning ? ABTriggerStateSelected : ABTriggerStateNormal;
}

- (void)incrementTest:(NSTimer*)timer {
    float updateValue = _delayProbability + 0.02;
    if ( updateValue >= 0.95 ) {
        self.delayProbability = _preTestDelayProbabilityValue;
        [timer invalidate];
        self.testRunning = NO;
        return;
    }
    
    self.delayProbability = updateValue;
}

// C input callback to receive audio from the microphone
static void audioInputAvailable (id                        receiver,
                                 AEAudioController        *audioController,
                                 void                     *source,
                                 const AudioTimeStamp     *time,
                                 UInt32                    frames,
                                 AudioBufferList          *audioBuffer) {
    ABAppDelegate *THIS = (ABAppDelegate*)receiver;
    
    // Add tone to mic audio
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
    
    // Buffer audio
    while ( !TPCircularBufferCopyAudioBufferList(&THIS->_buffer, audioBuffer, time, frames, AEAudioControllerAudioDescription(audioController)) ) {
        // If buffer full, send some audio from it
        AudioTimeStamp ts;
        AudioBufferList *buf = TPCircularBufferNextBufferList(&THIS->_buffer, &ts);
        ABOutputPortSendAudio(THIS->_output, buf, buf->mBuffers[0].mDataByteSize / AEAudioControllerAudioDescription(audioController)->mBytesPerFrame, &ts, NULL);
        TPCircularBufferConsumeNextBufferList(&THIS->_buffer);
    }
    
    // Send buffered audio, sometimes: Simulate packet delay
    if ( ((double)rand() / RAND_MAX) >= THIS->_delayProbability ) {
        while ( 1 ) {
            AudioTimeStamp ts;
            AudioBufferList *buf = TPCircularBufferNextBufferList(&THIS->_buffer, &ts);
            if ( !buf ) break;
            ABOutputPortSendAudio(THIS->_output, buf, buf->mBuffers[0].mDataByteSize / AEAudioControllerAudioDescription(audioController)->mBytesPerFrame, &ts, NULL);
            TPCircularBufferConsumeNextBufferList(&THIS->_buffer);
        }
    }
}

-(AEAudioControllerAudioCallback)receiverCallback {
    // Tells AEAudioController about our C input callback
    return audioInputAvailable;
}

@end
