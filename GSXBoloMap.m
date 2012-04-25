//
//  GSXBoloMap.m
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 12/29/09.
//  Copyright 2009 Robert Chrzanowski. All rights reserved.
//

#import "GSXBoloMap.h"
#import "GSXBoloMapView.h"
#import "GSToolsController.h"
#import "GSPaletteController.h"
#import "GSTileRect.h"


static void floodSize(GSTile tiles[][WIDTH], GSPoint point, int *minx, int *maxx, int *miny, int *maxy);
static void floodSizeLeft(GSTile tiles[][WIDTH], GSTile from, GSPoint point, int *minx, int *maxx, int *miny, int *maxy);
static void floodSizeRight(GSTile tiles[][WIDTH], GSTile from, GSPoint point, int *minx, int *maxx, int *miny, int *maxy);
static void floodSizeDown(GSTile tiles[][WIDTH], GSTile from, GSPoint point, int *minx, int *maxx, int *miny, int *maxy);
static void floodSizeUp(GSTile tiles[][WIDTH], GSTile from, GSPoint point, int *minx, int *maxx, int *miny, int *maxy);
static void flood(GSTile tiles[][WIDTH], GSTile to, GSPoint point);

NSString *const GSXBoloErrorDomain = @"GSXBoloErrorDomain";

static NSImage *img = nil;
static NSImage *sprites = nil;

@interface GSXBoloMap (Private)
- (void)remapImagesInRect:(GSRect)rect;
- (void)drawSprite:(GSImage)sprite at:(GSPoint)world;
@end

@implementation GSXBoloMap

+ (void)initialize {
  if (self == [GSXBoloMap class]) {
    assert((img = [[NSImage imageNamed:@"Tiles"] retain]) != nil);
    assert((sprites = [[NSImage imageNamed:@"Sprites"] retain]) != nil);
  }
}

- (id)init {
  self = [super init];

  if (self) {
    int x, y;

    bcopy(MAP_FILE_IDENT, preamble.ident, MAP_FILE_IDENT_LEN);
    preamble.version = CURRENT_MAP_VERSION;
    preamble.npills = 0;
    preamble.nbases = 0;
    preamble.nstarts = 0;

    for (y = 0; y < WIDTH; y++) {
      for (x = 0; x < WIDTH; x++) {
        tiles[y][x] = defaultTile(x, y);
      }
    }

    [self remapImagesInRect:kWorldRect];
  }

  return self;
}

// accessors
- (NSUInteger)pillCount {
  return preamble.npills;
}

- (const struct BMAP_PillInfo)pillAtIndex:(NSUInteger)i {
  NSAssert(i < preamble.npills, @"Pill index out of bounds.");
  return pills[i];
}

- (NSUInteger)baseCount {
  return preamble.nbases;
}

- (const struct BMAP_BaseInfo)baseAtIndex:(NSUInteger)i {
  NSAssert(i < preamble.nbases, @"Base index out of bounds.");
  return bases[i];
}

- (NSUInteger)startCount {
  return preamble.nstarts;
}

- (const struct BMAP_StartInfo)startAtIndex:(NSUInteger)i {
  NSAssert(i < preamble.nstarts, @"Start index out of bounds.");
  return starts[i];
}

- (GSTile)tileAtX:(NSUInteger)x y:(NSUInteger)y {
  NSAssert(x < WIDTH, @"Tile X coordinate out of bounds.");
  NSAssert(y < WIDTH, @"Tile Y coordinate out of bounds.");

  return tiles[y][x];
}

- (GSTile)tileAtPoint:(GSPoint)point {
  NSAssert(point.x < WIDTH, @"Tile X coordinate out of bounds.");
  NSAssert(point.y < WIDTH, @"Tile Y coordinate out of bounds.");

  return tiles[point.y][point.x];
}

- (GSTileRect *)tilesInRect:(GSRect)rect {
  return [GSTileRect tileRectWithTiles:(GSTile *)tiles inRect:rect];
}

- (GSTileRect *)tilesRectFloodAtPoint:(GSPoint)point {
  GSTile tile;
  int minx, maxx, miny, maxy;

  tile = tiles[point.y][point.x];

  floodSize(tiles, point, &minx, &maxx, &miny, &maxy);
  flood(tiles, tile, point);

  return [GSTileRect tileRectWithTiles:(GSTile *)tiles inRect:GSMakeRect(minx, miny, maxx - minx + 1, maxy - miny + 1)];
}

// updates image map

- (void)remapImagesInRect:(GSRect)rect {
  int x, y;

  for (y = GSMinY(rect); y <= GSMaxY(rect); y++) {
    for (x = GSMinX(rect); x <= GSMaxX(rect); x++) {
      images[y][x] = mapImage(tiles, x, y);
    }
  }


  [boloView setNeedsDisplayInRect:GSRect2NSRect(rect)];
}

- (NSString *)windowNibName {
  return @"GSXBoloMap";
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
  NSData *data;
  void *bytes;
  ssize_t length;

  if ((length = saveMap(&bytes, &preamble, pills, bases, starts, tiles)) == -1) {
    if (outError != NULL) {
      *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:memFullErr userInfo:NULL];
    }

    return nil;
  }

  if ((data = [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:YES]) == nil) {
    free(bytes);

    if (outError != NULL) {
      *outError = [NSError errorWithDomain:GSXBoloErrorDomain code:errno userInfo:NULL];
    }

    return nil;
  }

  if (outError != NULL) {
    *outError = nil;
  }

	return data;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
  if (loadMap([data bytes], [data length], &preamble, pills, bases, starts, tiles) == -1) {
    if (outError != NULL) {
      *outError = [NSError errorWithDomain:GSXBoloErrorDomain code:errno userInfo:NULL];
    }

    return NO;
  }

  [self remapImagesInRect:kWorldRect];

  return YES;
}

