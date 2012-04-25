//
//  bmap.c
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 10/11/09.
//  Copyright 2009 Robert Chrzanowski. All rights reserved.
//

#include "bmap.h"
#include "tiles.h"
#include "errchk.h"

#include <stdlib.h>
#include <string.h>
#include <assert.h>


const GSRect kWorldRect = { { 0, 0 }, { WIDTH, WIDTH } };
const GSRect kSeaRect = { { MINE_BORDER_WIDTH, MINE_BORDER_WIDTH }, { WIDTH - (MINE_BORDER_WIDTH * 2), WIDTH - (MINE_BORDER_WIDTH * 2) } };
const float k2Pif = 6.283185307179586;

static ssize_t mapSize(const struct BMAP_Preamble *preamble, const struct BMAP_PillInfo pills[], const struct BMAP_BaseInfo bases[], const struct BMAP_StartInfo starts[], GSTile tiles[][WIDTH]);
static int readNibble(const void *buf, size_t i);
static void writeNibble(void *buf, size_t i, int nibble);

int readRun(size_t *y, size_t *x, struct BMAP_Run *run, void *data, GSTile tiles[][WIDTH]) {
  int nibs, len, i, retval;

TRY
  while (*y < WIDTH) {  // find the beginning of a run
    while (*x < WIDTH) {
      if (tiles[*y][*x] != defaultTile(*x, *y)) {
        nibs = 0;
        run->y = *y;
        run->startx = *x;

        do {
          // read the run
          if (*x + 1 < WIDTH && tiles[*y][*x + 1] == tiles[*y][*x]) {  // sequence of like tiles
            for (len = 2; *x + len < WIDTH && len < 9 && tiles[*y][*x + len] == tiles[*y][*x]; len++);

            writeNibble(data, nibs++, len + 6);
            writeNibble(data, nibs++, tiles[*y][*x]);
          }
          else {  // sequence of different tiles
            len = 1;

            while (
              (*x + len < WIDTH) && (len < 8) &&
              (tiles[*y][*x + len] != defaultTile(*x + len, *y)) &&
              (tiles[*y][*x + len] != tiles[*y][*x + len + 1])
            ) {
              len++;
            }

            writeNibble(data, nibs++, len - 1);

            for (i = 0; i < len; i++) {
              writeNibble(data, nibs++, tiles[*y][*x + i]);
            }
          }

          *x += len;
        } while (tiles[*y][*x] != defaultTile(*x, *y));

        run->endx = *x;
        run->datalen = sizeof(struct BMAP_Run) + (nibs + 1)/2;

        retval = 0;
        SUCCESS
      }

      (*x)++;
    }

    (*y)++;
    *x = 0;
  }

  // write the last run
  run->datalen = 4;
  run->y = 0xff;
  run->startx = 0xff;
  run->endx = 0xff;

  retval = 1;

CLEANUP
  switch (errno) {
  case 0:
    RETURN(retval)

  default:
    RETERR(-1)
  }
END
}

int writeRun(struct BMAP_Run run, const void *buf, GSTile tiles[][WIDTH]) {
  int i;
  int x;
  int offset;
  int serverTileType;

TRY
  x = run.startx;
  offset = 0;

  while (x < run.endx) {
    int len;

    if (sizeof(struct BMAP_Run) + (offset + 2)/2 > run.datalen) LOGFAIL(ECORFILE)

    len = readNibble(buf, offset++);

    if (len >= 0 && len <= 7) {  // this is a sequence of different tiles
      len += 1;

      if (sizeof(struct BMAP_Run) + (offset + len + 1)/2 > run.datalen) {
        LOGFAIL(ECORFILE)
      }

      for (i = 0; i < len; i++) {
        if ((serverTileType = readNibble(buf, offset++)) == -1) {
          LOGFAIL(ECORFILE)
        }

        tiles[run.y][x++] = serverTileType;
      }
    }
    else if (len >= 8 && len <= 15) {  // this is a sequence of like tiles
      len -= 6;

      if (sizeof(struct BMAP_Run) + (offset + 2)/2 > run.datalen) {
        LOGFAIL(ECORFILE)
      }

      if ((serverTileType = readNibble(buf, offset++)) == -1) {
        LOGFAIL(ECORFILE)
      }

      for (i = 0; i < len; i++) {
        tiles[run.y][x++] = serverTileType;
      }
    }
    else {
      LOGFAIL(ECORFILE)
    }
  }

  if (sizeof(struct BMAP_Run) + (offset + 1)/2 != run.datalen) {
    LOGFAIL(ECORFILE)
  }

CLEANUP
ERRHANDLER(0, -1)
END
}

