//
//  GSTileRect.m
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 1/2/10.
//  Copyright 2010 Robert Chrzanowski. All rights reserved.
//

#import "GSTileRect.h"


static NSString * const GSUTIString = @"com.robertchrzanowski.xbolo.map.rect";


static void floodFillTilesWithSize(GSTile *tiles, GSSize size, GSTile from, GSTile to, GSPoint point);


@implementation GSTileRect

// NSPasteboardReading Protocol Methods


+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
  return [NSArray arrayWithObject:GSUTIString];
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard {
  return NSPasteboardReadingAsData;
}

- (id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type {
  self = [super init];

  if (self) {
    NSDictionary *temp;
    NSPropertyListFormat format;
    NSString *errorDesc = nil;
    NSDictionary *origin;
    NSDictionary *size;
    NSData *data;

    temp = (NSDictionary *)[NSPropertyListSerialization
            propertyListFromData:propertyList
            mutabilityOption:NSPropertyListMutableContainersAndLeaves
            format:&format
            errorDescription:&errorDesc];

    if (!temp) {
      NSLog(@"Error reading plist: %@, format: %d", errorDesc, format);
    }

    origin = [temp objectForKey:@"origin"];
    rect.origin = GSMakePoint([[origin objectForKey:@"x"] intValue], [[origin objectForKey:@"y"] intValue]);

    size = [temp objectForKey:@"size"];
    rect.size = GSMakeSize([[size objectForKey:@"width"] intValue], [[size objectForKey:@"height"] intValue]);

    data = [temp objectForKey:@"tiles"];
    NSAssert([data length] == (GSWidth(rect) * GSHeight(rect) * sizeof(GSTile)), @"Error reading plist: Data length does not match rect size.");
    tiles = (GSTile *)malloc([data length]);
    NSAssert(tiles, @"Malloc() Failed");
    [data getBytes:tiles length:[data length]];
  }

  return self;
}

// NSPasteboardWriting Protocol Methods


- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
  return [NSArray arrayWithObject:GSUTIString];
}

- (id)pasteboardPropertyListForType:(NSString *)type {
  if ([type isEqual:GSUTIString]) {
    NSString *error;
    NSDictionary *plistDict;
    NSData *plistData;

    plistDict =
      [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:
        [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithUnsignedInt:GSMinX(rect)], [NSNumber numberWithUnsignedInt:GSMinY(rect)], nil] forKeys:[NSArray arrayWithObjects:@"x", @"y", nil]],
        [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithUnsignedInt:GSWidth(rect)], [NSNumber numberWithUnsignedInt:GSHeight(rect)], nil] forKeys:[NSArray arrayWithObjects:@"width", @"height", nil]],
        [NSData dataWithBytes:tiles length:GSWidth(rect) * GSHeight(rect) * sizeof(GSTile)],
        nil]
      forKeys:[NSArray arrayWithObjects:
        @"origin", @"size", @"tiles", nil]];

    plistData = [NSPropertyListSerialization dataFromPropertyList:plistDict format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];

    if(!plistData) {
      NSLog(@"%@", error);
      [error release];
    }

    return plistData;
  }

  return nil;
}

// Factory Class Methods


+ (id)tileRectWithTiles:(const GSTile *)aTiles inRect:(GSRect)aRect {
  return [[[self alloc] initWithTiles:aTiles inRect:aRect] autorelease];
}

+ (id)tileRectWithTile:(GSTile)tile inRect:(GSRect)aRect {
  return [[[self alloc] initWithTile:tile inRect:aRect] autorelease];
}

+ (id)tileRectWithTileRect:(GSTileRect *)tileRect inRect:(GSRect)aRect {
  return [[[self alloc] initWithTileRect:tileRect inRect:aRect] autorelease];
}

// Init Methods


- (id)initWithTiles:(const GSTile *)aTiles inRect:(GSRect)aRect {
  self = [super init];

  if (self) {
    rect = aRect;

    if (!GSIsEmptyRect(aRect)) {
      int x, y;

      tiles = (GSTile *)malloc(GSWidth(aRect) * GSHeight(aRect) * sizeof(GSTile));

      for (y = 0; y < GSHeight(rect); y++) {
        for (x = 0; x < GSWidth(rect); x++) {
          tiles[(y * GSWidth(rect)) + x] = aTiles[((y + GSMinY(rect)) * WIDTH) + (x + GSMinX(rect))];
        }
      }
    }
    else {
      tiles = NULL;
    }
  }

  return self;
}

