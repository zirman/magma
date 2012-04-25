//
//  GSPaletteController.m
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 1/2/10.
//  Copyright 2010 Robert Chrzanowski. All rights reserved.
//

#import "GSPaletteController.h"


static GSPaletteController *controller = nil;

@implementation GSPaletteController

+ (int)palette {
  return [controller palette];
}

- (id)init {
  self = [super init];

  if (self) {
    controller = self;
  }

  return self;
}

- (void)dealloc {
  if (controller == self) {
    controller = nil;
  }

  [super dealloc];
}

- (int)palette {
  return [[paletteMatrix selectedCell] tag];
}

- (NSString *)windowFrameAutosaveName {
  return @"GSPalettePanel";
}

@end