- (GSRect)mapRect {
  int x, y;

  for (y = GSMinY(kSeaRect); y <= GSMaxY(kSeaRect); y++) {
    for (x = GSMinX(kSeaRect); x <= GSMaxX(kSeaRect); x++) {
      if (tiles[y][x] != kSeaTile) {
        int i, minx, maxx, miny, maxy;

        minx = x;
        maxx = x;
        miny = y;
        maxy = y;

        for (x = GSMaxX(kSeaRect); x > maxx; x--) {
          if (tiles[y][x] != kSeaTile) {
            maxx = x;
            break;
          }
        }

        for (y++; y <= GSMaxY(kSeaRect); y++) {
          for (x = GSMinX(kSeaRect); x <= GSMaxX(kSeaRect); x++) {
            if (tiles[y][x] != kSeaTile) {
              minx = MIN(minx, x);
              maxy = y;

              for (x = GSMaxX(kSeaRect); x > maxx; x--) {
                if (tiles[y][x] != kSeaTile) {
                  maxx = x;
                  break;
                }
              }

              break;
            }
          }
        }

        for (i = 0; i < preamble.npills; i++) {
          minx = MIN(minx, pills[i].x);
          maxx = MAX(maxx, pills[i].x);
          miny = MIN(miny, pills[i].y);
          maxy = MAX(maxy, pills[i].y);
        }

        for (i = 0; i < preamble.nbases; i++) {
          minx = MIN(minx, bases[i].x);
          maxx = MAX(maxx, bases[i].x);
          miny = MIN(miny, bases[i].y);
          maxy = MAX(maxy, bases[i].y);
        }

        for (i = 0; i < preamble.nstarts; i++) {
          minx = MIN(minx, starts[i].x);
          maxx = MAX(maxx, starts[i].x);
          miny = MIN(miny, starts[i].y);
          maxy = MAX(maxy, starts[i].y);
        }

        return GSMakeRect(minx, miny, maxx - minx + 1, maxy - miny + 1);
      }
    }
  }

  return kSeaRect;
}

// draws document in rect

- (void)drawRect:(NSRect)rect {
  int min_i, max_i, min_j, max_j;
  int min_x, max_x, min_y, max_y;
  int y, x, i;
  GSRect worldRect =
    GSIntersectionRect(
      NSRect2GSRect(rect),
    /*
      GSMakeRect(
        floorf(NSMinX(rect) / TILE_WIDTH),
        WIDTH - ((int)floorf(NSMaxY(rect) / TILE_WIDTH)),
        ceilf(NSWidth(rect) / TILE_WIDTH),
        ceilf(NSHeight(rect) / TILE_WIDTH)
      ),
      */
      kSeaRect
    );

  min_i = ((int)floorf(NSMinX(rect)))/16;
  max_i = ((int)ceilf(NSMaxX(rect)))/16;

  min_j = ((int)floorf(NSMinY(rect)))/16;
  max_j = ((int)ceilf(NSMaxY(rect)))/16;

  min_x = min_i;
  max_x = max_i;

  min_y = 255 - max_j;
  max_y = 255 - min_j;

  /* draw the tiles in the rect */
  for (y = min_y; y <= max_y; y++) {
    for (x = min_x; x <= max_x; x++) {
      GSImage image = images[y][x];
      NSRect dstRect = NSMakeRect(16.0*x, 16.0*(255 - y), 16.0, 16.0);
      NSRect srcRect = NSMakeRect((image%16)*16, (image/16)*16, 16.0, 16.0);

      /* draw tile */
      [img drawInRect:dstRect fromRect:srcRect operation:NSCompositeCopy fraction:1.0];

      /* draw mine */
      if (isMinedTile(tiles, x, y)) {
        NSRect mineImageRect;

        mineImageRect = NSMakeRect((MINE00IMAGE%16)*16, (MINE00IMAGE/16)*16, 16.0, 16.0);
        [img drawInRect:dstRect fromRect:mineImageRect operation:NSCompositeSourceOver fraction:1.0];
      }
    }
  }

  for (i = 0; i < preamble.npills; i++) {
    GSPoint p = GSMakePoint(pills[i].x, pills[i].y);

    if (GSPointInRect(worldRect, p)) {
      GSImage image = HPIL00IMAGE + pills[i].armour;
      NSRect dstRect = NSMakeRect(16.0*p.x, 16.0*(255 - p.y), 16.0, 16.0);
      NSRect srcRect = NSMakeRect((image%16)*16, (image/16)*16, 16.0, 16.0);

      [img drawInRect:dstRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1.0];
    }
  }

  for (i = 0; i < preamble.nbases; i++) {
    GSPoint p = GSMakePoint(bases[i].x, bases[i].y);

    if (GSPointInRect(worldRect, p)) {
      GSImage image = bases[i].owner == NEUTRAL ? NBAS00IMAGE : HBAS00IMAGE;
      NSRect dstRect = NSMakeRect(16.0*p.x, 16.0*(255 - p.y), 16.0, 16.0);
      NSRect srcRect = NSMakeRect((image%16)*16, (image/16)*16, 16.0, 16.0);

      [img drawInRect:dstRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1.0];
    }
  }

  for (i = 0; i < preamble.nstarts; i++) {
    GSPoint p = GSMakePoint(starts[i].x, starts[i].y);

    if (GSPointInRect(worldRect, p)) {
      [self drawSprite:PTKB00IMAGE + starts[i].dir at:p];
    }
  }
}

- (void)drawSprite:(GSImage)sprite at:(GSPoint)world {
  NSRect srcRect;
  NSRect dstRect;

  srcRect = NSMakeRect((sprite % 16) * TILE_WIDTH, (sprite / 16) * TILE_WIDTH, TILE_WIDTH, TILE_WIDTH);
  dstRect = NSMakeRect(world.x * TILE_WIDTH, (WIDTH - world.y - 1) * TILE_WIDTH, TILE_WIDTH, TILE_WIDTH);
  [sprites drawInRect:dstRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1.0];
}

