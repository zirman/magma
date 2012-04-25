//
//  GSXBoloMapView.m
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 12/29/09.
//  Copyright 2009 Robert Chrzanowski. All rights reserved.
//

#import "GSXBoloMapView.h"
#import "GSXBoloMap.h"
#import "GSToolsController.h"
#import "GSPaletteController.h"
#import "GSTileRect.h"


static NSImage *sprites = nil;
static CGFloat phase = 0.0f;
static NSMutableArray *boloMapViews = nil;

@interface GSXBoloMapView (Private)
+ (void)phaseIncrement:(id)obj;
- (GSPoint)convertScreenToWorld:(NSPoint)point;
- (void)fillTool;
- (void)filledEllipseTool;
- (void)filledRectangleTool;
- (void)ellipseTool;
- (void)rectangleTool;
- (void)mineTool;
- (void)pillTool;
- (void)baseTool;
- (void)deleteTool;
- (GSRect)getSelection;
- (NSInteger)pillAtPoint:(GSPoint)point;
- (NSInteger)baseAtPoint:(GSPoint)point;
- (NSInteger)startAtPoint:(GSPoint)point;
- (void)setUnderSelection:(GSTileRect *)newUnderSelection;
- (void)setNeedsDisplayInSelectionRect;
@end

@implementation GSXBoloMapView

+ (void)initialize {
  if (self == [GSXBoloMapView class]) {
    NSAssert((sprites = [[NSImage imageNamed:@"Sprites"] retain]) != nil, @"Failed to Open Sprites File");
    boloMapViews = [[NSMutableArray alloc] init];
    [[NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(phaseIncrement:) userInfo:nil repeats:YES] retain];
  }
}

- (void)awakeFromNib {
  [self center:self];
}

- (id)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];

  if (self) {
    boloMap = nil;
    firstMouseEvent = GSMakePoint(-1, -1);
    lastMouseEvent = GSMakePoint(-1, -1);
    startTool = FALSE;
    start.x = 0;
    start.y = 0;
    start.dir = 0;

    underSelection = nil;
    move = FALSE;

    [boloMapViews addObject:self];
  } 

  return self;
}

- (void)release {
  if ([self retainCount] == 2) {
    [boloMapViews removeObject:self];
  }

  [super release];
}

+ (void)phaseIncrement:(id)obj {
  phase += 1.0f;
  [boloMapViews makeObjectsPerformSelector:@selector(setNeedsDisplayInSelectionRect)];
}

- (void)setNeedsDisplayInSelectionRect {
  if (underSelection) {
    GSRect rect = [underSelection rect];
    [self setNeedsDisplayInRect:NSMakeRect(GSMinX(rect) * TILE_WIDTH, (WIDTH - (GSMinY(rect) + GSHeight(rect))) * TILE_WIDTH, GSWidth(rect) * TILE_WIDTH, 1.0f)];
    [self setNeedsDisplayInRect:NSMakeRect(GSMinX(rect) * TILE_WIDTH, ((WIDTH - GSMinY(rect)) * TILE_WIDTH) - 1.0f, GSWidth(rect) * TILE_WIDTH, 1.0f)];
    [self setNeedsDisplayInRect:NSMakeRect(GSMinX(rect) * TILE_WIDTH, ((WIDTH - (GSMinY(rect) + GSHeight(rect))) * TILE_WIDTH) + 1.0f, 1.0f, (GSHeight(rect) * TILE_WIDTH) - 2.0f)];
    [self setNeedsDisplayInRect:NSMakeRect(((GSMinX(rect) + GSWidth(rect)) * TILE_WIDTH) - 1.0f, ((WIDTH - (GSMinY(rect) + GSHeight(rect))) * TILE_WIDTH) + 1.0f, 1.0f, (GSHeight(rect) * TILE_WIDTH) - 2.0f)];
  }
}

