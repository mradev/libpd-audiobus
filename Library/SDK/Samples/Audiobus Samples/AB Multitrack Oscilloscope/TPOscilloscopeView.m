//
//  TPOscilloscopeView.m
//
//  Created by Michael Tyson on 27/07/2011.
//  Copyright (c) 2012 A Tasty Pixel. All rights reserved.
//

#import "TPOscilloscopeView.h"
#import "TheAmazingAudioEngine.h"
#import <Accelerate/Accelerate.h>
#include <libkern/OSAtomic.h>

#define kBufferLength 2048 // In frames; higher values mean oscilloscope spans more time
#define kSkipFrames 16     // Frames to skip - higher value means faster render time, but rougher display

@interface TPOscilloscopeLayer : CALayer
- (void)start;
- (void)stop;
- (void)addAudio:(AudioBufferList*)audio length:(UInt32)lengthInFrames;
@property (nonatomic, retain) UIColor *lineColor;
@property (nonatomic, assign) BOOL freeze;
@end

@implementation TPOscilloscopeView
@dynamic lineColor;
@dynamic freeze;

-(id)initWithFrame:(CGRect)frame {
    if ( !(self = [super initWithFrame:frame]) ) return nil;
    
    self.backgroundColor = [UIColor clearColor];
    
    return self;
}

+(Class)layerClass {
    return [TPOscilloscopeLayer class];
}

-(void)start {
    [(TPOscilloscopeLayer*)self.layer start];
}

-(void)stop {
    [(TPOscilloscopeLayer*)self.layer stop];
}

-(UIColor *)lineColor {
    return ((TPOscilloscopeLayer*)self.layer).lineColor;
}

-(void)setLineColor:(UIColor *)lineColor {
    ((TPOscilloscopeLayer*)self.layer).lineColor = lineColor;
}

-(BOOL)freeze {
    return ((TPOscilloscopeLayer*)self.layer).freeze;
}

-(void)setFreeze:(BOOL)freeze {
    ((TPOscilloscopeLayer*)self.layer).freeze = freeze;
}

-(void)addAudio:(AudioBufferList *)audio length:(UInt32)lengthInFrames {
    if ( !((TPOscilloscopeLayer*)self.layer).freeze ) {
        [(TPOscilloscopeLayer*)self.layer addAudio:audio length:lengthInFrames];
    }
}

@end


@interface TPOscilloscopeLayer () {
    id           _timer;
    SInt16      *_buffer;
    float       *_scratchBuffer;
    int          _buffer_head;
}
@end

static void audioCallback(id THIS, AEAudioController *audioController, void *source, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio);

@implementation TPOscilloscopeLayer
@synthesize lineColor=_lineColor;
@synthesize freeze=_freeze;

-(id)init {
    if ( !(self = [super init]) ) return nil;

    _buffer = (SInt16*)calloc(kBufferLength, sizeof(SInt16));
    _scratchBuffer = (float*)malloc(kBufferLength * sizeof(float) * 2);
    self.contentsScale = [[UIScreen mainScreen] scale];
    self.lineColor = [UIColor blackColor];
    
    // Disable animating view refreshes
    self.actions = [NSDictionary dictionaryWithObject:[NSNull null] forKey:@"contents"];
    
    return self;
}

- (void)start {
    if ( _timer ) return;
    
    if ( NSClassFromString(@"CADisplayLink") ) {
        _timer = [CADisplayLink displayLinkWithTarget:self selector:@selector(update)];
        ((CADisplayLink*)_timer).frameInterval = 2;
        [_timer addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    } else {
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0/30.0 target:self selector:@selector(update) userInfo:nil repeats:YES];
    }
}

- (void)stop {
    if ( !_timer ) return;
    [_timer invalidate];
    _timer = nil;
}

-(void)dealloc {
    [self stop];
    self.lineColor = nil;
    free(_buffer);
    free(_scratchBuffer);
    [super dealloc];
}

- (void)update {
    if ( !_freeze ) [self setNeedsDisplay];
}

-(void)setFreeze:(BOOL)freeze {
    _freeze = freeze;
    [self setNeedsDisplay];
}

#pragma mark - Rendering

-(void)drawInContext:(CGContextRef)ctx {
    CGContextSetShouldAntialias(ctx, false);
    
    // Render ring buffer as path
    CGContextSetLineWidth(ctx, 2);
    CGContextSetStrokeColorWithColor(ctx, [_lineColor CGColor]);

    float multiplier = self.bounds.size.height / (INT16_MAX-INT16_MIN);
    float midpoint = self.bounds.size.height / 2.0;
    
    // Render in contiguous segments, wrapping around if necessary
    int remainingFrames = kBufferLength-1;
    int tail = (_buffer_head+1) % kBufferLength;
    float x = 0;
    float xIncrement = (self.bounds.size.width / (remainingFrames-1)) * kSkipFrames;
    
    CGContextBeginPath(ctx);

    while ( remainingFrames > 0 ) {
        int framesToRender = MIN(remainingFrames, kBufferLength - tail);
        int samplesToRender = framesToRender / kSkipFrames;
        
        vDSP_vramp(&x, &xIncrement, _scratchBuffer, 2, samplesToRender);
        vDSP_vflt16(&_buffer[tail], kSkipFrames, _scratchBuffer+1, 2, samplesToRender);
        vDSP_vsmul(_scratchBuffer+1, 2, &multiplier, _scratchBuffer+1, 2, samplesToRender);
        vDSP_vsadd(_scratchBuffer+1, 2, &midpoint, _scratchBuffer+1, 2, samplesToRender);
        
        CGContextAddLines(ctx, (CGPoint*)_scratchBuffer, samplesToRender);
        
        x += (samplesToRender-1)*xIncrement;
        tail += framesToRender;
        if ( tail == kBufferLength ) tail = 0;
        remainingFrames -= framesToRender;
    }
    
    CGContextStrokePath(ctx);
}

#pragma mark - Callback

- (void)addAudio:(AudioBufferList*)audio length:(UInt32)frames {

    // Get a pointer to the audio buffer that we can advance
    SInt16 *audioPtr = audio->mBuffers[0].mData;
    
    // Copy in contiguous segments, wrapping around if necessary
    int remainingFrames = frames;
    while ( remainingFrames > 0 ) {
        int framesToCopy = MIN(remainingFrames, kBufferLength - _buffer_head);
        
        if ( audio->mNumberBuffers == 2 || audio->mBuffers[0].mNumberChannels == 1 ) {
            // Mono, or non-interleaved; just memcpy
            memcpy(_buffer + _buffer_head, audioPtr, framesToCopy * sizeof(SInt16));
            audioPtr += framesToCopy;
        } else {
            // Interleaved stereo: Copy every second sample
            SInt16 *buffer = &_buffer[_buffer_head];
            for ( int i=0; i<framesToCopy; i++ ) {
                *buffer = *audioPtr;
                audioPtr += 2;
                buffer++;
            }
        }
        
        int buffer_head = _buffer_head + framesToCopy;
        if ( buffer_head == kBufferLength ) buffer_head = 0;
        OSMemoryBarrier();
        _buffer_head = buffer_head;
        remainingFrames -= framesToCopy;
    }
}

@end
