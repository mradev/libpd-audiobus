//
//  TPOscilloscopeView.h
//
//  Created by Michael Tyson on 27/07/2011.
//  Copyright (c) 2012 A Tasty Pixel. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>

@interface TPOscilloscopeView : UIView

/*!
 * Begin rendering
 *
 *      Registers with the audio controller to start receiving
 *      outgoing audio samples, and begins rendering.
 */
- (void)start;

/*!
 * Stop rendering
 *
 *      Stops rendering, and unregisters from the audio controller.
 */
- (void)stop;

/*! The line color to render with */
@property (nonatomic, retain) UIColor *lineColor;

/*! Whether to freeze display */
@property (nonatomic, assign) BOOL freeze;

- (void)addAudio:(AudioBufferList*)audio length:(UInt32)lengthInFrames;

@end