- (void)drawRect:(NSRect)rect {
  [boloMap drawRect:rect];

  // draw tank shadow
  if (startTool) {
    int sprite = PTKB00IMAGE + start.dir;
    NSRect srcRect = NSMakeRect((sprite % 16) * TILE_WIDTH, (sprite / 16) * TILE_WIDTH, TILE_WIDTH, TILE_WIDTH);
    NSRect dstRect = NSMakeRect(start.x * TILE_WIDTH, (WIDTH - start.y - 1) * TILE_WIDTH, TILE_WIDTH, TILE_WIDTH);
    [sprites drawInRect:dstRect fromRect:srcRect operation:NSCompositeSourceOver fraction:0.5];
  }

  // draw selection ring
  if (underSelection) {
    GSRect rect;
    NSBezierPath *b;
    NSInteger count = 2;
    CGFloat pattern[2] = { 5.0f, 5.0f };
    rect = [underSelection rect];
    b = [NSBezierPath bezierPathWithRect:NSMakeRect((GSMinX(rect) * TILE_WIDTH) + 0.5f, ((WIDTH - (GSMinY(rect) + GSHeight(rect))) * TILE_WIDTH) + 0.5f, (GSWidth(rect) * TILE_WIDTH) - 1.0f, (GSHeight(rect) * TILE_WIDTH) - 1.0f)];
    [b setLineDash:pattern count:count phase:(CGFloat)phase];
    [[NSColor selectedControlColor] set];
    [b stroke];
  }
}

- (void)fillTool {
  int palette;

  palette = [GSPaletteController palette];

  if ([boloMap tileAtPoint:firstMouseEvent] != palette) {
    GSTileRect *tileRect;

    if (underSelection) {
      tileRect = [boloMap tilesInRect:[underSelection rect]];
    }
    else {
      tileRect = [boloMap tilesRectFloodAtPoint:firstMouseEvent];
    }

    [tileRect floodFillWithTile:palette atPoint:firstMouseEvent];

    if (underSelection) {
      tileRect = [GSTileRect tileRectWithTileRect:tileRect inRect:[underSelection rect]];
    }

    [boloMap setTileRect:tileRect];
    [boloMap setAppropriateTilesForObjectsInRect:[tileRect rect]];
    [[boloMap undoManager] setActionName:@"Fill"];
  }
}

- (void)filledEllipseTool {
  GSTileRect *tileRect;
  tileRect = [boloMap tilesInRect:[self getSelection]];
  [tileRect drawFilledEllipse:[GSPaletteController palette]];

  if (underSelection) {
    tileRect = [GSTileRect tileRectWithTileRect:tileRect inRect:[underSelection rect]];
  }

  [boloMap setTileRect:tileRect];
  [boloMap setAppropriateTilesForObjectsInRect:[tileRect rect]];
  [[boloMap undoManager] setActionName:@"Draw Ellipse"];
}

- (void)filledRectangleTool {
  GSTileRect *tileRect = [GSTileRect tileRectWithTile:[GSPaletteController palette] inRect:[self getSelection]];

  if (underSelection) {
    tileRect = [GSTileRect tileRectWithTileRect:tileRect inRect:[underSelection rect]];
  }

  [boloMap setTileRect:tileRect];
  [boloMap setAppropriateTilesForObjectsInRect:[tileRect rect]];
  [[boloMap undoManager] setActionName:@"Draw Rectangle"];
}

- (void)ellipseTool {
  GSTileRect *tileRect = [boloMap tilesInRect:[self getSelection]];
  [tileRect drawEllipse:[GSPaletteController palette]];

  if (underSelection) {
    tileRect = [GSTileRect tileRectWithTileRect:tileRect inRect:[underSelection rect]];
  }

  [boloMap setTileRect:tileRect];
  [boloMap setAppropriateTilesForObjectsInRect:[tileRect rect]];
  [[boloMap undoManager] setActionName:@"Draw Ellipse"];
}

- (void)rectangleTool {
  GSTileRect *tileRect = [boloMap tilesInRect:[self getSelection]];
  [tileRect drawRectangle:[GSPaletteController palette]];

  if (underSelection) {
    tileRect = [GSTileRect tileRectWithTileRect:tileRect inRect:[underSelection rect]];
  }

  [boloMap setTileRect:tileRect];
  [boloMap setAppropriateTilesForObjectsInRect:[tileRect rect]];
  [[boloMap undoManager] setActionName:@"Draw Rectangle"];
}