- (id)initWithTile:(GSTile)tile inRect:(GSRect)aRect {
  self = [super init];

  if (self) {
    rect = aRect;

    if (!GSIsEmptyRect(aRect)) {
      int i;

      tiles = (GSTile *)malloc(GSWidth(aRect) * GSHeight(aRect) * sizeof(GSTile));

      for (i = 0; i < GSWidth(rect) * GSHeight(rect); i++) {
        tiles[i] = tile;
      }
    }
    else {
      tiles = NULL;
    }
  }

  return self;
}

- (id)initWithTileRect:(GSTileRect *)tileRect inRect:(GSRect)aRect {
  self = [super init];

  if (self) {
    rect = GSIntersectionRect(aRect, [tileRect rect]);
    aRect = [tileRect rect];

    if (!GSIsEmptyRect(rect)) {
      int x, y;

      tiles = (GSTile *)malloc(GSWidth(aRect) * GSHeight(aRect) * sizeof(GSTile));

      for (y = 0; y < GSHeight(rect); y++) {
        for (x = 0; x < GSWidth(rect); x++) {
          tiles[(y * GSWidth(rect)) + x] = tileRect->tiles[(((GSMinY(rect) + y) - GSMinY(aRect)) * GSWidth(aRect)) + ((GSMinX(rect) + x) - GSMinX(aRect))];
        }
      }
    }
    else {
      tiles = NULL;
    }
  }

  return self;
}

// dealloc


- (void)dealloc {
  if (tiles) {
    free(tiles);
  }

  [super dealloc];
}

// Accessor Methods


- (GSRect)rect {
  return rect;
}

- (void)setOrigin:(GSPoint)origin {
  if (!GSEqualPoints(rect.origin, origin)) {
    rect.origin = origin;
  }
}

- (void)offsetX:(int)dx y:(int)dy {
  rect = GSOffsetRect(rect, dx, dy);
}

// Draw Methods

- (void)drawFilledEllipse:(GSTile)tile {
  // ellipse
  // 1 = ((x*x)/(a*a)) + ((y*y)/(b*b))
  // x(y) = sqrt((1 - ((y*y)/(b*b))) * (a*a))

  float aa, bb, yf;
  int  xc, yc, x, y, xstart;

  xc = GSWidth(rect) - 1;
  yc = GSHeight(rect) - 1;
  aa *= (aa = xc * 0.5f);
  bb *= (bb = yc * 0.5f);

  y = GSHeight(rect) / 2;
  xstart = xc;
  yf = (GSHeight(rect) % 2) ? -0.5f : 0.0f;

  while (y < GSHeight(rect)) {
    int xend;

    xend = xstart;

    // if this is the last line
    if (y == GSHeight(rect) - 1) {
      xstart = GSWidth(rect) / 2;
    }
    else {
      yf += 1.0f;
      xstart = (GSWidth(rect) * 0.5f) + sqrtf((1.0f - ((yf * yf) / bb)) * aa);
    }

    // draw horizontal line with mirroring
    for (x = xc - xend; x <= xend; x++) {
      int yw, mx, my;

      yw = y * GSWidth(rect);
      mx = xc - x;
      my = (yc - y) * GSWidth(rect);

      // draw ellipse
      tiles[yw + x] = tile;
      // mirror y axis
      tiles[my + x] = tile;
    }

    y++;
  }
}

- (void)drawEllipse:(GSTile)tile {
  // ellipse
  // 1 = ((x*x)/(a*a)) + ((y*y)/(b*b))
  // x(y) = sqrt((1 - ((y*y)/(b*b))) * (a*a))

  float aa, bb, yf;
  int  xc, yc, x, y, xstart;

  xc = GSWidth(rect) - 1;
  yc = GSHeight(rect) - 1;
  aa *= (aa = xc * 0.5f);
  bb *= (bb = yc * 0.5f);

  y = GSHeight(rect) / 2;
  xstart = xc;
  yf = (GSHeight(rect) % 2) ? -0.5f : 0.0f;

  while (y < GSHeight(rect)) {
    int xend;

    xend = xstart;

    // if this is the last line
    if (y == GSHeight(rect) - 1) {
      xstart = GSWidth(rect) / 2;
    }
    else {
      yf += 1.0f;
      xstart = (GSWidth(rect) * 0.5f) + sqrtf((1.0f - ((yf * yf) / bb)) * aa);
    }

    // draw horizontal line with mirroring
    for (x = xstart; x <= xend; x++) {
      int yw, mx, my;

      yw = y * GSWidth(rect);
      mx = xc - x;
      my = (yc - y) * GSWidth(rect);

      // draw ellipse
      tiles[yw + x] = tile;

      // mirror y axis
      tiles[my + x] = tile;

      // mirror x axis
      tiles[yw + mx] = tile;

      // mirror x/y axis
      tiles[my + mx] = tile;
    }

    y++;
  }
}

