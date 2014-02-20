//
//  ABLogFilter.h
//  Audiobus Samples
//
//  Created by Michael Tyson on 06/05/2012.
//  Copyright (c) 2012 Audiobus. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ABLogFilter : NSObject
- (void)filterAudio:(AudioBufferList*)audio length:(UInt32)lengthInFrames;

@property (nonatomic, assign) float lfoFrequency;
@end