- (void)mineTool {
  switch ([boloMap tileAtX:lastMouseEvent.x y:lastMouseEvent.y]) {
  case kSwampTile:
    [boloMap setTile:kMinedSwampTile at:lastMouseEvent];
    [boloMap setAppropriateTilesForObjectsInRect:GSMakeRect(lastMouseEvent.x, lastMouseEvent.y, 1, 1)];
    break;

  case kCraterTile:
    [boloMap setTile:kMinedCraterTile at:lastMouseEvent];
    [boloMap setAppropriateTilesForObjectsInRect:GSMakeRect(lastMouseEvent.x, lastMouseEvent.y, 1, 1)];
    break;

  case kRoadTile:
    [boloMap setTile:kMinedRoadTile at:lastMouseEvent];
    [boloMap setAppropriateTilesForObjectsInRect:GSMakeRect(lastMouseEvent.x, lastMouseEvent.y, 1, 1)];
    break;

  case kForestTile:
    [boloMap setTile:kMinedForestTile at:lastMouseEvent];
    [boloMap setAppropriateTilesForObjectsInRect:GSMakeRect(lastMouseEvent.x, lastMouseEvent.y, 1, 1)];
    break;

  case kRubbleTile:
    [boloMap setTile:kMinedRubbleTile at:lastMouseEvent];
    [boloMap setAppropriateTilesForObjectsInRect:GSMakeRect(lastMouseEvent.x, lastMouseEvent.y, 1, 1)];
    break;

  case kGrassTile:
    [boloMap setTile:kMinedGrassTile at:lastMouseEvent];
    [boloMap setAppropriateTilesForObjectsInRect:GSMakeRect(lastMouseEvent.x, lastMouseEvent.y, 1, 1)];
    break;

    default:
      break;
  }
}

- (void)pillTool {
  if ([boloMap pillCount] < MAX_PILLS &&
      [self pillAtPoint:firstMouseEvent] == -1 &&
      [self baseAtPoint:firstMouseEvent] == -1 &&
      [self startAtPoint:firstMouseEvent] == -1) {
    [boloMap setTile:appropriateTileForPill([boloMap tileAtX:firstMouseEvent.x y:firstMouseEvent.y]) at:GSMakePoint(firstMouseEvent.x, firstMouseEvent.y)];
    [boloMap createPillAt:firstMouseEvent];
    [[boloMap undoManager] setActionName:@"Add Pill"];
  }
}

- (void)baseTool {
  if ([boloMap baseCount] < MAX_BASES &&
      [self pillAtPoint:firstMouseEvent] == -1 &&
      [self baseAtPoint:firstMouseEvent] == -1 &&
      [self startAtPoint:firstMouseEvent] == -1) {
    [boloMap setTile:appropriateTileForBase([boloMap tileAtX:firstMouseEvent.x y:firstMouseEvent.y]) at:GSMakePoint(firstMouseEvent.x, firstMouseEvent.y)];
    [boloMap createBaseAt:firstMouseEvent];
    [[boloMap undoManager] setActionName:@"Add Base"];
  }
}

- (void)deleteTool {
  int i;

  if ((i = [self pillAtPoint:firstMouseEvent]) != -1) {
    [boloMap removePillAtIndex:i];
  }
  else if ((i = [self baseAtPoint:firstMouseEvent]) != -1) {
    [boloMap removeBaseAtIndex:i];
  }
  else if ((i = [self startAtPoint:firstMouseEvent]) != -1) {
    [boloMap removeStartAtIndex:i];
  }
}

- (GSRect)getSelection {
  if ([NSEvent modifierFlags] & NSShiftKeyMask) {
    int x, y, width, height;

    x = firstMouseEvent.x;
    y = firstMouseEvent.y;
    width = lastMouseEvent.x - firstMouseEvent.x;
    height = lastMouseEvent.y - firstMouseEvent.y;

    if (width > 0) {
      width++;
    }
    else {
      width--;
    }

    if (height > 0) {
      height++;
    }
    else {
      height--;
    }

    if (abs(width) > abs(height)) {
      width = width > 0 ? abs(height) : -abs(height);
    }

    if (abs(width) < abs(height)) {
      height = height > 0 ? abs(width) : -abs(width);
    }

    if (width < 0) {
      x += width + 1;
      width = -width;
    }

    if (height < 0) {
      y += height + 1;
      height = -height;
    }

    return GSMakeRect(x, y, width, height);
  }
  else {
    return GSMakeRect(MIN(firstMouseEvent.x, lastMouseEvent.x),
                    MIN(firstMouseEvent.y, lastMouseEvent.y),
                    MAX(firstMouseEvent.x, lastMouseEvent.x) - MIN(firstMouseEvent.x, lastMouseEvent.x) + 1,
                    MAX(firstMouseEvent.y, lastMouseEvent.y) - MIN(firstMouseEvent.y, lastMouseEvent.y) + 1);
  }
}