int readNibble(const void *buf, size_t i) {
  return i%2 ? *(uint8_t *)(buf + i/2) & 0x0f : (*(uint8_t *)(buf + i/2) & 0xf0) >> 4;
}

void writeNibble(void *buf, size_t i, int nibble) {
  *(uint8_t *)(buf + i/2) = i%2 ? (*(uint8_t *)(buf + i/2) & 0xf0) ^ (((uint8_t)nibble) & 0x0f) : (*(uint8_t *)(buf + i/2) & 0x0f) ^ ((((uint8_t)nibble) & 0x0f) << 4);
}

GSTile defaultTile(int x, int y) {
  return (y >= Y_MIN_MINE && y <= Y_MAX_MINE && x >= X_MIN_MINE && x <= X_MAX_MINE) ? kSeaTile : kMinedSeaTile;
}

int loadMap(const void *buf, size_t nbytes, struct BMAP_Preamble *preamble, struct BMAP_PillInfo pills[], struct BMAP_BaseInfo bases[], struct BMAP_StartInfo starts[], GSTile tiles[][WIDTH]) {
  int i, x, y;
  const void *runData;
  int runDataLen;
  int offset;

TRY
  // wipe the map clean
  for (y = 0; y < WIDTH; y++) {
    for (x = 0; x < WIDTH; x++) {
      tiles[y][x] = defaultTile(x, y);
    }
  }

  if (nbytes < sizeof(struct BMAP_Preamble)) LOGFAIL(ECORFILE)

  bcopy(buf, preamble, sizeof(struct BMAP_Preamble));
  buf += sizeof(struct BMAP_Preamble);

  if (strncmp((char *)preamble->ident, MAP_FILE_IDENT, MAP_FILE_IDENT_LEN) != 0)
    LOGFAIL(ECORFILE)

  if (preamble->version != CURRENT_MAP_VERSION) LOGFAIL(EINCMPAT)

  if (preamble->npills > MAX_PILLS) LOGFAIL(ECORFILE)

  if (preamble->nbases > MAX_BASES) LOGFAIL(ECORFILE)

  if (preamble->nstarts > MAX_STARTS) LOGFAIL(ECORFILE)

  if (nbytes <
      sizeof(struct BMAP_Preamble) +
      preamble->npills*sizeof(struct BMAP_PillInfo) +
      preamble->nbases*sizeof(struct BMAP_BaseInfo) +
      preamble->nstarts*sizeof(struct BMAP_StartInfo))
    LOGFAIL(ECORFILE)

  bcopy(buf, pills, preamble->npills * sizeof(struct BMAP_PillInfo));
  buf += preamble->npills * sizeof(struct BMAP_PillInfo);

  bcopy(buf, bases, preamble->nbases * sizeof(struct BMAP_BaseInfo));
  buf += preamble->nbases * sizeof(struct BMAP_BaseInfo);

  bcopy(buf, starts, preamble->nstarts * sizeof(struct BMAP_StartInfo));
  buf += preamble->nstarts * sizeof(struct BMAP_StartInfo);

  runData = buf;
  runDataLen =
    nbytes - (sizeof(struct BMAP_Preamble) +
              preamble->npills*sizeof(struct BMAP_PillInfo) +
              preamble->nbases*sizeof(struct BMAP_BaseInfo) +
              preamble->nstarts*sizeof(struct BMAP_StartInfo));

  offset = 0;

  for (;;) {  // write runs
    struct BMAP_Run run;

    if (offset + sizeof(struct BMAP_Run) > runDataLen) {
      break;  // ran out of bytes
//      LOGFAIL(ECORFILE)
    }

    run = *(struct BMAP_Run *)(runData + offset);

    // if last run
    if (run.datalen == 4 && run.y == 0xff && run.startx == 0xff && run.endx == 0xff) {
      if (offset + run.datalen != runDataLen) {
        // left over bytes extra game data??? ignore for now
      }

      break;
    }

    if (offset + run.datalen > runDataLen) LOGFAIL(ECORFILE)
    if (writeRun(run, runData + offset + sizeof(struct BMAP_Run), tiles) == -1) LOGFAIL(errno)
    offset += run.datalen;
  }

  // fix invalid pill info
  for (i = 0; i < preamble->npills; i++) {
    int j;

    // delete pills out of bounds
    if (!GSPointInRect(kSeaRect, GSMakePoint(pills[i].x, pills[i].y))) {
      preamble->npills--;

      for (j = i; j < preamble->npills; j--) {
        pills[j] = pills[j + 1];
      }
    }

    // delete pills under bases
    for (j = 0; j < preamble->nbases; j++) {
      if (GSEqualPoints(GSMakePoint(bases[j].x, bases[j].y), GSMakePoint(pills[i].x, pills[i].y))) {
        preamble->npills--;

        for (j = i; j < preamble->npills; j--) {
          pills[j] = pills[j + 1];
        }
      }
    }

    // delete pills under starts
    for (j = 0; j < preamble->nstarts; j++) {
      if (GSEqualPoints(GSMakePoint(starts[j].x, starts[j].y), GSMakePoint(pills[i].x, pills[i].y))) {
        preamble->npills--;

        for (j = i; j < preamble->npills; j--) {
          pills[j] = pills[j + 1];
        }
      }
    }

    if (!(pills[i].owner == NEUTRAL || pills[i].owner < MAX_PLAYERS)) {
      pills[i].owner = NEUTRAL;
    }

    if (pills[i].armour > MAX_PILL_ARMOUR) {
      pills[i].armour = MAX_PILL_ARMOUR;
    }

    if (pills[i].speed > MAX_PILL_SPEED) {
      pills[i].speed = MAX_PILL_SPEED;
    }

    tiles[pills[i].y][pills[i].x] = appropriateTileForBase(tiles[pills[i].y][pills[i].x]);
  }

  // fix invalid base info
  for (i = 0; i < preamble->nbases; i++) {
    int j;

    // delete base out of bounds
    if (!GSPointInRect(kSeaRect, GSMakePoint(bases[i].x, bases[i].y))) {
      preamble->nbases--;

      for (j = i; j < preamble->nbases; j--) {
        bases[j] = bases[j + 1];
      }
    }

    // delete base under starts
    for (j = 0; j < preamble->nstarts; j++) {
      if (GSEqualPoints(GSMakePoint(starts[j].x, starts[j].y), GSMakePoint(bases[i].x, bases[i].y))) {
        preamble->nbases--;

        for (j = i; j < preamble->nbases; j--) {
          bases[j] = bases[j + 1];
        }
      }
    }

    if (!(bases[i].owner == NEUTRAL || bases[i].owner < MAX_PLAYERS)) {
      bases[i].owner = NEUTRAL;
    }

    if (bases[i].armour > MAX_BASE_ARMOUR) {
      bases[i].armour = MAX_BASE_ARMOUR;
    }

    if (bases[i].shells > MAX_BASE_SHELLS) {
      bases[i].shells = MAX_BASE_SHELLS;
    }

    if (bases[i].mines > MAX_BASE_MINES) {
      bases[i].mines = MAX_BASE_MINES;
    }

    tiles[bases[i].y][bases[i].x] = appropriateTileForBase(tiles[bases[i].y][bases[i].x]);
  }

  // fix invalid start info
  for (i = 0; i < preamble->nstarts; i++) {
    int j;

    // delete base out of bounds
    if (!GSPointInRect(kSeaRect, GSMakePoint(starts[i].x, starts[i].y))) {
      preamble->nstarts--;

      for (j = i; j < preamble->nstarts; j--) {
        starts[j] = starts[j + 1];
      }
    }

    starts[i].dir %= 16;

    tiles[starts[i].y][starts[i].x] = appropriateTileForStart(tiles[starts[i].y][starts[i].x]);
  }

CLEANUP
ERRHANDLER(0, -1)
END
}

