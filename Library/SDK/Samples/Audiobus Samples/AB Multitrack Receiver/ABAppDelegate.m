//
//  ABAppDelegate.m
//  AB Receiver
//
//  Created by Michael Tyson on 25/11/2011.
//  Copyright (c) 2011 Audiobus. All rights reserved.
//

#import "ABAppDelegate.h"
#import "ABMultitrackReceiverViewController.h"
#import "Audiobus.h"
#import "TheAmazingAudioEngine.h"
#import <AudioToolbox/AudioToolbox.h>
#import <libkern/OSAtomic.h>

#define kMaxSources 10

static const int kCoreAudioInputTag; // The tag we'll use to identify the core audio input stream

struct port_entry_t { ABPort *port; BOOL pendingRemoval; };

@interface ABAppDelegate () <AEAudioReceiver, AEAudioPlayable> {
    struct port_entry_t _portTable[kMaxSources]; // A C array of our connected ports
}
@property (nonatomic, retain) ABMultitrackReceiverViewController *viewController;
@property (nonatomic, retain) AEAudioController *audioController;
@property (nonatomic, retain) ABAudiobusController *audiobusController;
@property (nonatomic, retain) ABInputPort *input;
@property (nonatomic, retain) ABLiveBuffer *liveBuffer;
@property (nonatomic, retain) ABMultiStreamBuffer *multiStreamBuffer;
@end

@implementation ABAppDelegate
@synthesize window = _window;
@synthesize audiobusController = _audiobusController;
@synthesize viewController = _viewController;
@synthesize audioController = _audioController;
@synthesize input = _input;
@synthesize liveBuffer = _liveBuffer;
@synthesize multiStreamBuffer = _multiStreamBuffer;

- (void)dealloc {
    self.window = nil;
    self.viewController = nil;
    self.audiobusController = nil;
    self.audioController = nil;
    self.input = nil;
    self.liveBuffer = nil;
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    
    // Create an instance of your audio engine (The Amazing Audio Engine used here for example only)
    self.audioController = [[[AEAudioController alloc] initWithAudioDescription:[AEAudioController nonInterleaved16BitStereoAudioDescription] inputEnabled:YES] autorelease];
    
    // Create an Audiobus instance
    self.audiobusController = [[[ABAudiobusController alloc] initWithAppLaunchURL:[NSURL URLWithString:@"abmultitrackreceiver.audiobus://"]
                                                                           apiKey:@"MCoqKkFCIE11bHRpdHJhY2sgUmVjZWl2ZXIqKiphYm11bHRpdHJhY2tyZWNlaXZlci5hdWRpb2J1czovLw==:g18SFyNKk5jCnd8rftSAr3xvGXvFWRpxAVDVFV363JOH+1hYGKt7nHMpKaLP6PYTxJxjZS+ZVD5dI2JB2FuEq5TJbmOnb65UrK0IpTQ4aWJjx0YT2OKdmuMf/HIR146I"] autorelease];
    
    // Create an input port, to receive audio
    self.input = [_audiobusController addInputPortNamed:@"Main" title:@"Main Input"];
    
    // Configure the input port (receive audio as separate streams, and note that we'll play live audio)
    _input.receiveMixedAudio = NO;
    _input.clientFormat = _audioController.audioDescription;
    _input.attributes = ABInputPortAttributePlaysLiveAudio;
    
    // Register this class to receive device audio input from the audio engine
    [_audioController addInputReceiver:self];
    
    // Create an instance of the multi-stream buffer, for synchronizing audio streams
    self.multiStreamBuffer = [[[ABMultiStreamBuffer alloc] initWithClientFormat:_audioController.audioDescription] autorelease];
    
    // Create an instance of the live buffer, for managing the live monitoring audio
    self.liveBuffer = [[[ABLiveBuffer alloc] initWithClientFormat:_audioController.audioDescription] autorelease];
    
    // Add this class an an output channel - we'll relay audio from the live buffer
    [_audioController addChannels:[NSArray arrayWithObject:self]];
    
    // Start the audio engine
    [_audioController start:NULL];
    
    // Register to receive notifications when the Audiobus connections change, so we can update our C source array
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audiobusConnectionsChanged:) name:ABConnectionsChangedNotification object:nil];
    
    self.viewController = [[[ABMultitrackReceiverViewController alloc] init] autorelease];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

