//
//  tiles.h
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 10/11/09.
//  Copyright 2009 Robert Chrzanowski. All rights reserved.
//

#ifndef __TILES__
#define __TILES__

#include <stdint.h>


#define WIDTH (256)

enum {
  kWallTile         = 0,
  kRiverTile        = 1,
  kSwampTile        = 2,
  kCraterTile       = 3,
  kRoadTile         = 4,
  kForestTile       = 5,
  kRubbleTile       = 6,
  kGrassTile        = 7,
  kDamagedWallTile  = 8,
  kBoatTile         = 9,

  kMinedSwampTile   = 10,
  kMinedCraterTile  = 11,
  kMinedRoadTile    = 12,
  kMinedForestTile  = 13,
  kMinedRubbleTile  = 14,
  kMinedGrassTile   = 15,

  kSeaTile          = 16,
  kMinedSeaTile     = 17,
  kTokenTile        = 18  // used in flood fill algorithm
} ;

typedef uint8_t GSTile;

int isForestLikeTile(GSTile tiles[][WIDTH], int x, int y);
int isCraterLikeTile(GSTile tiles[][WIDTH], int x, int y);
int isRoadLikeTile(GSTile tiles[][WIDTH], int x, int y);
int isWaterLikeToLandTile(GSTile tiles[][WIDTH], int x, int y);
int isWaterLikeToWaterTile(GSTile tiles[][WIDTH], int x, int y);
int isWallLikeTile(GSTile tiles[][WIDTH], int x, int y);
int isSeaLikeTile(GSTile tiles[][WIDTH], int x, int y);
int isMinedTile(GSTile tiles[][WIDTH], int x, int y);

#endif  // __TILES__
