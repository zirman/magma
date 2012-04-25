//
//  GSXBoloMapView.h
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 12/29/09.
//  Copyright 2009 Robert Chrzanowski. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "bmap.h"


#define TILE_WIDTH          (16.0)

@class GSXBoloMap, GSTileRect;

@interface GSXBoloMapView : NSView {
  IBOutlet GSXBoloMap *boloMap;

  // variables shared by most tools
  GSPoint firstMouseEvent;
  GSPoint lastMouseEvent;

  // start tool variables
  BOOL startTool;
  struct BMAP_StartInfo start;

  // selection tool variables
  GSTileRect *underSelection;
  BOOL move;
}

// menu actions
- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)selectAll:(id)sender;
- (IBAction)clearSelection:(id)sender;
- (IBAction)rotateLeft:(id)sender;
- (IBAction)rotateRight:(id)sender;
- (IBAction)flipHorizontal:(id)sender;
- (IBAction)flipVertical:(id)sender;
- (IBAction)center:(id)sender;

@end


NSRect GSRect2NSRect(GSRect rect);
GSRect NSRect2GSRect(NSRect rect);
