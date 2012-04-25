//
//  rect.h
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 11/11/04.
//  Copyright 2004 Robert Chrzanowski. All rights reserved.
//

#ifndef __RECT__
#define __RECT__

typedef struct GSPoint {
  int x;
  int y;
} GSPoint;

typedef struct GSRange {
  int origin;
  int size;
} GSRange;

typedef struct GSSize {
  int width;
  int height;
} GSSize;

typedef struct GSRect {
  GSPoint origin;
  GSSize size;
} GSRect;

GSPoint GSMakePoint(int x, int y);
int GSEqualPoints(GSPoint p1, GSPoint p2);

GSRange GSMakeRange(int origin, unsigned size);
int GSIntersectsRange(GSRange r1, GSRange r2);
int GSContainsRange(GSRange r1, GSRange r2);
int GSLocationInRange(GSRange r, int x);

GSSize GSMakeSize(unsigned width, unsigned height);
int GSEqualSizes(GSSize s1, GSSize s2);

GSRect GSMakeRect(int x, int y, unsigned w, unsigned h);
int GSHeight(GSRect r);
int GSWidth(GSRect r);
int GSMaxX(GSRect r);
int GSMaxY(GSRect r);
int GSMidX(GSRect r);
int GSMidY(GSRect r);
int GSMinX(GSRect r);
int GSMinY(GSRect r);
GSRect GSOffsetRect(GSRect r, int dx, int dy);
int GSPointInRect(GSRect r, GSPoint p);
GSRect GSUnionRect(GSRect r1, GSRect r2);
int GSContainsRect(GSRect r1, GSRect r2);
int GSEqualRects(GSRect r1, GSRect r2);
int GSIsEmptyRect(GSRect r);
GSRect GSInsetRect(GSRect r, int dx, int dy);
GSRect GSIntersectionRect(GSRect r1, GSRect r2);
int GSIntersectsRect(GSRect r1, GSRect r2);
void GSSplitRect(GSRect r, int x, int y, GSRect *rects);
void GSSubtractRect(GSRect r1, GSRect r2, GSRect *rects);

#endif  // __RECT__