- (void)setTile:(GSTile)tile at:(GSPoint)point {
  if (tiles[point.y][point.x] != tile) {
    GSRect rect;
    int x, y;

    [[[self undoManager] prepareWithInvocationTarget:self] setTile:tiles[point.y][point.x] at:point];

    tiles[point.y][point.x] = tile;

    rect = GSMakeRect(point.x - 1, point.y - 1, 3, 3);

    for (y = GSMinY(rect); y <= GSMaxY(rect); y++) {
      for (x = GSMinX(rect); x <= GSMaxX(rect); x++) {
        images[y][x] = mapImage(tiles, x, y);
      }
    }

    [boloView setNeedsDisplayInRect:NSMakeRect(GSMinX(rect) * TILE_WIDTH, (WIDTH - 1 - GSMaxY(rect)) * TILE_WIDTH, GSWidth(rect) * TILE_WIDTH, GSHeight(rect) * TILE_WIDTH)];
  }
}

- (void)setTileRect:(GSTileRect *)tileRect {
  NSUndoManager *undoManager = [self undoManager];
  [undoManager registerUndoWithTarget:self selector:@selector(setTileRect:) object:[GSTileRect tileRectWithTiles:(GSTile *)tiles inRect:[tileRect rect]]];
  [tileRect copyToTiles:(void *)tiles];
  [self remapImagesInRect:GSIntersectionRect(GSInsetRect([tileRect rect], -1, -1), kSeaRect)];
}

- (void)createPillAt:(GSPoint)point {
  struct BMAP_PillInfo pill;

  NSAssert(GSPointInRect(kSeaRect, point), @"Pill Location Out of Bounds");

  pill.x = point.x;
  pill.y = point.y;
  pill.owner = NEUTRAL;
  pill.armour = MAX_PILL_ARMOUR;
  pill.speed = MAX_PILL_SPEED;

  [self insertPill:pill atIndex:preamble.npills];
}

- (void)insertPill:(struct BMAP_PillInfo)pill atIndex:(NSUInteger)i {
  int j;

  NSAssert(i <= preamble.npills, @"Pill Out of Bounds");
  NSAssert(GSPointInRect(kSeaRect, GSMakePoint(pill.x, pill.y)), @"Pill Location Out of Bounds");
  NSAssert(pill.owner == NEUTRAL || pill.owner < MAX_PLAYERS, @"Pill Owner Invalid");
  NSAssert(pill.armour <= MAX_PILL_ARMOUR, @"Pill Armour Value Out of Bounds");
  NSAssert(pill.speed <= MAX_PILL_SPEED, @"Pill Speed Value Out of Bounds");

  [[[self undoManager] prepareWithInvocationTarget:self] removePillAtIndex:i];

  for (j = preamble.npills; j > i; j--) {
    pills[j] = pills[j - 1];
  }

  pills[i] = pill;
  preamble.npills++;

  [boloView setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(pill.x, pill.y, 1, 1))];
}

- (void)removePillAtIndex:(NSUInteger)i {
  NSAssert(i < preamble.npills, @"Pill Out of Bounds");
  [[[self undoManager] prepareWithInvocationTarget:self] insertPill:pills[i] atIndex:i];
  [boloView setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(pills[i].x, pills[i].y, 1, 1))];
  preamble.npills--;

  for (; i < preamble.npills; i++) {
    pills[i] = pills[i + 1];
  }
}

- (void)setPillAtIndex:(NSUInteger)i toPill:(struct BMAP_PillInfo)pill {
  NSAssert(i < preamble.npills, @"Pill Out of Bounds");
  NSAssert(GSPointInRect(kSeaRect, GSMakePoint(pill.x, pill.y)), @"Pill Location Out of Bounds");
  NSAssert(pill.owner == NEUTRAL || pill.owner < MAX_PLAYERS, @"Pill Owner Invalid");
  NSAssert(pill.armour <= MAX_PILL_ARMOUR, @"Pill Armour Value Out of Bounds");
  NSAssert(pill.speed <= MAX_PILL_SPEED, @"Pill Speed Value Out of Bounds");

  if (
    !GSEqualPoints(GSMakePoint(pills[i].x, pills[i].y), GSMakePoint(pill.x, pill.y)) ||
    pills[i].owner != pill.owner || pills[i].armour != pill.armour || pills[i].speed != pill.speed
  ) {
    [[[self undoManager] prepareWithInvocationTarget:self] setPillAtIndex:i toPill:pills[i]];

    if (!GSEqualPoints(GSMakePoint(pills[i].x, pills[i].y), GSMakePoint(pill.x, pill.y))) {
      [boloView setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(pills[i].x, pills[i].y, 1, 1))];
    }

    pills[i] = pill;
    [boloView setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(pill.x, pill.y, 1, 1))];
  }
}

- (void)createBaseAt:(GSPoint)point {
  struct BMAP_BaseInfo base;

  NSAssert(GSPointInRect(kSeaRect, point), @"Base Location Out of Bounds");

  base.x = point.x;
  base.y = point.y;
  base.owner = NEUTRAL;
  base.armour = MAX_BASE_ARMOUR;
  base.shells = MAX_BASE_SHELLS;
  base.mines = MAX_BASE_MINES;

  [self insertBase:base atIndex:preamble.nbases];
}

- (void)insertBase:(struct BMAP_BaseInfo)base atIndex:(NSUInteger)i {
  int j;

  NSAssert(i <= preamble.nbases, @"Base Out of Bounds");
  NSAssert(GSPointInRect(kSeaRect, GSMakePoint(base.x, base.y)), @"Base Location Out of Bounds");
  NSAssert(base.owner == NEUTRAL || base.owner < MAX_PLAYERS, @"Base Owner Invalid");
  NSAssert(base.armour <= MAX_BASE_ARMOUR, @"Base Armour Value Out of Bounds");
  NSAssert(base.shells <= MAX_BASE_SHELLS, @"Base Shell Value Out of Bounds");
  NSAssert(base.mines <= MAX_BASE_MINES, @"Base Mine Value Out of Bounds");

  [[[self undoManager] prepareWithInvocationTarget:self] removeBaseAtIndex:i];

  for (j = preamble.nbases; j > i; j--) {
    bases[j] = bases[j - 1];
  }

  bases[i] = base;
  preamble.nbases++;

  [boloView setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(base.x, base.y, 1, 1))];
}