ssize_t saveMap(void **data, struct BMAP_Preamble *preamble, struct BMAP_PillInfo pills[], struct BMAP_BaseInfo bases[], struct BMAP_StartInfo starts[], GSTile tiles[][WIDTH]) {
  size_t y, x;
  void *runData;
  struct BMAP_Run *run;
  int offset;
  ssize_t size;
  void *buf;

  *data = NULL;

TRY
  // find the size of the map
  if ((size = mapSize(preamble, pills, bases, starts, tiles)) == -1) LOGFAIL(errno)

  // allocate memory
  if ((buf = malloc(size)) == NULL) LOGFAIL(errno)
  *data = buf;

  // zero the bytes
  bzero(*data, size);

  // copy structs
  bcopy(preamble, buf, sizeof(struct BMAP_Preamble));
  buf += sizeof(struct BMAP_Preamble);

  bcopy(pills, buf, preamble->npills * sizeof(struct BMAP_PillInfo));
  buf += preamble->npills * sizeof(struct BMAP_PillInfo);

  bcopy(bases, buf, preamble->nbases * sizeof(struct BMAP_BaseInfo));
  buf += preamble->nbases * sizeof(struct BMAP_BaseInfo);

  bcopy(starts, buf, preamble->nstarts * sizeof(struct BMAP_StartInfo));
  buf += preamble->nstarts * sizeof(struct BMAP_StartInfo);

  runData = buf;
  offset = 0;
  y = 0;
  x = 0;

  while (y < WIDTH && x < WIDTH) {
    int r;

    run = runData + offset;
    if ((r = readRun(&y, &x, run, run + 1, tiles)) == -1) LOGFAIL(errno)
    if (r == 1) break;
    offset += run->datalen;
  }

  data = NULL;

CLEANUP
  if (data != NULL && *data != NULL) {
    free(*data);
    *data = NULL;
  }

ERRHANDLER(size, -1)
END
}

