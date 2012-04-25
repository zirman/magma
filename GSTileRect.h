//
//  GSTileRect.h
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 1/2/10.
//  Copyright 2010 Robert Chrzanowski. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "bmap.h"


@interface GSTileRect : NSObject < NSPasteboardReading, NSPasteboardWriting > {
  GSRect rect;
  GSTile *tiles;
}

+ (id)tileRectWithTiles:(const GSTile *)aTiles inRect:(GSRect)aRect;
+ (id)tileRectWithTile:(GSTile)tile inRect:(GSRect)aRect;
+ (id)tileRectWithTileRect:(GSTileRect *)tileRect inRect:(GSRect)aRect;

- (id)initWithTiles:(const GSTile *)aTiles inRect:(GSRect)aRect;
- (id)initWithTile:(GSTile)tile inRect:(GSRect)aRect;
- (id)initWithTileRect:(GSTileRect *)tileRect inRect:(GSRect)aRect;

- (GSRect)rect;
- (void)setOrigin:(GSPoint)origin;
- (void)offsetX:(int)dx y:(int)dy;

- (void)drawFilledEllipse:(GSTile)tile;

- (void)drawEllipse:(GSTile)tile;
- (void)drawRectangle:(GSTile)tile;
- (void)drawLine:(GSTile)tile fromPoint:(GSPoint)from toPoint:(GSPoint)to;
- (void)floodFillWithTile:(GSTile)tile atPoint:(GSPoint)point;
- (void)rotateLeft;
- (void)rotateRight;
- (void)flipHorizontal;
- (void)flipVertical;

- (void)copyToTiles:(GSTile *)aTiles;

@end