- (void)removeBaseAtIndex:(NSUInteger)i {
  NSAssert(i < preamble.nbases, @"Base Out of Bounds");
  [[[self undoManager] prepareWithInvocationTarget:self] insertBase:bases[i] atIndex:i];
  [boloView setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(bases[i].x, bases[i].y, 1, 1))];
  preamble.nbases--;

  for (; i < preamble.nbases; i++) {
    bases[i] = bases[i + 1];
  }
}

- (void)setBaseAtIndex:(NSUInteger)i toBase:(struct BMAP_BaseInfo)base {
  NSAssert(i < preamble.nbases, @"Base Out of Bounds");
  NSAssert(GSPointInRect(kSeaRect, GSMakePoint(base.x, base.y)), @"Base Location Out of Bounds");
  NSAssert(base.owner == NEUTRAL || base.owner < MAX_PLAYERS, @"Base Owner Invalid");
  NSAssert(base.armour <= MAX_BASE_ARMOUR, @"Base Armour Value Out of Bounds");
  NSAssert(base.shells <= MAX_BASE_SHELLS, @"Base Shells Value Out of Bounds");
  NSAssert(base.mines <= MAX_BASE_MINES, @"Base Mines Value Out of Bounds");

  if (
    !GSEqualPoints(GSMakePoint(bases[i].x, bases[i].y), GSMakePoint(base.x, base.y)) ||
    bases[i].owner != base.owner || bases[i].armour != base.armour || bases[i].shells != base.shells || bases[i].mines != base.mines
  ) {
    [[[self undoManager] prepareWithInvocationTarget:self] setBaseAtIndex:i toBase:bases[i]];

    if (!GSEqualPoints(GSMakePoint(bases[i].x, bases[i].y), GSMakePoint(base.x, base.y))) {
      [boloView setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(bases[i].x, bases[i].y, 1, 1))];
    }

    bases[i] = base;
    [boloView setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(base.x, base.y, 1, 1))];
  }
}

- (void)createStartAt:(GSPoint)point {
  struct BMAP_StartInfo start;

  NSAssert(GSPointInRect(kSeaRect, point), @"Start Location Out of Bounds");

  start.x = point.x;
  start.y = point.y;
  start.dir = 0;

  [self insertStart:start atIndex:preamble.nstarts];
}

- (void)insertStart:(struct BMAP_StartInfo)start atIndex:(NSUInteger)i {
  int j;

  NSAssert(i <= preamble.nstarts, @"Start Out of Bounds");
  NSAssert(GSPointInRect(kSeaRect, GSMakePoint(start.x, start.y)), @"Start Location Out of Bounds");
  NSAssert(start.dir < 16, @"Start Direction Out of Bounds");

  [[[self undoManager] prepareWithInvocationTarget:self] removeStartAtIndex:i];

  for (j = preamble.nstarts; j > i; j--) {
    starts[j] = starts[j - 1];
  }

  starts[i] = start;
  preamble.nstarts++;

  [boloView setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(start.x, start.y, 1, 1))];
}

- (void)removeStartAtIndex:(NSUInteger)i {
  NSAssert(i < preamble.nstarts, @"Start Out of Bounds");
  [[[self undoManager] prepareWithInvocationTarget:self] insertStart:starts[i] atIndex:i];
  [boloView setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(starts[i].x, starts[i].y, 1, 1))];
  preamble.nstarts--;

  for (; i < preamble.nstarts; i++) {
    starts[i] = starts[i + 1];
  }
}

- (void)setStartAtIndex:(NSUInteger)i toStart:(struct BMAP_StartInfo)start {
  NSAssert(i < preamble.nstarts, @"Start Out of Bounds");
  NSAssert(GSPointInRect(kSeaRect, GSMakePoint(start.x, start.y)), @"Start Location Out of Bounds");
  NSAssert(start.dir < 16, @"Start Direction Out of Bounds");

  if (starts[i].dir != start.dir || !GSEqualPoints(GSMakePoint(starts[i].x, starts[i].y), GSMakePoint(start.x, start.y))) {
    [[[self undoManager] prepareWithInvocationTarget:self] setStartAtIndex:i toStart:starts[i]];

    if (!GSEqualPoints(GSMakePoint(bases[i].x, bases[i].y), GSMakePoint(start.x, start.y))) {
      [boloView setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(starts[i].x, starts[i].y, 1, 1))];
    }

    starts[i] = start;
    [boloView setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(start.x, start.y, 1, 1))];
  }
}

