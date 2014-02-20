//
//  ABLogFilter.m
//  Audiobus Samples
//
//  Created by Michael Tyson on 06/05/2012.
//  Copyright (c) 2012 Audiobus. All rights reserved.
//

#import "ABLogFilter.h"

// Per-channel filter record structure
struct filter_rec_t {
    int firstTime;
    float yP;
};

@interface ABLogFilter () {
    struct filter_rec_t _channelRecord[2];
    float _oscillatorPosition;
    float _oscallatorRate;
}
static inline float xslide(int sval, float x, int *firstTime, float *yP );
@end

@implementation ABLogFilter
@synthesize lfoFrequency = _lfoFrequency;

-(id)init {
    if ( !(self = [super init]) ) return nil;
    
    self.lfoFrequency = 1.0;

    for ( int i=0; i<2; i++ ) {
        _channelRecord[i] = (struct filter_rec_t){ .firstTime = YES, .yP = 0 };
    }
    
    return self;
}

-(void)setLfoFrequency:(float)lfoFrequency {
    _lfoFrequency = lfoFrequency;
    _oscallatorRate = lfoFrequency / 44100.0;
}

-(void)filterAudio:(AudioBufferList *)audioBuffer length:(UInt32)lengthInFrames {
    for ( int frame=0; frame<lengthInFrames; frame++ ) {
        // Quick sin-esque oscillator
        float x = _oscillatorPosition;
        x *= x; x -= 1.0; x *= x; // x now in the range 0...1
        x *= 100; // x now in range 0-200
        _oscillatorPosition += _oscallatorRate;
        if ( _oscillatorPosition > 1.0 ) _oscillatorPosition -= 2.0;
        
        
        for ( int channel=0; channel<audioBuffer->mNumberBuffers; channel++ ) {
            float *audio = ((float*)audioBuffer->mBuffers[channel].mData) + frame;
            *audio = xslide((int)x, *audio, &_channelRecord[channel].firstTime, &_channelRecord[channel].yP);
        }
    }
}

///////////////////////////////////////////////////
//
// recursive logarithmic smoothing (low pass filter)
// based on algorithm in Max/MSP slide object
// http://cycling74.com
//
static inline float xslide(int sval, float x, int *firstTime, float *yP ) {
	float y;
	
	if(sval <= 0) {
		sval = 1;
	}
	
	if(*firstTime) {
		*firstTime = FALSE;
		*yP = x;
    }
	
	
	y = *yP + ((x - *yP) / sval);
	
	*yP = y;
	
	return(y);
}

@end
