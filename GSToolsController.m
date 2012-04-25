//
//  GSToolsController.m
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 12/31/09.
//  Copyright 2009 Robert Chrzanowski. All rights reserved.
//

#import "GSToolsController.h"


static GSToolsController *controller = nil;

@implementation GSToolsController

+ (int)tool {
  return [controller tool];
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

- (int)tool {
  return [[toolMatrix selectedCell] tag];
}

- (NSString *)windowFrameAutosaveName {
  return @"GSToolsPanel";
}

@end
