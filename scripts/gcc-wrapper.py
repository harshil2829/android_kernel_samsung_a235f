#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Transparent wrapper for compiler invocation

import sys
import subprocess

if __name__ == '__main__':
    args = sys.argv[1:]
    sys.exit(subprocess.call(args))
