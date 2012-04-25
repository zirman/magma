//
//  bmap.h
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 10/11/09.
//  Copyright 2009 Robert Chrzanowski. All rights reserved.
//

#ifndef __BMAP__
#define __BMAP__

#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>


#define CURRENT_MAP_VERSION (1)

#define MAX_PLAYERS         (16)
#define MAX_PILLS           (16)
#define MAX_BASES           (16)
#define MAX_STARTS          (16)

#define MAX_PILL_ARMOUR     (15)
#define MAX_PILL_SPEED      (50)

#define MAX_BASE_ARMOUR     (90)
#define MAX_BASE_SHELLS     (90)
#define MAX_BASE_MINES      (90)

#define MINE_BORDER_WIDTH   (10)

#define X_MIN_MINE          (10)
#define Y_MIN_MINE          (10)
#define X_MAX_MINE          (245)
#define Y_MAX_MINE          (245)

#define MAP_FILE_IDENT      ("BMAPBOLO")
#define MAP_FILE_IDENT_LEN  (8)

#define WIDTH               (256)
#define FWIDTH              (256.0)

#define NEUTRAL             (0xff)

struct BMAP_Preamble {
  uint8_t ident[8];  // "BMAPBOLO"
  uint8_t version;   // currently 0
  uint8_t npills;    // maximum 16 (at the moment)
  uint8_t nbases;    // maximum 16 (at the moment)
  uint8_t nstarts;   // maximum 16 (at the moment)
} __attribute__((__packed__));

struct BMAP_PillInfo {
	uint8_t x;
	uint8_t y;
	uint8_t owner;   // should be 0xFF except in speciality maps
	uint8_t armour;  // range 0-15 (dead pillbox = 0, full strength = 15)
	uint8_t speed;   // typically 50. Time between shots, in 20ms units
                   // Lower values makes the pillbox start off 'angry'
} __attribute__((__packed__));

struct BMAP_BaseInfo {
	uint8_t x;
	uint8_t y;
	uint8_t owner;   // should be 0xFF except in speciality maps
	uint8_t armour;  // initial stocks of base. Maximum value 90
	uint8_t shells;  // initial stocks of base. Maximum value 90
	uint8_t mines;   // initial stocks of base. Maximum value 90
} __attribute__((__packed__));

struct BMAP_StartInfo {
  uint8_t x;
  uint8_t y;
	uint8_t dir;  // Direction towards land from this start. Range 0-15
} __attribute__((__packed__));

struct BMAP_Run {
	uint8_t datalen;  // length of the data for this run
                    // INCLUDING this 4 byte header
	uint8_t y;        // y co-ordinate of this run.
	uint8_t startx;   // first square of the run
	uint8_t endx;     // last square of run + 1
                    // (ie first deep sea square after run)
//	uint8_t data[0xFF];  // actual length of data is always much less than 0xFF
} __attribute__((__packed__));

#include "rect.h"
#include "tiles.h"
#include "images.h"


extern const GSRect kWorldRect;
extern const GSRect kSeaRect;
extern const float k2Pif;

GSTile defaultTile(int x, int y);

int readRun(size_t *y, size_t *x, struct BMAP_Run *run, void *data, GSTile tiles[][WIDTH]);
int writeRun(struct BMAP_Run run, const void *buf, GSTile tiles[][WIDTH]);

// load/save map
int loadMap(const void *buf, size_t nbytes, struct BMAP_Preamble *preamble,
            struct BMAP_PillInfo pills[], struct BMAP_BaseInfo bases[],
            struct BMAP_StartInfo starts[], GSTile tiles[][WIDTH]);

ssize_t saveMap(void **data, struct BMAP_Preamble *preamble,
                struct BMAP_PillInfo pills[], struct BMAP_BaseInfo bases[],
                struct BMAP_StartInfo starts[], GSTile tiles[][WIDTH]);

GSTile appropriateTileForPill(GSTile tile);
GSTile appropriateTileForBase(GSTile tile);
GSTile appropriateTileForStart(GSTile tile);

#ifndef MIN
#define MIN(x, y) (((x) < (y)) ? (x) : (y))
#endif

#ifndef MAX
#define MAX(x, y) (((x) > (y)) ? (x) : (y))
#endif

#endif // __BMAP__
