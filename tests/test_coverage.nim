# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab

# These imports register and execute their unittest suites.
{.push warning[UnusedImport]: off.}
import test_version
import test_path
import test_flatten
import test_prepared
import test_stroke
import test_raster
import test_svg
{.pop.}
