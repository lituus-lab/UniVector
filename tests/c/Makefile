# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# Use CURDIR portably and select the platform's file-removal command.
ifeq ($(origin CC),default)
  ifeq ($(OS),Windows_NT)
    CC := gcc
  else
    CC := cc
  endif
endif

ROOT   := $(CURDIR)/../..
CFLAGS := -I$(ROOT)/include -O2 -Wall -Wextra -std=c11
LIB    := $(ROOT)/libUniVector.a
# Static consumers supply zlib for PNG and libm for the engine's mathematics.
# Keep system libraries after the archive so one-pass Unix linkers resolve it.
LIBS := -lz -lm

ifeq ($(OS),Windows_NT)
  BIN  := test_univector.exe
  RUN  := $(BIN)
  RM_F := del /q
else
  BIN  := test_univector
  RUN  := ./$(BIN)
  RM_F := rm -f
endif

.PHONY: all run test clean
all: run
run: $(BIN)
	$(RUN)
test: run
$(BIN): test_univector.c $(ROOT)/include/UniVector.h $(LIB)
	$(CC) $(CFLAGS) -o $(BIN) test_univector.c $(LIB) $(LIBS)
# File target, not phony: `nimble ctest` already built the lib, don't redo it.
$(LIB):
	cd $(ROOT) && nimble clibStatic
clean:
	-$(RM_F) $(BIN)