- (void)setUnderSelection:(GSTileRect *)newUnderSelection {
  [[boloMap undoManager] registerUndoWithTarget:self selector:@selector(setUnderSelection:) object:underSelection];

  [self setNeedsDisplayInSelectionRect];
  [underSelection release];
  underSelection = [newUnderSelection retain];
  [self setNeedsDisplayInSelectionRect];
}

- (NSInteger)pillAtPoint:(GSPoint)point {
  int i;

  for (i = 0; i < [boloMap pillCount]; i++) {
    if (GSEqualPoints(point, GSMakePoint([boloMap pillAtIndex:i].x, [boloMap pillAtIndex:i].y))) {
      return i;
    }
  }

  return -1;
}

- (NSInteger)baseAtPoint:(GSPoint)point {
  int i;

  for (i = 0; i < [boloMap baseCount]; i++) {
    if (GSEqualPoints(point, GSMakePoint([boloMap baseAtIndex:i].x, [boloMap baseAtIndex:i].y))) {
      return i;
    }
  }

  return -1;
}

- (NSInteger)startAtPoint:(GSPoint)point {
  int i;

  for (i = 0; i < [boloMap startCount]; i++) {
    if (GSEqualPoints(point, GSMakePoint([boloMap startAtIndex:i].x, [boloMap startAtIndex:i].y))) {
      return i;
    }
  }

  return -1;
}

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (void)mouseDown:(NSEvent *)event {
  GSPoint mouseEvent = [self convertScreenToWorld:[event locationInWindow]];

  if (GSPointInRect(kWorldRect, mouseEvent)) {
    firstMouseEvent = mouseEvent;
    lastMouseEvent = mouseEvent;

    switch ([GSToolsController tool]) {
    case kPencilTool:
      {
        NSUndoManager *undoManager = [boloMap undoManager];

        [undoManager setGroupsByEvent:NO];
        [undoManager beginUndoGrouping];

        if (GSPointInRect(kSeaRect, mouseEvent) && (!underSelection || GSPointInRect([underSelection rect], mouseEvent))) {
          [boloMap setTile:[GSPaletteController palette] at:lastMouseEvent];
          [boloMap setAppropriateTilesForObjectsInRect:GSMakeRect(lastMouseEvent.x, lastMouseEvent.y, 1, 1)];
        }
      }

      break;

    case kFillTool:
      if (GSPointInRect(kSeaRect, mouseEvent) && (!underSelection || GSPointInRect([underSelection rect], mouseEvent))) {
        [self fillTool];
      }

      break;

    case kSelectTool:
      if (underSelection && GSPointInRect([underSelection rect], firstMouseEvent)) {
        move = TRUE;
        [[boloMap undoManager] setActionName:@"Move"];
      }
      else {
        [self setUnderSelection:nil];
        [[boloMap undoManager] setActionName:@"Clear Selection"];
      }

      break;

    case kFilledEllipseTool:
      if (GSPointInRect(kSeaRect, mouseEvent)) {
        [self filledEllipseTool];
      }

      break;

    case kFilledRectangleTool:
      if (GSPointInRect(kSeaRect, mouseEvent)) {
        [self filledRectangleTool];
      }

      break;

    case kEllipseTool:
      if (GSPointInRect(kSeaRect, mouseEvent)) {
        [self ellipseTool];
      }

      break;

    case kRectangleTool:
      if (GSPointInRect(kSeaRect, mouseEvent)) {
        [self rectangleTool];
      }

      break;

    case kMineTool:
      {
        NSUndoManager *undoManager = [boloMap undoManager];

        [undoManager setGroupsByEvent:NO];
        [undoManager beginUndoGrouping];

        if (GSPointInRect(kSeaRect, mouseEvent) && (!underSelection || GSPointInRect([underSelection rect], mouseEvent))) {
          [self mineTool];
        }
      }

      break;

    case kPillTool:
      if (GSPointInRect(kSeaRect, mouseEvent)) {
        [self pillTool];
      }

      break;

    case kBaseTool:
      if (GSPointInRect(kSeaRect, mouseEvent)) {
        [self baseTool];
      }

      break;

    case kStartTool:
      if (GSPointInRect(kSeaRect, mouseEvent) &&
          [boloMap startCount] < MAX_STARTS &&
          [self startAtPoint:firstMouseEvent] == -1 &&
          [self pillAtPoint:firstMouseEvent] == -1 &&
          [self baseAtPoint:firstMouseEvent] == -1) {
        NSUndoManager *undoManager = [boloMap undoManager];
        [undoManager setGroupsByEvent:NO];
        [undoManager beginUndoGrouping];

        // modify terrain to be valid for start placement
        if ([boloMap tileAtX:firstMouseEvent.x y:firstMouseEvent.y] != kSeaTile) {
          [boloMap setTile:kSeaTile at:firstMouseEvent];
        }

        startTool = TRUE;
        start.x = firstMouseEvent.x;
        start.y = firstMouseEvent.y;
        start.dir = 0;
        [self setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(firstMouseEvent.x, firstMouseEvent.y, 1, 1))];
      }

      break;

    case kDeleteTool:
      if (GSPointInRect(kSeaRect, mouseEvent)) {
        [self deleteTool];
      }

      break;

    default:
      break;
    }
  }
}

