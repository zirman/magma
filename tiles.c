//
//  tiles.c
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 10/11/09.
//  Copyright 2009 Robert Chrzanowski. All rights reserved.
//

#include "tiles.h"
#include "bmap.h"


int isForestLikeTile(GSTile tiles[][WIDTH], int x, int y) {
  if (x < 0 || x >= 256 || y < 0 || y >= 256) {
    return 1;
  }
  else {
    switch (tiles[y][x]) {
    case kForestTile:
    case kMinedForestTile:
      return 1;

    default:
      return 0;
    }
  }
}

int isCraterLikeTile(GSTile tiles[][WIDTH], int x, int y) {
  if (x < 0 || x >= 256 || y < 0 || y >= 256) {
    return 1;
  }
  else {
    switch (tiles[y][x]) {
    case kCraterTile:
    case kRiverTile:
    case kSeaTile:
    case kMinedCraterTile:
    case kMinedSeaTile:
      return 1;

    default:
      return 0;
    }
  }
}

int isRoadLikeTile(GSTile tiles[][WIDTH], int x, int y) {
  if (x < 0 || x >= 256 || y < 0 || y >= 256) {
    return 1;
  }
  else {
    switch (tiles[y][x]) {
    case kRoadTile:
    case kMinedRoadTile:
      return 1;

    default:
      return 0;
    }
  }
}

int isWaterLikeToLandTile(GSTile tiles[][WIDTH], int x, int y) {
  if (x < 0 || x >= 256 || y < 0 || y >= 256) {
    return 1;
  }
  else {
    switch (tiles[y][x]) {
    case kRiverTile:
    case kBoatTile:
    case kSeaTile:
    case kMinedSeaTile:
      return 1;

    default:
      return 0;
    }
  }
}

int isWaterLikeToWaterTile(GSTile tiles[][WIDTH], int x, int y) {
  if (x < 0 || x >= 256 || y < 0 || y >= 256) {
    return 1;
  }
  else {
    switch (tiles[y][x]) {
    case kRoadTile:
    case kRiverTile:
    case kBoatTile:
    case kSeaTile:
    case kCraterTile:
    case kMinedRoadTile:
    case kMinedSeaTile:
    case kMinedCraterTile:
      return 1;

    default:
      return 0;
    }
  }
}

int isWallLikeTile(GSTile tiles[][WIDTH], int x, int y) {
  if (x < 0 || x >= 256 || y < 0 || y >= 256) {
    return 1;
  }
  else {
    switch (tiles[y][x]) {
    case kRubbleTile:
    case kDamagedWallTile:
    case kWallTile:
    case kMinedRubbleTile:
      return 1;

    default:
      return 0;
    }
  }
}

int isSeaLikeTile(GSTile tiles[][WIDTH], int x, int y) {
  if (x < 0 || x >= 256 || y < 0 || y >= 256) {
    return 1;
  }
  else {
    switch (tiles[y][x]) {
    case kSeaTile:
    case kMinedSeaTile:
      return 1;
  
    default:
      return 0;
    }
  }
}

int isMinedTile(GSTile tiles[][WIDTH], int x, int y) {
  if (x < 0 || x >= 256 || y < 0 || y >= 256) {
    return 1;
  }
  else {
    switch (tiles[y][x]) {
    case kMinedSwampTile:
    case kMinedCraterTile:
    case kMinedRoadTile:
    case kMinedForestTile:
    case kMinedRubbleTile:
    case kMinedGrassTile:
    case kMinedSeaTile:
      return 1;

    default:
      return 0;
    }
  }
}
