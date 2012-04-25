//
//  rect.c
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski on 11/11/04.
//  Copyright 2004 Robert Chrzanowski. All rights reserved.
//

#include "rect.h"
#include "errchk.h"


GSPoint GSMakePoint(int x, int y) {
  GSPoint p;
  p.x = x;
  p.y = y;
  return p;
}

int GSEqualPoints(GSPoint p1, GSPoint p2) {
  return p1.x == p2.x && p1.y == p2.y;
}

GSRange GSMakeRange(int origin, unsigned size) {
  GSRange n;
  n.origin = origin;
  n.size = size;
  return n;
}

int GSIntersectsRange(GSRange r1, GSRange r2) {
  if (r1.origin < r2.origin) {
    if (r1.origin + r1.size > r2.origin) {
      return 1;
    }
  }
  else {
    if (r2.origin + r2.size > r1.origin) {
      return 1;
    }
  }

  return 0;
}

int GSContainsRange(GSRange r1, GSRange r2) {
  return r1.origin <= r2.origin && r1.origin + r1.size >= r2.origin + r2.size;
}

int GSLocationInRange(GSRange r, int x) {
  return r.origin <= x && r.origin + r.size < x;
}

GSSize GSMakeSize(unsigned w, unsigned h) {
  GSSize s;
  s.width = w;
  s.height = h;
  return s;
}

int GSEqualSizes(GSSize s1, GSSize s2) {
  return s1.width == s2.width && s1.height == s2.height;
}

GSRect GSMakeRect(int x, int y, unsigned w, unsigned h) {
  GSRect r;
  r.origin.x = x;
  r.origin.y = y;
  r.size.width = w;
  r.size.height = h;
  return r;
}

int GSHeight(GSRect r) {
  return r.size.height;
}

int GSWidth(GSRect r) {
  return r.size.width;
}

int GSMaxX(GSRect r) {
  return r.origin.x + r.size.width - 1;
}

int GSMaxY(GSRect r) {
  return r.origin.y + r.size.height - 1;
}

int GSMidX(GSRect r) {
  return r.origin.x + (r.size.width/2);
}

int GSMidY(GSRect r) {
  return r.origin.y + (r.size.height/2);
}

int GSMinX(GSRect r) {
  return r.origin.x;
}

int GSMinY(GSRect r) {
  return r.origin.y;
}

GSRect GSOffsetRect(GSRect r, int dx, int dy) {
  GSRect n;
  n.origin.x = r.origin.x + dx;
  n.origin.y = r.origin.y + dy;
  n.size.width = r.size.width;
  n.size.height = r.size.height;
  return n;
}

int GSPointInRect(GSRect r, GSPoint p) {
  return (r.origin.x <= p.x) && (r.origin.y <= p.y) && ((r.origin.x + r.size.width) > p.x) && ((r.origin.y + r.size.height) > p.y);
}

GSRect GSUnionRect(GSRect r1, GSRect r2) {
  GSRect n;
  n.origin.x = r1.origin.x < r2.origin.x ? r1.origin.x : r2.origin.x;
  n.origin.y = r1.origin.y < r2.origin.y ? r1.origin.y : r2.origin.y;
  n.size.width =
    (r1.origin.x + r1.size.width > r2.origin.x + r2.size.width ? r1.origin.x + r1.size.width : r2.origin.x + r2.size.width) - n.origin.x;
  n.size.height =
    (r1.origin.y + r1.size.height > r2.origin.y + r2.size.height ? r1.origin.y + r1.size.height : r2.origin.y + r2.size.height) - n.origin.y;
  return n;
}

int GSContainsRect(GSRect r1, GSRect r2) {
  return
    GSContainsRange(GSMakeRange(r1.origin.x, r1.size.width), GSMakeRange(r2.origin.x, r2.size.width)) &&
    GSContainsRange(GSMakeRange(r1.origin.y, r1.size.height), GSMakeRange(r2.origin.y, r2.size.height));
}

int GSEqualRects(GSRect r1, GSRect r2) {
  return r1.origin.x == r2.origin.x && r1.origin.y == r2.origin.y && r1.size.width == r2.size.width && r1.size.height == r2.size.height;
}

