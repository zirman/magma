//
//  GSPaletteController.h
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 1/2/10.
//  Copyright 2010 Robert Chrzanowski. All rights reserved.
//

#import <Cocoa/Cocoa.h>


enum {
  kWallPalette        = 0,
  kRiverPalette       = 1,
  kSwampPalette       = 2,
  kCraterPalette      = 3,
  kRoadPalette        = 4,
  kForestPalette      = 5,
  kRubblePalette      = 6,
  kGrassPalette       = 7,
  kDamagedWallPalette = 8,
  kBoatPalette        = 9,
  kMinedSwampPalette  = 10,
  kMinedCraterPalette = 11,
  kMinedRoadPalette   = 12,
  kMinedForestPalette = 13,
  kMinedRubblePalette = 14,
  kMinedGrassPalette  = 15,
  kDeepSeaPalette     = 16
} ;

@interface GSPaletteController : NSWindowController {
  IBOutlet NSMatrix *paletteMatrix;
}

+ (int)palette;
- (int)palette;

@end
