#!/bin/sh
# Replays a recording through asmtone's receiver and explains what it heard.
#   sh test/analyze.sh path/to/heard-....wav [v]     (ARM64 Linux)
set -e
cd "$(dirname "$0")/.."
B=${TMPDIR:-/tmp}/asmtone-analyze
mkdir -p "$B"
for f in fec dsp modem text; do as --defsym LINUX=1 -I src -o "$B/$f.o" "src/$f.s"; done
gcc -O1 -no-pie -o "$B/analyze" test/analyze.c "$B"/fec.o "$B"/dsp.o "$B"/modem.o "$B"/text.o -lm
"$B/analyze" "$@"