int GSIsEmptyRect(GSRect r) {
  return r.size.width <= 0 || r.size.height <= 0;
}

GSRect GSInsetRect(GSRect r, int dx, int dy) {
  GSRect n;
  n.origin.x = r.origin.x + dx;
  n.origin.y = r.origin.y + dy;
  n.size.width = r.size.width - dx*2;
  n.size.height = r.size.height - dy*2;
  return n;
}

GSRect GSIntersectionRect(GSRect r1, GSRect r2) {
  GSRect n;
  n.origin.x = r1.origin.x > r2.origin.x ? r1.origin.x : r2.origin.x;
  n.origin.y = r1.origin.y > r2.origin.y ? r1.origin.y : r2.origin.y;
  n.size.width =
    (r1.origin.x + r1.size.width < r2.origin.x + r2.size.width ? r1.origin.x + r1.size.width : r2.origin.x + r2.size.width) - n.origin.x;
  n.size.height =
    (r1.origin.y + r1.size.height < r2.origin.y + r2.size.height ? r1.origin.y + r1.size.height : r2.origin.y + r2.size.height) - n.origin.y;
  return n;
}

int GSIntersectsRect(GSRect r1, GSRect r2) {
  return 
    GSIntersectsRange(GSMakeRange(r1.origin.x, r1.size.width), GSMakeRange(r2.origin.x, r2.size.width)) &&
    GSIntersectsRange(GSMakeRange(r1.origin.y, r1.size.height), GSMakeRange(r2.origin.y, r2.size.height));
}

void GSSplitRect(GSRect r, int x, int y, GSRect *rects) {
  rects[0] = GSMakeRect(r.origin.x, r.origin.y, x - r.origin.x, y - r.origin.y);
  rects[1] = GSMakeRect(x, r.origin.y, (r.origin.x + r.size.width) - x, y - r.origin.y);
  rects[2] = GSMakeRect(r.origin.x, y, x - r.origin.x, (r.origin.y + r.size.height) - y);
  rects[3] = GSMakeRect(x, y, (r.origin.x + r.size.width) - x, (r.origin.y + r.size.height) - y);
}

