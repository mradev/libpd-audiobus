//
//  ABPort.h
//  Audiobus
//
//  Created by Michael Tyson on 02/04/2012.
//  Copyright (c) 2012 Audiobus. All rights reserved.
//


#ifdef __cplusplus
extern "C" {
#endif

#import <UIKit/UIKit.h>
#import "ABCommon.h"

/*!
 * Port types
 */
typedef enum {
    ABPortTypeInput,
    ABPortTypeFilter,
    ABPortTypeOutput
} ABPortType;

@class ABPeer;

/*!
 * Port
 *
 *  Ports are the source or destination points for Audiobus connections. Ports can
 *  send audio, receive audio, or filter audio.  You can define multiple ports of each
 *  type in your app to define different audio routes.  For example, a multi-track recorder 
 *  could define additional ports for each track, so each track can be routed to a different place,
 *  or recorded to individually.
 *
 *  This class represents a port on another peer.
 */
@interface ABPort : NSObject

/*!
 * The peer this port is on
 */
@property (nonatomic, assign, readonly) ABPeer *peer;

/*!
 * The internal port name
 */
@property (nonatomic, retain, readonly) NSString *name;

/*!
 * The title of the port, for display to the user
 */
@property (nonatomic, retain, readonly) NSString *title;

/*!
 * The port icon (a 64x64 image)
 */
@property (nonatomic, readonly) UIImage *icon;

/*!
 * The type of the port
 */
@property (nonatomic, readonly) ABPortType type;

/*!
 * The attributes of this port
 */
@property (nonatomic, readonly) uint32_t attributes;

@end

#ifdef __cplusplus
}
#endif