- (void)offsetObjectsInRect:(GSRect)rect dX:(int)dX dY:(int)dY {
  NSAssert(GSContainsRect(kSeaRect, rect), @"Rect Out of Bounds");

  // only of source rect is not empty
  if (!GSIsEmptyRect(rect) && (dX != 0 || dY != 0)) {
    int i;

    // offset pills
    i = 0;
    while (i < preamble.npills) {
      if (GSPointInRect(rect, GSMakePoint(pills[i].x, pills[i].y))) {
        struct BMAP_PillInfo pill = pills[i];
        pill.x += dX;
        pill.y += dY;

        if (GSPointInRect(kSeaRect, GSMakePoint(pill.x, pill.y))) {
          // remove any objects underneith moved pill if pill is outside of source rect
          if (!GSPointInRect(rect, GSMakePoint(pill.x, pill.y))) {
            int j;

            for (j = 0; j < preamble.npills;) {
              if (j != i && GSEqualPoints(GSMakePoint(pill.x, pill.y), GSMakePoint(pills[j].x, pills[j].y))) {
                [self removePillAtIndex:j];

                if (j < i) {
                  i--;
                }
              }
              else {
                j++;
              }
            }

            for (j = 0; j < preamble.nbases;) {
              if (GSEqualPoints(GSMakePoint(pill.x, pill.y), GSMakePoint(bases[j].x, bases[j].y))) {
                [self removeBaseAtIndex:j];
              }
              else {
                j++;
              }
            }

            for (j = 0; j < preamble.nstarts;) {
              if (GSEqualPoints(GSMakePoint(pill.x, pill.y), GSMakePoint(starts[j].x, starts[j].y))) {
                [self removeStartAtIndex:j];
              }
              else {
                j++;
              }
            }
          }

          [self setPillAtIndex:i toPill:pill];
          i++;
        }
        else {
          [self removePillAtIndex:i];
        }
      }
      else {
        i++;
      }
    }

    // offset bases
    i = 0;
    while (i < preamble.nbases) {
      if (GSPointInRect(rect, GSMakePoint(bases[i].x, bases[i].y))) {
        struct BMAP_BaseInfo base = bases[i];
        base.x += dX;
        base.y += dY;

        if (GSPointInRect(kSeaRect, GSMakePoint(base.x, base.y))) {
          // remove any objects underneith moved base if outside of source rect
          if (!GSPointInRect(rect, GSMakePoint(base.x, base.y))) {
            int j;

            for (j = 0; j < preamble.npills;) {
              if (GSEqualPoints(GSMakePoint(base.x, base.y), GSMakePoint(pills[j].x, pills[j].y))) {
                [self removePillAtIndex:j];
              }
              else {
                j++;
              }
            }

            for (j = 0; j < preamble.nbases;) {
              if (j != i && GSEqualPoints(GSMakePoint(base.x, base.y), GSMakePoint(bases[j].x, bases[j].y))) {
                [self removeBaseAtIndex:j];

                if (j < i) {
                  i--;
                }
              }
              else {
                j++;
              }
            }

            for (j = 0; j < preamble.nstarts;) {
              if (GSEqualPoints(GSMakePoint(base.x, base.y), GSMakePoint(starts[j].x, starts[j].y))) {
                [self removeStartAtIndex:j];
              }
              else {
                j++;
              }
            }
          }

          [self setBaseAtIndex:i toBase:base];
          i++;
        }
        else {
          [self removeBaseAtIndex:i];
        }
      }
      else {
        i++;
      }
    }

    // offset starts
    i = 0;
    while (i < preamble.nstarts) {
      if (GSPointInRect(rect, GSMakePoint(starts[i].x, starts[i].y))) {
        struct BMAP_StartInfo start = starts[i];
        start.x += dX;
        start.y += dY;

        if (GSPointInRect(kSeaRect, GSMakePoint(start.x, start.y))) {
          // remove any objects underneith moved start if outside of source rect
          if (!GSPointInRect(rect, GSMakePoint(start.x, start.y))) {
            int j;

            for (j = 0; j < preamble.npills;) {
              if (GSEqualPoints(GSMakePoint(start.x, start.y), GSMakePoint(pills[j].x, pills[j].y))) {
                [self removePillAtIndex:j];
              }
              else {
                j++;
              }
            }

            for (j = 0; j < preamble.nbases;) {
              if (GSEqualPoints(GSMakePoint(start.x, start.y), GSMakePoint(bases[j].x, bases[j].y))) {
                [self removeBaseAtIndex:j];
              }
              else {
                j++;
              }
            }

            for (j = 0; j < preamble.nstarts;) {
              if (j != i && GSEqualPoints(GSMakePoint(start.x, start.y), GSMakePoint(starts[j].x, starts[j].y))) {
                [self removeStartAtIndex:j];

                if (j < i) {
                  i--;
                }
              }
              else {
                j++;
              }
            }
          }

          [self setStartAtIndex:i toStart:start];
          i++;
        }
        else {
          [self removeStartAtIndex:i];
        }
      }
      else {
        i++;
      }
    }
  }
}

- (void)flipHorinzontalObjectsInRect:(GSRect)rect {
  if (!GSIsEmptyRect(rect)) {
    int i;

    for (i = 0; i < preamble.npills; i++) {
      if (GSPointInRect(rect, GSMakePoint(pills[i].x, pills[i].y))) {
        struct BMAP_PillInfo pill = pills[i];
        pill.x = GSMaxX(rect) - (pill.x - GSMinX(rect));
        [self setPillAtIndex:i toPill:pill];
      }
    }

    for (i = 0; i < preamble.nbases; i++) {
      if (GSPointInRect(rect, GSMakePoint(bases[i].x, bases[i].y))) {
        struct BMAP_BaseInfo base = bases[i];
        base.x = GSMaxX(rect) - (base.x - GSMinX(rect));
        [self setBaseAtIndex:i toBase:base];
      }
    }

    for (i = 0; i < preamble.nstarts; i++) {
      if (GSPointInRect(rect, GSMakePoint(starts[i].x, starts[i].y))) {
        struct BMAP_StartInfo start = starts[i];
        start.x = GSMaxX(rect) - (start.x - GSMinX(rect));
        start.dir = (24 - start.dir) % 16;
        [self setStartAtIndex:i toStart:start];
      }
    }
  }
}

- (void)flipVerticalObjectsInRect:(GSRect)rect {
  if (!GSIsEmptyRect(rect)) {
    int i;

    for (i = 0; i < preamble.npills; i++) {
      if (GSPointInRect(rect, GSMakePoint(pills[i].x, pills[i].y))) {
        struct BMAP_PillInfo pill = pills[i];
        pill.y = GSMaxY(rect) - (pill.y - GSMinY(rect));
        [self setPillAtIndex:i toPill:pill];
      }
    }

    for (i = 0; i < preamble.nbases; i++) {
      if (GSPointInRect(rect, GSMakePoint(bases[i].x, bases[i].y))) {
        struct BMAP_BaseInfo base = bases[i];
        base.y = GSMaxY(rect) - (base.y - GSMinY(rect));
        [self setBaseAtIndex:i toBase:base];
      }
    }

    for (i = 0; i < preamble.nstarts; i++) {
      if (GSPointInRect(rect, GSMakePoint(starts[i].x, starts[i].y))) {
        struct BMAP_StartInfo start = starts[i];
        start.y = GSMaxY(rect) - (start.y - GSMinY(rect));
        start.dir = (16 - start.dir) % 16;
        [self setStartAtIndex:i toStart:start];
      }
    }
  }
}

