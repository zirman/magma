//
//  GSXBoloMap.h
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 12/29/09.
//  Copyright 2009 Robert Chrzanowski. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "bmap.h"


@class GSXBoloMapView, GSTileRect;

@interface GSXBoloMap : NSDocument {
  struct BMAP_Preamble preamble;
  struct BMAP_PillInfo pills[MAX_PILLS];
  struct BMAP_BaseInfo bases[MAX_BASES];
  struct BMAP_StartInfo starts[MAX_STARTS];
  GSTile tiles[WIDTH][WIDTH];

  GSImage images[WIDTH][WIDTH];

  IBOutlet GSXBoloMapView *boloView;
}

// accessors
- (NSUInteger)pillCount;
- (struct BMAP_PillInfo)pillAtIndex:(NSUInteger)i;

- (NSUInteger)baseCount;
- (struct BMAP_BaseInfo)baseAtIndex:(NSUInteger)i;

- (NSUInteger)startCount;
- (struct BMAP_StartInfo)startAtIndex:(NSUInteger)i;

- (GSTile)tileAtX:(NSUInteger)x y:(NSUInteger)y;
- (GSTile)tileAtPoint:(GSPoint)point;
- (GSTileRect *)tilesInRect:(GSRect)rect;
- (GSTileRect *)tilesRectFloodAtPoint:(GSPoint)point;

// modifiers
- (void)createPillAt:(GSPoint)point;
- (void)insertPill:(struct BMAP_PillInfo)pill atIndex:(NSUInteger)i;
- (void)removePillAtIndex:(NSUInteger)i;
- (void)setPillAtIndex:(NSUInteger)i toPill:(struct BMAP_PillInfo)pill;

- (void)createBaseAt:(GSPoint)point;
- (void)insertBase:(struct BMAP_BaseInfo)base atIndex:(NSUInteger)i;
- (void)removeBaseAtIndex:(NSUInteger)i;
- (void)setBaseAtIndex:(NSUInteger)i toBase:(struct BMAP_BaseInfo)base;

- (void)createStartAt:(GSPoint)point;
- (void)insertStart:(struct BMAP_StartInfo)start atIndex:(NSUInteger)i;
- (void)removeStartAtIndex:(NSUInteger)i;
- (void)setStartAtIndex:(NSUInteger)i toStart:(struct BMAP_StartInfo)start;

- (void)setTile:(GSTile)tile at:(GSPoint)point;
- (void)setTileRect:(GSTileRect *)tileRect;

- (void)offsetObjectsInRect:(GSRect)rect dX:(int)dX dY:(int)dY;
- (void)flipHorinzontalObjectsInRect:(GSRect)rect;
- (void)flipVerticalObjectsInRect:(GSRect)rect;
- (void)rotateLeftObjectsInRect:(GSRect)rect;
- (void)rotateRightObjectsInRect:(GSRect)rect;
- (void)deleteObjectsInRect:(GSRect)rect;
- (void)setAppropriateTilesForObjectsInRect:(GSRect)rect;

- (GSRect)mapRect;

// draw methods
- (void)drawRect:(NSRect)rect;

@end

extern NSString *const GSXBoloErrorDomain;
