# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Self-contained pytest over the uv_* Cython surface (no fixture)."""
import pytest

import univector


def test_abi_version():
    assert univector.abi_version() == 1


def test_version():
    assert univector.version() == "1.0.0"
    assert univector.__version__ == "1.0.0"


def test_strerror_ok():
    assert univector.strerror(0) == "ok"


def test_image_bad_dims_raise():
    with pytest.raises(ValueError):
        univector.Image(0, 4)
    with pytest.raises(ValueError):
        univector.Image(4, 0)


def test_color_parse_bad_raises():
    with pytest.raises(ValueError):
        univector.Color.parse("not-a-color")


def test_color_rgba_and_to_svg():
    red = univector.Color.rgba(1.0, 0.0, 0.0, 1.0)
    assert red.to_svg() == "#FF0000"


def test_color_parse_hex_to_svg():
    c = univector.Color.parse("#3366cc")
    assert c.to_svg() == "#3366CC"


def test_fill_rect_pixel():
    """A 4x4 rect filled with #3366cc covers the interior with the solid color."""
    img = univector.Image(4, 4)
    assert (img.width, img.height, img.channels) == (4, 4, 4)
    p = univector.Path()
    p.rect(0, 0, 4, 4)
    col = univector.Color.parse("#3366cc")
    img.fill(p, col, winding=univector.WINDING_NON_ZERO)
    px = img.pixels()
    assert len(px) == 4 * 4 * 4
    # Interior pixel (1,1): full coverage -> exact solid sRGB, opaque.
    off = ((1 * 4) + 1) * 4
    assert px[off:off + 4] == b"\x33\x66\xcc\xff"


def test_fill_even_odd_red():
    img = univector.Image(2, 2)
    p = univector.Path()
    p.rect(0, 0, 2, 2)
    red = univector.Color.rgba(1.0, 0.0, 0.0, 1.0)
    img.fill(p, red, winding=univector.WINDING_EVEN_ODD)
    px = img.pixels()
    assert px[0:4] == b"\xff\x00\x00\xff"


def test_fill_overwrite_replaces_backdrop():
    img = univector.Image(1, 1)
    p = univector.Path()
    p.rect(0, 0, 1, 1)
    img.fill(p, univector.Color.parse("#0000ff"))
    img.fill(p, univector.Color.parse("#ff000080"),
             blend=univector.BLEND_OVERWRITE)
    assert img.pixels() == b"\xff\x00\x00\x80"


def test_parse_d_round_trip():
    p = univector.Path.parse_d("M 0 0 L 10 0 L 10 10 Z")
    d = p.to_d()
    assert d.startswith("M 0 0")
    assert "L 10 0" in d


def test_parse_d_bad_raises():
    with pytest.raises(ValueError):
        univector.Path.parse_d("M 0 0 X 1 2")


def test_to_svg_contains_path_and_fill():
    p = univector.Path()
    p.rect(0, 0, 4, 4)
    col = univector.Color.parse("#3366cc")
    svg = p.to_svg(col, 4, 4)
    assert svg.startswith("<svg")
    assert "<path d=\"" in svg
    assert "fill=\"#3366CC\"" in svg


def test_encode_png_signature():
    img = univector.Image(2, 2)
    p = univector.Path()
    p.rect(0, 0, 2, 2)
    img.fill(p, univector.Color.parse("#ff0000"))
    png = img.encode_png()
    assert png[:4] == b"\x89PNG"


def test_path_copy():
    p = univector.Path()
    p.rect(0, 0, 4, 4)
    q = p.copy()
    assert q.to_d() == p.to_d()


def test_path_state_commands_flatten_and_bounds():
    p = univector.Path.parse_d("M 1 2 l 3 4 Z")
    assert p.start == pytest.approx((1, 2))
    assert p.current == pytest.approx((1, 2))
    assert [command[0] for command in p.commands] == [
        univector.PATH_MOVE,
        univector.PATH_REL_LINE,
        univector.PATH_CLOSE,
    ]
    segments = p.flatten()
    assert len(segments) == 2
    assert univector.compute_bounds(segments) == pytest.approx((1, 2, 3, 4))
    assert p.bounds() == pytest.approx((1, 2, 3, 4))


def test_geometry_helpers_and_command_metadata():
    assert univector.BLEND_NORMAL == 0
    assert univector.BLEND_OVERWRITE == 1
    assert univector.GEOMETRIC_EPSILON > 0
    assert univector.MAX_FLATTEN_SEGMENTS == 1048576
    assert univector.quad_point((0, 0), (1, 1), (2, 0), 0.5) == pytest.approx(
        (1, 0.5)
    )
    assert univector.cubic_point(
        (0, 0), (0, 1), (1, 1), (1, 0), 0.5
    ) == pytest.approx((0.5, 0.75))
    assert univector.is_relative(univector.PATH_REL_LINE)
    assert univector.parameter_count(univector.PATH_CUBIC) == 6
    with pytest.raises(ValueError):
        univector.quad_point((0, 0), (1, 1), (2, 0), 1.5)


def test_arc_and_arc_to_validate_radius():
    p = univector.Path()
    p.arc(0, 0, 10, 0, 3.14159265)
    p.arc_to(10, 0, 10, 10, 2)
    with pytest.raises(ValueError):
        p.arc(0, 0, -1, 0, 1)


def test_path_polygon_guard():
    p = univector.Path()
    with pytest.raises(ValueError):
        p.polygon(0, 0, 5, 2)


def test_path_builders_reject_invalid_domains():
    p = univector.Path()
    with pytest.raises(ValueError):
        p.move_to(float("nan"), 0)
    with pytest.raises(ValueError):
        p.ellipse(0, 0, -1, 2)
    with pytest.raises(ValueError):
        p.circle(0, 0, -1)