- (void)drawLine:(GSTile)tile from:(GSPoint)fPoint to:(GSPoint)tPoint {
  // line
  // x = a*y + b

/*
  float aa, bb, yf;
  int  xc, yc, x, y, xstart;

  xc = GSWidth(rect) - 1;
  yc = GSHeight(rect) - 1;
  aa *= (aa = xc * 0.5f);
  bb *= (bb = yc * 0.5f);

  y = GSHeight(rect) / 2;
  xstart = xc;
  yf = (GSHeight(rect) % 2) ? -0.5f : 0.0f;

  while (y < GSHeight(rect)) {
    int xend;

    xend = xstart;

    // if this is the last line
    if (y == GSHeight(rect) - 1) {
      xstart = GSWidth(rect) / 2;
    }
    else {
      yf += 1.0f;
      xstart = (GSWidth(rect) * 0.5f) + sqrtf((1.0f - ((yf * yf) / bb)) * aa);
    }

    // draw horizontal line with mirroring
    for (x = xstart; x <= xend; x++) {
      int yw, mx, my;

      yw = y * GSWidth(rect);
      mx = xc - x;
      my = (yc - y) * GSWidth(rect);

      // draw ellipse
      tiles[yw + x] = tile;

      // mirror y axis
      tiles[my + x] = tile;

      // mirror x axis
      tiles[yw + mx] = tile;

      // mirror x/y axis
      tiles[my + mx] = tile;
    }

    y++;
  }
  */
}

- (void)drawRectangle:(GSTile)tile {
  int x, y;

  // draw bottom and top of rectangle
  for (x = 0; x < GSWidth(rect); x++) {
    tiles[x] = tile;
    tiles[((GSHeight(rect) - 1) * GSWidth(rect)) + x] = tile;
  }

  // draw left and right of rectangle
  for (y = 1; y < GSHeight(rect) - 1; y++) {
    tiles[(GSWidth(rect) * y)] = tile;
    tiles[(GSWidth(rect) * y) + GSWidth(rect) - 1] = tile;
  }
}

- (void)drawLine:(GSTile)tile fromPoint:(GSPoint)from toPoint:(GSPoint)to {
  int x, y;

  // draw bottom and top of rectangle
  for (x = 0; x < GSWidth(rect); x++) {
    tiles[x] = tile;
    tiles[((GSHeight(rect) - 1) * GSWidth(rect)) + x] = tile;
  }

  // draw left and right of rectangle
  for (y = 1; y < GSHeight(rect) - 1; y++) {
    tiles[(GSWidth(rect) * y)] = tile;
    tiles[(GSWidth(rect) * y) + GSWidth(rect) - 1] = tile;
  }
}

- (void)floodFillWithTile:(GSTile)tile atPoint:(GSPoint)point {
  NSAssert(tiles[((point.y - GSMinY(rect)) * GSWidth(rect)) + (point.x - GSMinX(rect))] != tile, @"");
  floodFillTilesWithSize(tiles, rect.size, tiles[((point.y - GSMinY(rect)) * GSWidth(rect)) + (point.x - GSMinX(rect))], tile, GSMakePoint(point.x - GSMinX(rect), point.y - GSMinY(rect)));
}

- (void)copyToTiles:(GSTile *)aTiles {
  int x, y;

  for (y = 0; y < GSHeight(rect); y++) {
    for (x = 0; x < GSWidth(rect); x++) {
      aTiles[((y + GSMinY(rect)) * WIDTH) + (x + GSMinX(rect))] = tiles[(y * GSWidth(rect)) + x];
    }
  }
}

