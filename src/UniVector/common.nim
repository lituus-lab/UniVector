# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniVector/common — 2D graphics leaf types.
##
## The vector type itself is UniLinalg's `Vector[2, float32]` (alias `Vector2f`),
## consumed here, never redefined. The graphics primitives
## `Rect`/`Segment`/`Circle`/`Polygon` are the 2D-rasterization leaf types the
## path and rasterizer modules build on.
import std/math
import UniLinalg

export UniLinalg.Vector2f, UniLinalg.vec2, UniLinalg.`[]`, UniLinalg.x,
  UniLinalg.y, UniLinalg.`+`, UniLinalg.`-`, UniLinalg.`*`, UniLinalg.`/`,
  UniLinalg.`+=`, UniLinalg.`-=`, UniLinalg.`*=`, UniLinalg.`/=`,
  UniLinalg.dot, UniLinalg.lengthSquared, UniLinalg.length, UniLinalg.normalize
# UniLinalg's `RealField` concept calls `sqrt` at the generic's instantiation
# site (the consumer), so `sqrt` must be visible to anyone who calls `vec2` /
# `length` / `normalize`. Re-export it so `import UniVector` is self-sufficient.
export math.sqrt

type
  Vec2* = Vector2f
    ## Convenience alias for the 2D point/vector used throughout the rasterizer.

  Rect* = object
    ## Axis-aligned rectangle stored as origin and size.
    x*: float32
    y*: float32
    w*: float32
    h*: float32

  Segment* = object
    ## Directed line segment stored as its start and end points.
    at*: Vec2
    to*: Vec2

  Circle* = object
    pos*: Vec2
    radius*: float32

  Polygon* = seq[Vec2]

  BlendMode* = enum
    NormalBlend    ## `dst = src*coverage + dst*(1-coverage)` (straight alpha, the default).
    OverwriteBlend ## `dst = src` (ignore the backdrop; no compositing).

  WindingRule* = enum
    NonZero
    EvenOdd
