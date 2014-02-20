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
#import "ViewController.h"

//Unique, get a temporary registration from http://developer.audiob.us/temporary-registration
static NSString *const AUDIOBUS_API_KEY = @"MTM5NDEwOTc4MioqKkF1ZGlvQnVzbGlicGQqKipBdWRpb0J1c2xpYnBkLmF1ZGlvYnVzOi8v:Tf6vImI3uGLmGany/kcEQkJEdQSpFiZYWI4TF4MdjbFJaGKKzDN9YKXUC8a1vt7GxSFsMEJXi1EfDSKHRr9ICABTiJHwunkXu5ENXN16TKvGaM8g3naih+lZPRqALGW/";
static NSString *const PD_PATCH = @"Test_Patch.pd";

static NSString *const AUDIOBUS_URL_SCHEME = @"AudioBuslibpd.audiobus://";
static NSString *const AUDIOBUS_INPUTPORT = @"Main-Input";
static NSString *const AUDIOBUS_OUTPUTPORT = @"Main-Output";
static NSString *const AUDIOBUS_INPUT_DESCRIPTION = @"Main App Input";
static NSString *const AUDIOBUS_OUTPUT_DESCRIPTION = @"Main App Output";
static NSString *const AUDIOBUS_FILTER_TITLE = @"Pd-Filter";
static NSString *const AUDIOBUS_FILTERPORT_NAME = @"Main Filter";

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
    
    //libpd configuration
    self.pdaudioController = [[PdAudioController alloc]init];
    [self.pdaudioController configurePlaybackWithSampleRate:SAMPLE_RATE
                                             numberChannels:2
                                               inputEnabled:YES
                                              mixingEnabled:YES];
     
     //ticks completion handler, store ticks set in property
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
    //set audio active
    self.pdaudioController.active = YES;
    
    //open pd patch
    [PdBase openFile:PD_PATCH path:[[NSBundle mainBundle] bundlePath]];


    //audioBus check for any audio issues restart audio if detected
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
    // Watch for connection changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionsChanged:)
                                                 name:ABConnectionsChangedNotification
                                               object:nil];
    
    
    //add ports for input and output
    ABInputPort *input = [self.audiobusController addInputPortNamed:AUDIOBUS_INPUTPORT
                                                              title:NSLocalizedString(AUDIOBUS_INPUT_DESCRIPTION, nil)];
    ABOutputPort *output = [self.audiobusController addOutputPortNamed:AUDIOBUS_OUTPUTPORT
                                                                 title:NSLocalizedString(AUDIOBUS_OUTPUT_DESCRIPTION, nil)];
   
    //set input port attributes
    input.attributes = ABInputPortAttributePlaysLiveAudio;
    
    
    //add the audiounit wrapper
    self.audiobusAudioUnitWrapper = [[ABAudiobusAudioUnitWrapper alloc] initWithAudiobusController:self.audiobusController
                                                                                         audioUnit:self.pdaudioController.audioUnit.audioUnit
                                                                                            output:output input:input];
    self.audiobusAudioUnitWrapper.useLowLatencyInputStream = YES;
    
    //filter callback
    self.filterPort =  [self.audiobusController
                        addFilterPortNamed:AUDIOBUS_FILTERPORT_NAME
                        title:AUDIOBUS_FILTER_TITLE
                        processBlock:^(AudioBufferList *audio, UInt32 frames, AudioTimeStamp *timestamp) {
                            
                            // Filter the audio...
                            Float32 *auBuffer = (Float32 *)audio->mBuffers[0].mData;
                            int ticks = frames >>  log2int([PdBase getBlockSize]);
                            [PdBase processFloatWithInputBuffer:auBuffer outputBuffer:auBuffer ticks:ticks];
    }];
    
    //configure port
    int numberFrames = [PdBase getBlockSize] * self.ticks;
    self.filterPort.audioBufferSize = numberFrames;
    self.filterPort.clientFormat = [self.pdaudioController.audioUnit
                                    ASBDForSampleRate:SAMPLE_RATE
                                    numberChannels:2];
    
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
    
    self.pdaudioController.audioUnit.filterActive = ABFilterPortIsConnected(_filterPort);
    if (self.pdaudioController.audioUnit.filterActive)NSLog(@"Filter Port Connected");
    
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