- (void)rotateLeftObjectsInRect:(GSRect)rect {
  if (!GSIsEmptyRect(rect)) {
    int offset = (GSWidth(rect) - GSHeight(rect))/2;
    GSRect rotatedRect = GSOffsetRect(rect, offset, -offset);
    int i;

    rotatedRect.size = GSMakeSize(GSHeight(rect), GSWidth(rect));
    rotatedRect = GSOffsetRect(rotatedRect, GSMinX(kSeaRect) > GSMinX(rotatedRect) ? GSMinX(kSeaRect) - GSMinX(rotatedRect) : 0, GSMinY(kSeaRect) > GSMinY(rotatedRect) ? GSMinY(kSeaRect) - GSMinY(rotatedRect) : 0);
    rotatedRect = GSOffsetRect(rotatedRect, GSMaxX(rotatedRect) > GSMaxX(kSeaRect) ? GSMaxX(kSeaRect) - GSMaxX(rotatedRect) : 0, GSMaxY(rotatedRect) > GSMaxY(kSeaRect) ? GSMaxY(kSeaRect) - GSMaxY(rotatedRect) : 0);

    for (i = 0; i < preamble.npills; i++) {
      if (GSPointInRect(rect, GSMakePoint(pills[i].x, pills[i].y))) {
        struct BMAP_PillInfo pill = pills[i];

        pill.x = (pills[i].y - GSMinY(rect)) + GSMinX(rotatedRect);;
        pill.y = GSMaxY(rotatedRect) - (pills[i].x - GSMinX(rect));

        if (!GSPointInRect(rect, GSMakePoint(pill.x, pill.y))) {
          int j;

          // remove any objects underneith moved pill
          for (j = 0; j < preamble.npills;) {
            if (j != i && GSEqualPoints(GSMakePoint(pill.x, pill.y), GSMakePoint(pills[j].x, pills[j].y))) {
              [self removePillAtIndex:j];

              if (j < i) {
                i--;
              }
            }
            else {
              j++;
            }
          }

          for (j = 0; j < preamble.nbases;) {
            if (GSEqualPoints(GSMakePoint(pill.x, pill.y), GSMakePoint(bases[j].x, bases[j].y))) {
              [self removeBaseAtIndex:j];
            }
            else {
              j++;
            }
          }

          for (j = 0; j < preamble.nstarts;) {
            if (GSEqualPoints(GSMakePoint(pill.x, pill.y), GSMakePoint(starts[j].x, starts[j].y))) {
              [self removeStartAtIndex:j];
            }
            else {
              j++;
            }
          }
        }

        [self setPillAtIndex:i toPill:pill];
      }
    }

    for (i = 0; i < preamble.nbases; i++) {
      if (GSPointInRect(rect, GSMakePoint(bases[i].x, bases[i].y))) {
        struct BMAP_BaseInfo base = bases[i];

        base.x = (bases[i].y - GSMinY(rect)) + GSMinX(rotatedRect);;
        base.y = GSMaxY(rotatedRect) - (bases[i].x - GSMinX(rect));

        // remove any objects underneith moved base
        if (!GSPointInRect(rect, GSMakePoint(base.x, base.y))) {
          int j;

          for (j = 0; j < preamble.npills;) {
            if (GSEqualPoints(GSMakePoint(base.x, base.y), GSMakePoint(pills[j].x, pills[j].y))) {
              [self removePillAtIndex:j];
            }
            else {
              j++;
            }
          }

          for (j = 0; j < preamble.nbases;) {
            if (j != i && GSEqualPoints(GSMakePoint(base.x, base.y), GSMakePoint(bases[j].x, bases[j].y))) {
              [self removeBaseAtIndex:j];

              if (j < i) {
                i--;
              }
            }
            else {
              j++;
            }
          }

          for (j = 0; j < preamble.nstarts;) {
            if (GSEqualPoints(GSMakePoint(base.x, base.y), GSMakePoint(starts[j].x, starts[j].y))) {
              [self removeStartAtIndex:j];
            }
            else {
              j++;
            }
          }
        }

        [self setBaseAtIndex:i toBase:base];
      }
    }

    for (i = 0; i < preamble.nstarts; i++) {
      if (GSPointInRect(rect, GSMakePoint(starts[i].x, starts[i].y))) {
        struct BMAP_StartInfo start = starts[i];

        start.x = (starts[i].y - GSMinY(rect)) + GSMinX(rotatedRect);;
        start.y = GSMaxY(rotatedRect) - (starts[i].x - GSMinX(rect));
        start.dir = (start.dir + 4)%16;

        // remove any objects underneith moved start
        if (!GSPointInRect(rect, GSMakePoint(start.x, start.y))) {
          int j;

          for (j = 0; j < preamble.npills;) {
            if (GSEqualPoints(GSMakePoint(start.x, start.y), GSMakePoint(pills[j].x, pills[j].y))) {
              [self removePillAtIndex:j];
            }
            else {
              j++;
            }
          }

          for (j = 0; j < preamble.nbases;) {
            if (GSEqualPoints(GSMakePoint(start.x, start.y), GSMakePoint(bases[j].x, bases[j].y))) {
              [self removeBaseAtIndex:j];
            }
            else {
              j++;
            }
          }

          for (j = 0; j < preamble.nstarts;) {
            if (j != i && GSEqualPoints(GSMakePoint(start.x, start.y), GSMakePoint(starts[j].x, starts[j].y))) {
              [self removeStartAtIndex:j];

              if (j < i) {
                i--;
              }
            }
            else {
              j++;
            }
          }
        }

        [self setStartAtIndex:i toStart:start];
      }
    }
  }
}

