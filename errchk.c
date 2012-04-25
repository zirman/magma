//
//  errchk.c
//  XBolo Map Editor
//
//  Created by Robert Chrzanowski.
//  Copyright 2004 Robert Chrzanowski. All rights reserved.
//

#include "errchk.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>


struct TErrNode {
  struct TErrNode *prev;
  struct TErrNode *next;
  pthread_t thread;
  size_t used;
  size_t size;
  struct LineInfo {
    char file[64];
    char function[64];
    size_t line;
  } *stack;
} ;

struct TErrNode top = { NULL };

struct TErrNode *getnode();

struct TErrNode *getnode() {
  pthread_t thread;
  struct TErrNode *node;

  thread = pthread_self();

  for (node = top.next; node != NULL; node = node->next) {
    if (node->thread == thread) {
      return node;
    }
  }

  assert((node = (struct TErrNode *)malloc(sizeof(struct TErrNode))) != NULL);
  node->thread =  thread;
  node->prev = &top;
  node->next = top.next;
  node->used = 0;
  node->size = 1;
  assert((node->stack =
    (struct LineInfo *)malloc(node->size*sizeof(struct LineInfo))) != NULL);
  node->prev->next = node;

  if (node->next != NULL) {
    node->next->prev = node;
  }

  return node;
}

void errchkcleanup() {
  struct TErrNode *node;

  if ((node = getnode()) != NULL) {
    node->prev->next = node->next;

    if (node->next != NULL) {
      node->next->prev = node->prev;
    }

    free(node->stack);
    free(node);
  }
}

void pushlineinfo(const char *file, const char *function, size_t line) {
  struct TErrNode *node;

  node = getnode();

  if (node->used + 1 > node->size) {
    node->size *= 2;
    assert((node->stack = realloc(node->stack, node->size*sizeof(struct LineInfo))) != NULL);
  }

  strncpy(node->stack[node->used].file, file, sizeof(node->stack[node->used].file) - 1);
  strncpy(node->stack[node->used].function, function, sizeof(node->stack[node->used].function) - 1);
  node->stack[node->used].line = line;
  node->used++;
}

void printlineinfo() {
  struct TErrNode *node;
  size_t i;

  node = getnode();
  assert(fprintf(stderr, "Error Trace:\n") >= 0);

  for (i = 0; i < node->used; i++) {
    assert(fprintf(stderr, "file:%s:%s:%ld\n", node->stack[i].file,
                   node->stack[i].function, node->stack[i].line) >= 0);
  }
}