void GSSubtractRect(GSRect r1, GSRect r2, GSRect *rects) {
  int minx, miny, maxx, maxy;
  int lxly, lxhy, hxly, hxhy;
//  int c;

  minx = r2.origin.x;
  miny = r2.origin.y;
  maxx = r2.origin.x + r2.size.width;
  maxy = r2.origin.y + r2.size.height;

  lxly = GSPointInRect(r1, GSMakePoint(minx - 1, miny - 1));
  lxhy = GSPointInRect(r1, GSMakePoint(minx - 1, maxy));
  hxly = GSPointInRect(r1, GSMakePoint(maxx, miny - 1));
  hxhy = GSPointInRect(r1, GSMakePoint(maxx, maxy));

  if (lxly && !lxhy && !hxly && !hxhy) {
    rects[0] = GSMakeRect(r1.origin.x, r1.origin.y, r1.size.width, miny - r1.origin.y);
    rects[1] = GSMakeRect(r1.origin.x, miny, minx - r1.origin.x, (r1.origin.y + r1.size.height) - miny);
    rects[2] = GSMakeRect(0, 0, 0, 0);
    rects[3] = GSMakeRect(0, 0, 0, 0);
  }
  else if (!lxly && lxhy && !hxly && !hxhy) {
    rects[0] = GSMakeRect(r1.origin.x, r1.origin.y, minx - r1.origin.x, r1.size.height);
    rects[1] = GSMakeRect(minx, maxy, (r1.origin.x + r1.size.width) - minx, (r1.origin.y + r1.size.height) - maxy);
    rects[2] = GSMakeRect(0, 0, 0, 0);
    rects[3] = GSMakeRect(0, 0, 0, 0);
  }
  else if (!lxly && !lxhy && hxly && !hxhy) {
    rects[0] = GSMakeRect(r1.origin.x, r1.origin.y, r1.size.width, miny - r1.origin.y);
    rects[1] = GSMakeRect(maxx, miny, (r1.origin.x + r1.size.width) - maxx, (r1.origin.y + r1.size.height) - miny);
    rects[2] = GSMakeRect(0, 0, 0, 0);
    rects[3] = GSMakeRect(0, 0, 0, 0);
  }
  else if (!lxly && !lxhy && !hxly && hxhy) {
    rects[0] = GSMakeRect(maxx, r1.origin.y, (r1.origin.x + r1.size.width) - maxx, r1.size.height);
    rects[1] = GSMakeRect(r1.origin.x, maxy, maxx - r1.origin.x, (r1.origin.y + r1.size.height) - maxy);
    rects[2] = GSMakeRect(0, 0, 0, 0);
    rects[3] = GSMakeRect(0, 0, 0, 0);
  }
  else if (lxly && !lxhy && hxly && !hxhy) {
    rects[0] = GSMakeRect(r1.origin.x, r1.origin.y, r1.size.width, miny - r1.origin.y);
    rects[1] = GSMakeRect(r1.origin.x, miny, minx - r1.origin.x, (r1.origin.y + r1.size.height) - miny);
    rects[2] = GSMakeRect(maxx, miny, (r1.origin.x + r1.size.width) - maxx, (r1.origin.y + r1.size.height) - miny);
    rects[3] = GSMakeRect(0, 0, 0, 0);
  }
  else if (!lxly && !lxhy && hxly && hxhy) {
    rects[0] = GSMakeRect(r1.origin.x, r1.origin.y, r1.size.width, miny - r1.origin.y);
    rects[1] = GSMakeRect(maxx, miny, (r1.origin.x + r1.size.width) - maxx, (r1.origin.y + r1.size.height) - miny);
    rects[2] = GSMakeRect(r1.origin.x, maxy, maxx - r1.origin.x, (r1.origin.y + r1.size.height) - maxy);
    rects[3] = GSMakeRect(0, 0, 0, 0);
  }
  else if (!lxly && lxhy && !hxly && hxhy) {
    rects[0] = GSMakeRect(r1.origin.x, r1.origin.y, minx - r1.origin.x, r1.size.height);
    rects[1] = GSMakeRect(maxx, r1.origin.y, (r1.origin.x + r1.size.width) - maxx, r1.size.height);
    rects[2] = GSMakeRect(minx, maxy, maxx - minx, (r1.origin.y + r1.size.height) - maxy);
    rects[3] = GSMakeRect(0, 0, 0, 0);
  }
  else if (lxly && lxhy && !hxly && !hxhy) {
    rects[0] = GSMakeRect(r1.origin.x, r1.origin.y, r1.size.width, miny - r1.origin.y);
    rects[1] = GSMakeRect(r1.origin.x, miny, minx - r1.origin.x, (r1.origin.y + r1.size.height) - miny);
    rects[2] = GSMakeRect(minx, maxy, (r1.origin.x + r1.size.width) - minx, (r1.origin.y + r1.size.height) - maxy);
    rects[3] = GSMakeRect(0, 0, 0, 0);
  }
  else if (lxly && lxhy && hxly && hxhy) {
    rects[0] = GSMakeRect(r1.origin.x, r1.origin.y, maxx - r1.origin.x, miny - r1.origin.y);
    rects[1] = GSMakeRect(r1.origin.x, miny, minx - r1.origin.x, (r1.origin.y + r1.size.height) - miny);
    rects[2] = GSMakeRect(minx, maxy, (r1.origin.x + r1.size.width) - minx, (r1.origin.y + r1.size.height) - maxy);
    rects[3] = GSMakeRect(maxx, r1.origin.y, (r1.origin.x + r1.size.width) - maxx, maxy - r1.origin.y);
  }
  else if (!lxly && !lxhy && !hxly && !hxhy) {
    rects[0] = GSMakeRect(r1.origin.x, r1.origin.y, r1.size.width, miny - r1.origin.y);
    rects[1] = GSMakeRect(r1.origin.x, r1.origin.y, minx - r1.origin.x, r1.size.height);
    rects[2] = GSMakeRect(r1.origin.x, maxy, r1.size.width, (r1.origin.y + r1.size.height) - maxy);
    rects[3] = GSMakeRect(maxx, r1.origin.y, (r1.origin.x + r1.size.width) - maxx, r1.size.height);
  }
}