- (void)mouseDragged:(NSEvent *)event {
  // only if first click was accepted
  if (!GSEqualPoints(firstMouseEvent, GSMakePoint(-1, -1))) {
    GSPoint mouseEvent = [self convertScreenToWorld:[event locationInWindow]];

    switch ([GSToolsController tool]) {
    case kStartTool:
      if (startTool) {
        NSPoint view, startp, vect;
        float dirf;
        int dir;

        view = [self convertPoint:[event locationInWindow] fromView:nil];
        startp.x = start.x * TILE_WIDTH + (TILE_WIDTH*0.5f);
        startp.y = (WIDTH - start.y - 1) * TILE_WIDTH + (TILE_WIDTH*0.5f);
        vect.x = view.x - startp.x;
        vect.y = view.y - startp.y;

        if (vect.x != 0.0f || vect.y != 0.0f) {
          dirf = atan2f(vect.y, vect.x);
      
          if (dirf < 0.0f) {
            dirf += k2Pif;
          }

          dir = ((int)roundf(dirf / (k2Pif / 16))) % 16;

          if (start.dir != dir) {
            start.dir = dir;
            [self setNeedsDisplayInRect:GSRect2NSRect(GSMakeRect(lastMouseEvent.x, lastMouseEvent.y, 1, 1))];
          }
        }
      }

      break;

    default:
      // only process dragged invents inside mined border
      if (GSPointInRect(kSeaRect, mouseEvent) && !GSEqualPoints(lastMouseEvent, mouseEvent)) {
        lastMouseEvent = mouseEvent;

        switch ([GSToolsController tool]) {
        case kPencilTool:
          if (!underSelection || GSPointInRect([underSelection rect], mouseEvent)) {
            [boloMap setTile:[GSPaletteController palette] at:lastMouseEvent];
            [boloMap setAppropriateTilesForObjectsInRect:GSMakeRect(lastMouseEvent.x, lastMouseEvent.y, 1, 1)];
          }

          break;

        case kFilledEllipseTool:
          [[boloMap undoManager] undo];
          [self filledEllipseTool];
          break;

        case kFilledRectangleTool:
          [[boloMap undoManager] undo];
          [self filledRectangleTool];
          break;

        case kEllipseTool:
          [[boloMap undoManager] undo];
          [self ellipseTool];
          break;

        case kRectangleTool:
          [[boloMap undoManager] undo];
          [self rectangleTool];
          break;

        case kMineTool:
          if (!underSelection || GSPointInRect([underSelection rect], mouseEvent)) {
            [self mineTool];
          }

          break;

        case kSelectTool:
          // undo last move from mouse drag
          [[boloMap undoManager] undo];

          if (move) {
            int dX = lastMouseEvent.x - firstMouseEvent.x;
            int dY = lastMouseEvent.y - firstMouseEvent.y;
            // copy selected rect after clipping with edge
            GSTileRect *over = [boloMap tilesInRect:GSOffsetRect(GSIntersectionRect(GSOffsetRect([underSelection rect], dX, dY), kSeaRect), -dX, -dY)];
            // offset copy
            [over offsetX:dX y:dY];
            // write under copy
            [boloMap setTileRect:underSelection];
            // offset objects
            [boloMap offsetObjectsInRect:[underSelection rect] dX:dX dY:dY];
            // set new under selection
            [self setUnderSelection:[boloMap tilesInRect:[over rect]]];
            // write copy
            [boloMap setTileRect:over];
            // for objects that entered
            [boloMap setAppropriateTilesForObjectsInRect:[over rect]];
            // set undo name
            [[boloMap undoManager] setActionName:@"Move"];
          }
          else {
            [self setUnderSelection:[GSTileRect tileRectWithTile:kSeaTile inRect:[self getSelection]]];
            [[boloMap undoManager] setActionName:@"Select"];
          }

          break;

        default:
          break;
        }
      }

      break;
    }
  }
}

