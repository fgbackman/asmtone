#!/bin/sh
# Builds asmtone's modem for ARM64 Linux and runs its self-tests (no Mac needed).
set -e
cd "$(dirname "$0")/.."
B=${TMPDIR:-/tmp}/asmtone-linux
mkdir -p "$B"
for f in fec dsp modem selftest; do
  as --defsym LINUX=1 -I src -o "$B/$f.o" "src/$f.s"
done
gcc -O1 -no-pie -o "$B/modemtest" test/linux_main.c "$B"/fec.o "$B"/dsp.o "$B"/modem.o "$B"/selftest.o -lm
"$B/modemtest"