- (void)rotateRightObjectsInRect:(GSRect)rect {
  if (!GSIsEmptyRect(rect)) {
    int offset = (GSWidth(rect) - GSHeight(rect))/2;
    GSRect rotatedRect = GSOffsetRect(rect, offset, -offset);
    int i;

    rotatedRect.size = GSMakeSize(GSHeight(rect), GSWidth(rect));
    rotatedRect = GSOffsetRect(rotatedRect, GSMinX(kSeaRect) > GSMinX(rotatedRect) ? GSMinX(kSeaRect) - GSMinX(rotatedRect) : 0, GSMinY(kSeaRect) > GSMinY(rotatedRect) ? GSMinY(kSeaRect) - GSMinY(rotatedRect) : 0);
    rotatedRect = GSOffsetRect(rotatedRect, GSMaxX(rotatedRect) > GSMaxX(kSeaRect) ? GSMaxX(kSeaRect) - GSMaxX(rotatedRect) : 0, GSMaxY(rotatedRect) > GSMaxY(kSeaRect) ? GSMaxY(kSeaRect) - GSMaxY(rotatedRect) : 0);

    for (i = 0; i < preamble.npills; i++) {
      if (GSPointInRect(rect, GSMakePoint(pills[i].x, pills[i].y))) {
        struct BMAP_PillInfo pill = pills[i];

        pill.x = GSMaxX(rotatedRect) - (pills[i].y - GSMinY(rect));
        pill.y = (pills[i].x - GSMinX(rect)) + GSMinY(rotatedRect);;

        if (!GSPointInRect(rect, GSMakePoint(pill.x, pill.y))) {
          int j;

          // remove any objects underneith moved pill
          for (j = 0; j < preamble.npills;) {
            if (j != i && GSEqualPoints(GSMakePoint(pill.x, pill.y), GSMakePoint(pills[j].x, pills[j].y))) {
              [self removePillAtIndex:j];

              if (j < i) {
                i--;
              }
            }
            else {
              j++;
            }
          }

          for (j = 0; j < preamble.nbases;) {
            if (GSEqualPoints(GSMakePoint(pill.x, pill.y), GSMakePoint(bases[j].x, bases[j].y))) {
              [self removeBaseAtIndex:j];
            }
            else {
              j++;
            }
          }

          for (j = 0; j < preamble.nstarts;) {
            if (GSEqualPoints(GSMakePoint(pill.x, pill.y), GSMakePoint(starts[j].x, starts[j].y))) {
              [self removeStartAtIndex:j];
            }
            else {
              j++;
            }
          }
        }

        [self setPillAtIndex:i toPill:pill];
      }
    }

    for (i = 0; i < preamble.nbases; i++) {
      if (GSPointInRect(rect, GSMakePoint(bases[i].x, bases[i].y))) {
        struct BMAP_BaseInfo base = bases[i];

        base.x = GSMaxX(rotatedRect) - (bases[i].y - GSMinY(rect));
        base.y = (bases[i].x - GSMinX(rect)) + GSMinY(rotatedRect);;

        // remove any objects underneith moved base
        if (!GSPointInRect(rect, GSMakePoint(base.x, base.y))) {
          int j;

          for (j = 0; j < preamble.npills;) {
            if (GSEqualPoints(GSMakePoint(base.x, base.y), GSMakePoint(pills[j].x, pills[j].y))) {
              [self removePillAtIndex:j];
            }
            else {
              j++;
            }
          }

          for (j = 0; j < preamble.nbases;) {
            if (j != i && GSEqualPoints(GSMakePoint(base.x, base.y), GSMakePoint(bases[j].x, bases[j].y))) {
              [self removeBaseAtIndex:j];

              if (j < i) {
                i--;
              }
            }
            else {
              j++;
            }
          }

          for (j = 0; j < preamble.nstarts;) {
            if (GSEqualPoints(GSMakePoint(base.x, base.y), GSMakePoint(starts[j].x, starts[j].y))) {
              [self removeStartAtIndex:j];
            }
            else {
              j++;
            }
          }
        }

        [self setBaseAtIndex:i toBase:base];
      }
    }

    for (i = 0; i < preamble.nstarts; i++) {
      if (GSPointInRect(rect, GSMakePoint(starts[i].x, starts[i].y))) {
        struct BMAP_StartInfo start = starts[i];

        start.x = GSMaxX(rotatedRect) - (starts[i].y - GSMinY(rect));
        start.y = (starts[i].x - GSMinX(rect)) + GSMinY(rotatedRect);;
        start.dir = (start.dir + 12) % 16;

        // remove any objects underneith moved start
        if (!GSPointInRect(rect, GSMakePoint(start.x, start.y))) {
          int j;

          for (j = 0; j < preamble.npills;) {
            if (GSEqualPoints(GSMakePoint(start.x, start.y), GSMakePoint(pills[j].x, pills[j].y))) {
              [self removePillAtIndex:j];
            }
            else {
              j++;
            }
          }

          for (j = 0; j < preamble.nbases;) {
            if (GSEqualPoints(GSMakePoint(start.x, start.y), GSMakePoint(bases[j].x, bases[j].y))) {
              [self removeBaseAtIndex:j];
            }
            else {
              j++;
            }
          }

          for (j = 0; j < preamble.nstarts;) {
            if (j != i && GSEqualPoints(GSMakePoint(start.x, start.y), GSMakePoint(starts[j].x, starts[j].y))) {
              [self removeStartAtIndex:j];

              if (j < i) {
                i--;
              }
            }
            else {
              j++;
            }
          }
        }

        [self setStartAtIndex:i toStart:start];
      }
    }
  }
}