- (void)mouseUp:(NSEvent *)event {
  if (!GSEqualPoints(firstMouseEvent, GSMakePoint(-1, -1))) {
    switch ([GSToolsController tool]) {
    case kPencilTool:
      {
        NSUndoManager *undoManager = [boloMap undoManager];
        NSString *actionName;

        switch ([GSPaletteController palette]) {
        case kWallTile:
          actionName = @"Draw Wall";
          break;

        case kRiverTile:
          actionName = @"Draw River";
          break;

        case kSwampTile:
          actionName = @"Draw Swamp";
          break;

        case kCraterTile:
          actionName = @"Draw Crater";
          break;

        case kRoadTile:
          actionName = @"Draw Road";
          break;

        case kForestTile:
          actionName = @"Draw Forest";
          break;

        case kRubbleTile:
          actionName = @"Draw Rubble";
          break;

        case kGrassTile:
          actionName = @"Draw Grass";
          break;

        case kDamagedWallTile:
          actionName = @"Draw Damaged Wall";
          break;

        case kBoatTile:
          actionName = @"Draw Boat";
          break;

        case kMinedSwampTile:
          actionName = @"Draw Mined Swamp";
          break;

        case kMinedCraterTile:
          actionName = @"Draw Mined Crater";
          break;
        
        case kMinedRoadTile:
          actionName = @"Draw Mined Road";
          break;

        case kMinedForestTile:
          actionName = @"Draw Mined Forest";
          break;

        case kMinedRubbleTile:
          actionName = @"Draw Mined Rubble";
          break;

        case kMinedGrassTile:
          actionName = @"Draw Mined Grass";
          break;

        case kSeaTile:
          actionName = @"Draw Sea";
          break;

        default:
          NSAssert(nil, @"");
          break;
        }

        [undoManager setActionName:actionName];
        [undoManager endUndoGrouping];
        [undoManager setGroupsByEvent:YES];
      }

      break;

    case kMineTool:
      {
        NSUndoManager *undoManager = [boloMap undoManager];
        [undoManager setActionName:@"Draw Mines"];
        [undoManager endUndoGrouping];
        [undoManager setGroupsByEvent:YES];
      }

      break;

    case kStartTool:
      if (startTool) {
        NSUndoManager *undoManager = [boloMap undoManager];
        [boloMap insertStart:start atIndex:[boloMap startCount]];
        [undoManager setActionName:@"Create Start"];
        [undoManager endUndoGrouping];
        [undoManager setGroupsByEvent:YES];
        startTool = FALSE;
      }

      break;

    case kSelectTool:
      move = FALSE;
      break;

    default:
      break;
    }

    firstMouseEvent = GSMakePoint(-1, -1);
    lastMouseEvent = GSMakePoint(-1, -1);
  }
}

- (void)flagsChanged:(NSEvent *)event {
  // only if mouse is down
  if (!GSEqualPoints(firstMouseEvent, GSMakePoint(-1, -1))) {
    switch ([GSToolsController tool]) {
    case kSelectTool:
      if (underSelection) {
        [[boloMap undoManager] undo];
        [self setUnderSelection:[GSTileRect tileRectWithTile:kSeaTile inRect:[self getSelection]]];
        [[boloMap undoManager] setActionName:@"Select"];
      }

      break;

    case kFilledEllipseTool:
      [[boloMap undoManager] undo];
      [self filledEllipseTool];
      break;

    case kFilledRectangleTool:
      [[boloMap undoManager] undo];
      [self filledRectangleTool];
      break;

    case kEllipseTool:
      [[boloMap undoManager] undo];
      [self ellipseTool];
      break;

    case kRectangleTool:
      [[boloMap undoManager] undo];
      [self rectangleTool];
      break;

    default:
      break;
    }
  }
}