// Table lookup facility
- (struct port_entry_t*)entryForPort:(ABPort*)port {
    for ( int i=0; i<kMaxSources; i++ ) {
        if ( _portTable[i].port == port ) {
            return &_portTable[i];
        }
    }
    return NULL;
}

- (void)audiobusConnectionsChanged:(NSNotification*)notification {
    // Add new sources to our C array, and assign pan for live buffer so we hear channels spaced across the stereo field
    int sourceCount = [_input.sources count] + 1;
    float pan = sourceCount <= 1 ? 0 : -1.0;
    float panIncrement = sourceCount >= 2 ? 2.0 / (sourceCount-1) : 0;
    
    [_liveBuffer setPan:pan forSource:(ABLiveBufferSource)&kCoreAudioInputTag];
    pan += panIncrement;
    
    // Iterate through, adding missing sources to the C array.
    // We'll use the array in the Core Audio input callback, so we can avoid calling any Objective-C from there, which would be bad
    for ( ABPort *source in _input.sources ) {
        if ( ![self entryForPort:source] ) {
            struct port_entry_t *emptySlot = [self entryForPort:nil];
            if ( emptySlot ) {
                emptySlot->pendingRemoval = NO;
                emptySlot->port = source;
            }
        }
        
        // Set the pan for this channel
        [_liveBuffer setPan:pan forSource:(ABLiveBufferSource)source];
        pan += panIncrement;
    }
    
    // Prepare to remove old sources (this will be done on the Core Audio thread, so removals are thread-safe)
    for ( int i=0; i<kMaxSources; i++ ) {
        if ( _portTable[i].port && ![_input.sources containsObject:_portTable[i].port] ) {
            _portTable[i].pendingRemoval = YES;
        }
    }
}