GSTile appropriateTileForPill(GSTile tile) {
  switch (tile) {
  case kSeaTile:
  case kBoatTile:
  case kRiverTile:
  case kMinedSeaTile:
    return kSwampTile;

  case kWallTile:
  case kDamagedWallTile:
    return kRubbleTile;

  case kForestTile:
  case kMinedForestTile:
    return kGrassTile;

  case kMinedSwampTile:
    return kSwampTile;

  case kMinedCraterTile:
    return kCraterTile;

  case kMinedRoadTile:
    return kRoadTile;

  case kMinedRubbleTile:
    return kRubbleTile;

  case kMinedGrassTile:
    return kGrassTile;

  default:
    return tile;
  }
}

GSTile appropriateTileForBase(GSTile tile) {
  switch (tile) {
  case kSeaTile:
  case kBoatTile:
  case kRiverTile:
  case kMinedSeaTile:
    return kSwampTile;

  case kWallTile:
  case kDamagedWallTile:
    return kRubbleTile;

  case kForestTile:
  case kMinedForestTile:
    return kGrassTile;

  case kMinedSwampTile:
    return kSwampTile;

  case kMinedCraterTile:
    return kCraterTile;

  case kMinedRoadTile:
    return kRoadTile;

  case kMinedRubbleTile:
    return kRubbleTile;

  case kMinedGrassTile:
    return kGrassTile;

  default:
    return tile;
  }
}

GSTile appropriateTileForStart(GSTile tile) {
  return kSeaTile;
}

ssize_t mapSize(const struct BMAP_Preamble *preamble, const struct BMAP_PillInfo pills[], const struct BMAP_BaseInfo bases[], const struct BMAP_StartInfo starts[], GSTile tiles[][WIDTH]) {
  size_t x, y, len;

  assert(preamble != NULL);
  assert(pills != NULL);
  assert(bases != NULL);
  assert(starts != NULL);

TRY
  x = 0;
  y = 0;
  len =
    sizeof(struct BMAP_Preamble) +
    preamble->npills*sizeof(struct BMAP_PillInfo) +
    preamble->nbases*sizeof(struct BMAP_BaseInfo) +
    preamble->nstarts*sizeof(struct BMAP_StartInfo);

  for (;;) {
    ssize_t r;
    struct BMAP_Run run;
    char buf[256];
    
    if ((r = readRun(&y, &x, &run, buf, tiles)) == -1) LOGFAIL(errno)
    len += run.datalen;
    // if this is the last run
    if (r == 1) SUCCESS
  }

CLEANUP
ERRHANDLER(len, -1)
END
}