- (IBAction)cut:(id)sender {
  if (underSelection) {
    NSPasteboard *pasteboard;

    // prepare pasteboard for cut
    pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];

    // copy selection to pasteboard
    [pasteboard writeObjects:[NSArray arrayWithObject:[boloMap tilesInRect:[underSelection rect]]]];

    // overwrite selection with kSeaTile
    [boloMap setTileRect:[GSTileRect tileRectWithTile:kSeaTile inRect:[underSelection rect]]];
    [boloMap setAppropriateTilesForObjectsInRect:[underSelection rect]];
    [[boloMap undoManager] setActionName:@"Cut"];
  }
}

- (IBAction)copy:(id)sender {
  if (underSelection) {
    NSPasteboard *pasteboard;

    // prepare pasteboard for copy
    pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];

    // copy selection to pasteboard
    [pasteboard writeObjects:[NSArray arrayWithObject:[boloMap tilesInRect:[underSelection rect]]]];
  }
}

- (IBAction)paste:(id)sender {
  NSPasteboard *pasteboard;
  NSArray *classArray;
  NSDictionary *options;

  pasteboard = [NSPasteboard generalPasteboard];
  classArray = [NSArray arrayWithObject:[GSTileRect class]];
  options = [NSDictionary dictionary];

  if ([pasteboard canReadObjectForClasses:classArray options:options]) {
    NSArray *objectsToPaste;
    GSTileRect *tileRect;

    objectsToPaste = [pasteboard readObjectsForClasses:classArray options:options];
    tileRect = [objectsToPaste objectAtIndex:0];

    [self setUnderSelection:[boloMap tilesInRect:[tileRect rect]]];
    [boloMap setTileRect:tileRect];
    [boloMap setAppropriateTilesForObjectsInRect:[tileRect rect]];
    [[boloMap undoManager] setActionName:@"Paste"];
  }
}

- (IBAction)delete:(id)sender {
  [boloMap setTileRect:[GSTileRect tileRectWithTile:kSeaTile inRect:underSelection == nil ? kSeaRect : [underSelection rect]]];
  [boloMap deleteObjectsInRect:underSelection == nil ? kSeaRect : [underSelection rect]];
  [[boloMap undoManager] setActionName:@"Delete"];
}

- (IBAction)selectAll:(id)sender {
  [self setUnderSelection:[GSTileRect tileRectWithTile:kSeaTile inRect:[boloMap mapRect]]];
  [[boloMap undoManager] setActionName:@"Select All"];
}

- (IBAction)clearSelection:(id)sender {
  [self setUnderSelection:nil];
  [[boloMap undoManager] setActionName:@"Clear Selection"];
}

- (IBAction)rotateLeft:(id)sender {
  if (underSelection) {
    GSTileRect *tileRect;
    tileRect = [boloMap tilesInRect:[underSelection rect]];
    [tileRect rotateLeft];

    [boloMap rotateLeftObjectsInRect:[underSelection rect]];
    [boloMap setTileRect:underSelection];
    [self setUnderSelection:[boloMap tilesInRect:[tileRect rect]]];
    [boloMap setTileRect:tileRect];
    [boloMap setAppropriateTilesForObjectsInRect:[tileRect rect]];
  }
  else {
    GSTileRect *tileRect;
    [boloMap rotateLeftObjectsInRect:kSeaRect];
    tileRect = [boloMap tilesInRect:kSeaRect];
    [tileRect rotateLeft];
    [boloMap setTileRect:tileRect];
    [boloMap setAppropriateTilesForObjectsInRect:[tileRect rect]];
  }

  [[boloMap undoManager] setActionName:@"Rotate Left"];
}

- (IBAction)rotateRight:(id)sender {
  if (underSelection) {
    GSTileRect *tileRect;
    tileRect = [boloMap tilesInRect:[underSelection rect]];
    [tileRect rotateRight];

    [boloMap rotateRightObjectsInRect:[underSelection rect]];
    [boloMap setTileRect:underSelection];
    [self setUnderSelection:[boloMap tilesInRect:[tileRect rect]]];
    [boloMap setTileRect:tileRect];
    [boloMap setAppropriateTilesForObjectsInRect:[tileRect rect]];
  }
  else {
    GSTileRect *tileRect;
    [boloMap rotateRightObjectsInRect:kSeaRect];
    tileRect = [boloMap tilesInRect:kSeaRect];
    [tileRect rotateRight];
    [boloMap setTileRect:tileRect];
    [boloMap setAppropriateTilesForObjectsInRect:[tileRect rect]];
  }

  [[boloMap undoManager] setActionName:@"Rotate Right"];
}