// Callback for device audio input
static void audioInputCallback (id                        receiver,
                                AEAudioController        *audioController,
                                void                     *source,
                                const AudioTimeStamp     *time,
                                UInt32                    frames,
                                AudioBufferList          *audio) {

    // Get reference to this class
    ABAppDelegate *THIS = (ABAppDelegate*)receiver;
    
    // First a little housekeeping: Remove sources pending removal (which we did in the connection change handler above)
    for ( int i=0; i<kMaxSources; i++ ) {
        if ( THIS->_portTable[i].port && THIS->_portTable[i].pendingRemoval ) {
            // Tell the multi stream buffer that this source is now idle - it won't wait for more audio for this source any more
            ABMultiStreamBufferMarkSourceIdle(THIS->_multiStreamBuffer, (ABMultiStreamBufferSource)THIS->_portTable[i].port);
            
            // Also tell the live buffer that this source is idle so it will go silent straight away
            ABLiveBufferMarkSourceIdle(THIS->_liveBuffer, (ABLiveBufferSource)THIS->_portTable[i].port);
            
            THIS->_portTable[i].pendingRemoval = NO;
            THIS->_portTable[i].port = nil;
        }
    }
    
    // Enqueue the audio input from the device into our multi-stream buffer
    ABMultiStreamBufferEnqueue(THIS->_multiStreamBuffer,
                               (ABMultiStreamBufferSource)&kCoreAudioInputTag, // This is our identifier for the core audio input stream
                               audio,
                               frames,
                               time);
    
    // Next peek the available audio on the input port
    AudioTimeStamp audiobusTimestamp;
    UInt32 audiobusFrames = ABInputPortPeek(THIS->_input, &audiobusTimestamp);
    
    // Now iterate through each of the Audiobus sources, pulling their audio and enqueuing each stream
    if ( audiobusFrames > 0 ) {
        // Create an audio buffer list on the stack
        char audioBufferListSpace[sizeof(AudioBufferList)+sizeof(AudioBuffer)]; // Space for 2 audio buffers within list
        AudioBufferList *bufferList = (AudioBufferList*)audioBufferListSpace;
        bufferList->mNumberBuffers = 2;
        
        for ( int i=0; i<kMaxSources; i++ ) {
            if ( THIS->_portTable[i].port ) {
                // First we initialize the audio buffer list - we have to do this each time, because Audiobus will alter the values
                for ( int j=0; j<bufferList->mNumberBuffers; j++ ) {
                    bufferList->mBuffers[j].mData = NULL; // Use NULL data; Audiobus will provide the buffers
                    bufferList->mBuffers[j].mDataByteSize = 0; // Audiobus will set this for us.
                    bufferList->mBuffers[j].mNumberChannels = 1;
                }
                
                // Now we draw audio from the source port
                ABInputPortReceive(THIS->_input,
                                   THIS->_portTable[i].port,
                                   bufferList,
                                   &audiobusFrames,
                                   NULL,
                                   NULL);
                
                // Then, we enqueue the audio into our multi-stream buffer
                ABMultiStreamBufferEnqueue(THIS->_multiStreamBuffer,
                                           (ABMultiStreamBufferSource)THIS->_portTable[i].port, // We use the port to identify the stream
                                           bufferList,
                                           audiobusFrames,
                                           &audiobusTimestamp);
            }
        }
        
        // Tell the input port that we've reached the end of this time interval
        ABInputPortEndReceiveTimeInterval(THIS->_input);
    }
    
    // Now we've enqueued all the audio for this timestamp, we can dequeue the synced streams from the multi-stream buffer
    // First we peek, to figure out how much audio can be dequeued across all streams
    AudioTimeStamp timestamp;
    UInt32 availableFrames = ABMultiStreamBufferPeek(THIS->_multiStreamBuffer, &timestamp);
    
    // Now we're ready to dequeue
    if ( availableFrames > 0 ) {
        // First, we create an audio buffer list on the stack, to receive the audio
        char audioBufferListSpace[sizeof(AudioBufferList)+sizeof(AudioBuffer)]; // Space for 2 audio buffers within list
        AudioBufferList *bufferList = (AudioBufferList*)audioBufferListSpace;
        bufferList->mNumberBuffers = 2;
   
        
        // Now, dequeue the device's audio input stream
        // Initialize the audio buffer list
        for ( int i=0; i<bufferList->mNumberBuffers; i++ ) {
            bufferList->mBuffers[i].mData = NULL; // Use NULL data; Audiobus will provide the buffers
            bufferList->mBuffers[i].mDataByteSize = 0; // Audiobus will set this for us.
            bufferList->mBuffers[i].mNumberChannels = 1;
        }
        
        ABMultiStreamBufferDequeueSingleSource(THIS->_multiStreamBuffer,
                                               (ABMultiStreamBufferSource)&kCoreAudioInputTag,
                                               bufferList,
                                               &availableFrames,
                                               NULL);
        
        // TODO: Do something with the *availableFrames* frames in *bufferList*
        // Here, we'll enqueue it on the live buffer so we can play the audio out the device audio output
        ABLiveBufferEnqueue(THIS->_liveBuffer,
                            (ABLiveBufferSource)&kCoreAudioInputTag,
                            bufferList,
                            availableFrames,
                            &timestamp);
        
        
        bufferList->mNumberBuffers = 2;
        
        // Next, dequeue audio for each of the ports
        for ( int i=0; i<kMaxSources; i++ ) {
            if ( THIS->_portTable[i].port ) {
                // Initialize the audio buffer list
                for ( int j=0; j<bufferList->mNumberBuffers; j++ ) {
                    bufferList->mBuffers[j].mData = NULL;
                    bufferList->mBuffers[j].mDataByteSize = 0;
                    bufferList->mBuffers[j].mNumberChannels = 1;
                }
                
                ABMultiStreamBufferDequeueSingleSource(THIS->_multiStreamBuffer,
                                                       (ABMultiStreamBufferSource)THIS->_portTable[i].port,
                                                       bufferList,
                                                       &availableFrames,
                                                       &timestamp);
                
                // TODO: Do something with the *availableFrames* frames in *bufferList*
                // We'll enqueue it on the live buffer so we can play the audio out the device audio output
                ABLiveBufferEnqueue(THIS->_liveBuffer,
                                    (ABLiveBufferSource)THIS->_portTable[i].port,
                                    bufferList,
                                    availableFrames,
                                    &timestamp);
            }
        }
        
        // Finally, we tell the multi-stream buffer we've reached the end of a timestamp
        ABMultiStreamBufferEndTimeInterval(THIS->_multiStreamBuffer);
    }
}

-(AEAudioControllerAudioCallback)receiverCallback {
    return audioInputCallback;
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
