//
//  AppDelegate.m
//  AudioBuslibpd
//
//  Created by paul adams on 19/02/2014.
//  Copyright (c) 2014 mra. All rights reserved.
//

#import "AppDelegate.h"


#import "Audiobus.h"
#import "PdBase.h"
#import "PdAudioController.h"
#import "AudioHelpers.h"

//Unique, change this for your app
static NSString *const AUDIOBUS_API_KEY = @"MCoqKkEtRGVsYXkqKipBLURlbGF5LmF1ZGlvYnVzOi8v:CCFnbK1qi/mnQbv7Ln411DLsY6FCHdkWfRkF+8OGL3SLEAOBX2xpn1yRxg0NyGOLfCrK8ZpiqeTWp/0xfpUa88VLvkw92+27yZ0jvVqNMrNhQYkk9hQVsO8TS1TwSFaN";
static NSString *const PD_PATCH = @"testaudiobus.pd";

static NSString *const AUDIOBUS_URL_SCHEME = @"A-Delay.audiobus://";
static float const SAMPLE_RATE = 44100;
static int const TICKS_PER_BUFFER = 8;//minimum libpd will allow, also what filter sets



@interface AppDelegate ()

@property (strong, nonatomic)ABAudiobusController *audiobusController;
@property (strong, nonatomic)ABAudiobusAudioUnitWrapper *audiobusAudioUnitWrapper;
@property (strong,nonatomic)PdAudioController *pdaudioController;
@property (nonatomic, retain)ABInputPort *input;
@property (strong, nonatomic)ABFilterPort *filterPort;
@property (assign,nonatomic)NSInteger ticks;
@end


@implementation AppDelegate

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    [self setupAudioEngine];
    
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
   // self.rootController = [[RootViewController alloc]init];
   // self.window.rootViewController = self.rootController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)setupAudioEngine {
    
    NSLog(@"%@ UISC", NSStringFromCGRect([UIScreen mainScreen].bounds));
    
    //launch PD Sound Engine
    self.pdaudioController = [[PdAudioController alloc]init];
    [self.pdaudioController configurePlaybackWithSampleRate:SAMPLE_RATE
                                         numberChannels:2
                                           inputEnabled:YES
                                          mixingEnabled:YES];
 
    [self.pdaudioController configureTicksPerBuffer:TICKS_PER_BUFFER withCompletionHandler:^(int ticksPerBufferSet, PdAudioStatus status) {
        switch (status) {
            case PdAudioError:
                self.ticks = ticksPerBufferSet;
                break;
            case PdAudioPropertyChanged:
                self.ticks = ticksPerBufferSet;
                break;
            case PdAudioOK:
                self.ticks = TICKS_PER_BUFFER;
                break;
            default:
                break;
        }
    }];
    
    self.pdaudioController.active = YES;
    
    //open pd patch
    [PdBase openFile:PD_PATCH path:[[NSBundle mainBundle] bundlePath]];


    //check for any audio issues restart audio if detected
    UInt32 channels;
    UInt32 size; //= sizeof(channels);
    OSStatus result = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels, &size, &channels);
    if ( result == kAudioSessionIncompatibleCategory ) {
        // Audio session error (rdar://13022588). Power-cycle audio session.
        AudioSessionSetActive(false);
        AudioSessionSetActive(true);
        result = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels, &size, &channels);
        if ( result != noErr ) {
            NSLog(@"Got error %ld while querying input channels", result);
        }
    }
    
    
    //audiobus setup
    self.audiobusController = [[ABAudiobusController alloc]
                               initWithAppLaunchURL:[NSURL URLWithString:AUDIOBUS_URL_SCHEME]
                               apiKey:AUDIOBUS_API_KEY];
    // Watch for connections
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionsChanged:)
                                                 name:ABConnectionsChangedNotification
                                               object:nil];
    
    
    //add ports for input and output
    ABOutputPort *output = [self.audiobusController addOutputPortNamed:@"Audio Output"
                                                                 title:NSLocalizedString(@"Main App Output", @"")];
    ABInputPort *input = [self.audiobusController addInputPortNamed:@"Audio Input"
                                                              title:NSLocalizedString(@"Main App Input", @"")];
    input.attributes = ABInputPortAttributePlaysLiveAudio;
    
    
    //add the audiounit wrapper
    self.audiobusAudioUnitWrapper = [[ABAudiobusAudioUnitWrapper alloc] initWithAudiobusController:self.audiobusController
                                                                                         audioUnit:self.pdaudioController.audioUnit.audioUnit
                                                                                            output:output input:input];
    self.audiobusAudioUnitWrapper.useLowLatencyInputStream = YES;
    
    
    //add filter port
    
    self.filterPort =  [self.audiobusController
                        addFilterPortNamed:@"AudPassFilter" title:@"testpd" processBlock:^(AudioBufferList *audio, UInt32 frames, AudioTimeStamp *timestamp) {
        // Filter the audio...
        Float32 *auBuffer = (Float32 *)audio->mBuffers[0].mData;
        int ticks = frames >>  log2int([PdBase getBlockSize]);
        [PdBase processFloatWithInputBuffer:auBuffer outputBuffer:auBuffer ticks:ticks];
                            
    }];
    
    
    int numberFrames = [PdBase getBlockSize] * self.ticks;
    self.filterPort.audioBufferSize = numberFrames;
    self.filterPort.clientFormat = [self.pdaudioController.audioUnit ASBDForSampleRate:SAMPLE_RATE numberChannels:2];
    
    //add port to audio unit wrapper
    [self.audiobusAudioUnitWrapper addFilterPort:self.filterPort];
    //print audio unit configuration
    [self printAudioSessionUnitInfo];
    
}

- (void)printAudioSessionUnitInfo {
    //audio info
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSLog(@" aft Buffer size %f \n category %@ \n sample rate %f \n input latency %f \n other app playing? %d \n audiosession mode %@ \n audiosession output latency %f",audioSession.IOBufferDuration,audioSession.category,audioSession.sampleRate,audioSession.inputLatency,audioSession.isOtherAudioPlaying,audioSession.mode,audioSession.outputLatency);
    
    [self.pdaudioController.audioUnit print];
    
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Only stop the audio system if Audiobus isn't connected
    if ( !self.audiobusController.connected ) {
        self.pdaudioController.active = NO;
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Cancel any scheduled shutdown
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopAudio) object:nil];
    
    // Start the audio system if it's not already running
    if ( !self.pdaudioController.active ) {
        self.pdaudioController.active = YES;
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)connectionsChanged:(NSNotification*)notification {
    
    
    
    if (ABFilterPortIsConnected(_filterPort)) {
        
        
        NSLog(@"Filter Port Connected");
        
    }
    
    self.pdaudioController.audioUnit.filterActive = ABFilterPortIsConnected(_filterPort);
    
    // Cancel any scheduled shutdown
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopAudio) object:nil];
    
    if ( self.audiobusController.connected && !self.pdaudioController.active ) {
        
        // Start the audio system upon connection, if it's not running already
        self.pdaudioController.active = YES;
        
    } else if ( !self.audiobusController.connected && self.pdaudioController.active
               && [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground ) {
        
        // Shut down after 10 seconds if we disconnected while in the background
        [self performSelector:@selector(stopAudio) withObject:nil afterDelay:10.0];
    }
    
    NSLog(@"Connections changed");
    [self printAudioSessionUnitInfo];
}

- (void)stopAudio {
    
    self.pdaudioController.active = NO;
}


@end