- (void)deleteObjectsInRect:(GSRect)rect {
  if (!GSIsEmptyRect(rect)) {
    int i;

    for (i = preamble.npills - 1; i >= 0; i--) {
      if (GSPointInRect(rect, GSMakePoint(pills[i].x, pills[i].y))) {
        [self removePillAtIndex:i];
      }
    }

    for (i = preamble.nbases - 1; i >= 0; i--) {
      if (GSPointInRect(rect, GSMakePoint(bases[i].x, bases[i].y))) {
        [self removeBaseAtIndex:i];
      }
    }

    for (i = preamble.nstarts - 1; i >= 0; i--) {
      if (GSPointInRect(rect, GSMakePoint(starts[i].x, starts[i].y))) {
        [self removeStartAtIndex:i];
      }
    }
  }
}

- (void)setAppropriateTilesForObjectsInRect:(GSRect)rect {
  if (!GSIsEmptyRect(rect)) {
    int i;

    for (i = preamble.npills - 1; i >= 0; i--) {
      if (GSPointInRect(rect, GSMakePoint(pills[i].x, pills[i].y))) {
        [self setTile:appropriateTileForPill(tiles[pills[i].y][pills[i].x]) at:GSMakePoint(pills[i].x, pills[i].y)];
      }
    }

    for (i = preamble.nbases - 1; i >= 0; i--) {
      if (GSPointInRect(rect, GSMakePoint(bases[i].x, bases[i].y))) {
        [self setTile:appropriateTileForBase(tiles[bases[i].y][bases[i].x]) at:GSMakePoint(bases[i].x, bases[i].y)];
      }
    }

    for (i = preamble.nstarts - 1; i >= 0; i--) {
      if (GSPointInRect(rect, GSMakePoint(starts[i].x, starts[i].y))) {
        [self setTile:appropriateTileForStart(tiles[starts[i].y][starts[i].x]) at:GSMakePoint(starts[i].x, starts[i].y)];
      }
    }
  }
}

@end


// flood fill algorithm to find size of the fill area
// doesn't do out of bounds checks which is fine since there is a mine border that doesn't change
void floodSize(GSTile tiles[][WIDTH], GSPoint point, int *minx, int *maxx, int *miny, int *maxy) {
  GSTile from;

  *minx = point.x;
  *maxx = point.x;
  *miny = point.y;
  *maxy = point.y;

  from = tiles[point.y][point.x];
  tiles[point.y][point.x] = kTokenTile;

  floodSizeLeft (tiles, from, GSMakePoint(point.x - 1, point.y), minx, maxx, miny, maxy);
  floodSizeRight(tiles, from, GSMakePoint(point.x + 1, point.y), minx, maxx, miny, maxy);
  floodSizeDown (tiles, from, GSMakePoint(point.x, point.y - 1), minx, maxx, miny, maxy);
  floodSizeUp   (tiles, from, GSMakePoint(point.x, point.y + 1), minx, maxx, miny, maxy);
}

void floodSizeLeft(GSTile tiles[][WIDTH], GSTile from, GSPoint point, int *minx, int *maxx, int *miny, int *maxy) {
  if (tiles[point.y][point.x] == from) {
    *minx = MIN(*minx, point.x);
    tiles[point.y][point.x] = kTokenTile;
    floodSizeLeft (tiles, from, GSMakePoint(point.x - 1, point.y), minx, maxx, miny, maxy);
    floodSizeDown (tiles, from, GSMakePoint(point.x, point.y - 1), minx, maxx, miny, maxy);
    floodSizeUp   (tiles, from, GSMakePoint(point.x, point.y + 1), minx, maxx, miny, maxy);
  }
}

void floodSizeRight(GSTile tiles[][WIDTH], GSTile from, GSPoint point, int *minx, int *maxx, int *miny, int *maxy) {
  if (tiles[point.y][point.x] == from) {
    *maxx = MAX(*maxx, point.x);
    tiles[point.y][point.x] = kTokenTile;
    floodSizeRight(tiles, from, GSMakePoint(point.x + 1, point.y), minx, maxx, miny, maxy);
    floodSizeDown (tiles, from, GSMakePoint(point.x, point.y - 1), minx, maxx, miny, maxy);
    floodSizeUp   (tiles, from, GSMakePoint(point.x, point.y + 1), minx, maxx, miny, maxy);
  }
}

void floodSizeDown(GSTile tiles[][WIDTH], GSTile from, GSPoint point, int *minx, int *maxx, int *miny, int *maxy) {
  if (tiles[point.y][point.x] == from) {
    *miny = MIN(*miny, point.y);
    tiles[point.y][point.x] = kTokenTile;
    floodSizeLeft (tiles, from, GSMakePoint(point.x - 1, point.y), minx, maxx, miny, maxy);
    floodSizeRight(tiles, from, GSMakePoint(point.x + 1, point.y), minx, maxx, miny, maxy);
    floodSizeDown (tiles, from, GSMakePoint(point.x, point.y - 1), minx, maxx, miny, maxy);
  }
}

void floodSizeUp(GSTile tiles[][WIDTH], GSTile from, GSPoint point, int *minx, int *maxx, int *miny, int *maxy) {
  if (tiles[point.y][point.x] == from) {
    *maxy = MAX(*maxy, point.y);
    tiles[point.y][point.x] = kTokenTile;
    floodSizeLeft (tiles, from, GSMakePoint(point.x - 1, point.y), minx, maxx, miny, maxy);
    floodSizeRight(tiles, from, GSMakePoint(point.x + 1, point.y), minx, maxx, miny, maxy);
    floodSizeUp   (tiles, from, GSMakePoint(point.x, point.y + 1), minx, maxx, miny, maxy);
  }
}

void flood(GSTile tiles[][WIDTH], GSTile to, GSPoint point) {
  if (tiles[point.y][point.x] == kTokenTile) {
    tiles[point.y][point.x] = to;
    flood(tiles, to, GSMakePoint(point.x - 1, point.y));
    flood(tiles, to, GSMakePoint(point.x + 1, point.y));
    flood(tiles, to, GSMakePoint(point.x, point.y - 1));
    flood(tiles, to, GSMakePoint(point.x, point.y + 1));
  }
}