- (void)rotateLeft {
  GSTile *newTiles;
  int x, y;
  int offset;

  newTiles = (GSTile *)malloc(GSWidth(rect) * GSHeight(rect) * sizeof(GSTile));
  NSAssert(newTiles != NULL, @"Malloc Failed");

  // translate tiles
  for (y = 0; y < GSHeight(rect); y++) {
    for (x = 0; x < GSWidth(rect); x++) {
      newTiles[((GSWidth(rect) - 1 - x) * GSHeight(rect)) + y] = tiles[(y * GSWidth(rect)) + x];
    }
  }

  free(tiles);

  // keep rect centered
  offset = (GSWidth(rect) - GSHeight(rect))/2;
  rect = GSOffsetRect(rect, offset, -offset);
  rect.size = GSMakeSize(GSHeight(rect), GSWidth(rect));

  // shift if outside of bounds
  rect = GSOffsetRect(rect, GSMinX(kSeaRect) > GSMinX(rect) ? GSMinX(kSeaRect) - GSMinX(rect) : 0, GSMinY(kSeaRect) > GSMinY(rect) ? GSMinY(kSeaRect) - GSMinY(rect) : 0);
  rect = GSOffsetRect(rect, GSMaxX(rect) > GSMaxX(kSeaRect) ? GSMaxX(kSeaRect) - GSMaxX(rect) : 0, GSMaxY(rect) > GSMaxY(kSeaRect) ? GSMaxY(kSeaRect) - GSMaxY(rect) : 0);

  tiles = newTiles;
}

- (void)rotateRight {
  GSTile *newTiles;
  int x, y;
  int offset;

  newTiles = (GSTile *)malloc(GSWidth(rect) * GSHeight(rect) * sizeof(GSTile));
  NSAssert(newTiles != NULL, @"Malloc Failed");

  // translate tiles
  for (y = 0; y < GSHeight(rect); y++) {
    for (x = 0; x < GSWidth(rect); x++) {
      newTiles[(x * GSHeight(rect)) + (GSHeight(rect) - 1 - y)] = tiles[(y * GSWidth(rect)) + x];
    }
  }

  free(tiles);

  // keep rect centered
  offset = (GSWidth(rect) - GSHeight(rect))/2;
  rect = GSOffsetRect(rect, offset, -offset);
  rect.size = GSMakeSize(GSHeight(rect), GSWidth(rect));

  // shift if outside of bounds
  rect = GSOffsetRect(rect, GSMinX(kSeaRect) > GSMinX(rect) ? GSMinX(kSeaRect) - GSMinX(rect) : 0, GSMinY(kSeaRect) > GSMinY(rect) ? GSMinY(kSeaRect) - GSMinY(rect) : 0);
  rect = GSOffsetRect(rect, GSMaxX(rect) > GSMaxX(kSeaRect) ? GSMaxX(kSeaRect) - GSMaxX(rect) : 0, GSMaxY(rect) > GSMaxY(kSeaRect) ? GSMaxY(kSeaRect) - GSMaxY(rect) : 0);

  tiles = newTiles;
}

- (void)flipHorizontal {
  int x, y;

  for (y = 0; y < GSHeight(rect); y++) {
    for (x = 0; x < GSWidth(rect)/2; x++) {
      GSTile t;

      t = tiles[(y * GSWidth(rect)) + x];
      tiles[(y * GSWidth(rect)) + x] = tiles[(y * GSWidth(rect)) + GSWidth(rect) - 1 - x];
      tiles[(y * GSWidth(rect)) + GSWidth(rect) - 1 - x] = t;
    }
  }
}

- (void)flipVertical {
  int x, y;

  for (y = 0; y < GSHeight(rect)/2; y++) {
    for (x = 0; x < GSWidth(rect); x++) {
      GSTile t;

      t = tiles[(y * GSWidth(rect)) + x];
      tiles[(y * GSWidth(rect)) + x] = tiles[((GSHeight(rect) - y - 1) * GSWidth(rect)) + x];
      tiles[((GSHeight(rect) - y - 1) * GSWidth(rect)) + x] = t;
    }
  }
}

@end

// flood fill algorithm that works on a GSTileRect.  does do bounds checking.
void floodFillTilesWithSize(GSTile *tiles, GSSize size, GSTile from, GSTile to, GSPoint point) {
  if (tiles[(point.y * size.width) + point.x] == from) {
    tiles[(point.y * size.width) + point.x] = to;

    if (point.x > 0) {
      floodFillTilesWithSize(tiles, size, from, to, GSMakePoint(point.x - 1, point.y));
    }

    if (point.x < size.width - 1) {
      floodFillTilesWithSize(tiles, size, from, to, GSMakePoint(point.x + 1, point.y));
    }

    if (point.y > 0) {
      floodFillTilesWithSize(tiles, size, from, to, GSMakePoint(point.x, point.y - 1));
    }

    if (point.y < size.height - 1) {
      floodFillTilesWithSize(tiles, size, from, to, GSMakePoint(point.x, point.y + 1));
    }
  }
}