- (IBAction)flipHorizontal:(id)sender {
  if (underSelection) {
    GSTileRect *tileRect;

    [boloMap flipHorinzontalObjectsInRect:[underSelection rect]];
    tileRect = [boloMap tilesInRect:[underSelection rect]];
    [tileRect flipHorizontal];
    [boloMap setTileRect:tileRect];
  }
  else {
    GSTileRect *tileRect;

    [boloMap flipHorinzontalObjectsInRect:kSeaRect];
    tileRect = [boloMap tilesInRect:kSeaRect];
    [tileRect flipHorizontal];
    [boloMap setTileRect:tileRect];
  }

  [[boloMap undoManager] setActionName:@"Flip Horizontal"];
}

- (IBAction)flipVertical:(id)sender {
  if (underSelection) {
    GSTileRect *tileRect;

    [boloMap flipVerticalObjectsInRect:[underSelection rect]];
    tileRect = [boloMap tilesInRect:[underSelection rect]];
    [tileRect flipVertical];
    [boloMap setTileRect:tileRect];
  }
  else {
    GSTileRect *tileRect;

    [boloMap flipVerticalObjectsInRect:kSeaRect];
    tileRect = [boloMap tilesInRect:kSeaRect];
    [tileRect flipVertical];
    [boloMap setTileRect:tileRect];
  }

  [[boloMap undoManager] setActionName:@"Flip Vertical"];
}

- (IBAction)center:(id)sender {
  NSRect rect = GSRect2NSRect([boloMap mapRect]);
  NSSize size = [self visibleRect].size;
  [self scrollRectToVisible:NSInsetRect(rect, (NSWidth(rect) - size.width) * 0.5f, (NSHeight(rect) - size.height) * 0.5f)];
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem {
  if ([anItem action] == @selector(cut:)) {
    return underSelection != nil;
  }
  else if ([anItem action] == @selector(copy:)) {
    return underSelection != nil;
  }
  else if ([anItem action] == @selector(paste:)) {
    NSPasteboard *pasteboard;
    NSArray *classArray;
    NSDictionary *options;

    pasteboard = [NSPasteboard generalPasteboard];
    classArray = [NSArray arrayWithObject:[GSTileRect class]];
    options = [NSDictionary dictionary];

    return [pasteboard canReadObjectForClasses:classArray options:options];
  }
  else if ([anItem action] == @selector(delete:)) {
    return TRUE;
  }
  else if ([anItem action] == @selector(selectAll:)) {
    return !underSelection || !GSEqualRects([underSelection rect], [boloMap mapRect]);
  }
  else if ([anItem action] == @selector(clearSelection:)) {
    return underSelection != nil;
  }
  else if ([anItem action] == @selector(rotateLeft:)) {
    return TRUE;
  }
  else if ([anItem action] == @selector(rotateRight:)) {
    return TRUE;
  }
  else if ([anItem action] == @selector(flipHorizontal:)) {
    return TRUE;
  }
  else if ([anItem action] == @selector(flipVertical:)) {
    return TRUE;
  }
  else if ([anItem action] == @selector(center:)) {
    return TRUE;
  }

  return NO;
}

- (BOOL)isOpaque {
  return YES;
}

// converts world coordinates to world coordinates
- (GSPoint)convertScreenToWorld:(NSPoint)point {
  NSPoint view;
  GSPoint world;
  view = [self convertPoint:point fromView:nil];
  world.x = (view.x/TILE_WIDTH);
  world.y = WIDTH - (int)(view.y/TILE_WIDTH) - 1;
  return world;
}

- (NSUndoManager *)undoManager {
  return [boloMap undoManager];
}

@end

NSRect GSRect2NSRect(GSRect rect) {
 return NSMakeRect(GSMinX(rect) * TILE_WIDTH, (WIDTH - 1 - GSMaxY(rect)) * TILE_WIDTH, GSWidth(rect) * TILE_WIDTH, GSHeight(rect) * TILE_WIDTH);
}

GSRect NSRect2GSRect(NSRect rect) {
  GSRect r;
  r.origin = GSMakePoint(NSMinX(rect) / TILE_WIDTH, WIDTH - 1 - ((int)(NSMaxY(rect) / TILE_WIDTH)));
  r.size = GSMakeSize(((int)(NSMaxX(rect) / TILE_WIDTH)) - r.origin.x + 1, (WIDTH - 1 - ((int)(NSMinY(rect) / TILE_WIDTH))) - r.origin.y + 1);
 return r;
}
