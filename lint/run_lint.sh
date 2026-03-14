#!/usr/bin/env bash
set -euo pipefail

cd "$MRV_CPU_HOME"

verilator --lint-only --sv -Wall \
  --top-module m_vlsit_mrv_cpu \
  -f rtl/filelist.f \
  "$@"
