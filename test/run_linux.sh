#!/bin/sh
# Builds asmtone's modem for ARM64 Linux and runs its self-tests (no Mac needed), then
# plays every mode through simulated echoing rooms (needs python3 + numpy).
set -e
cd "$(dirname "$0")/.."
B=${TMPDIR:-/tmp}/asmtone-linux
mkdir -p "$B"
for f in fec dsp modem text selftest; do
  as --defsym LINUX=1 -I src -o "$B/$f.o" "src/$f.s"
done
gcc -O1 -no-pie -o "$B/modemtest" test/linux_main.c "$B"/fec.o "$B"/dsp.o "$B"/modem.o "$B"/text.o "$B"/selftest.o -lm
"$B/modemtest"
gcc -O1 -no-pie -w -o "$B/analyze" test/analyze.c "$B"/fec.o "$B"/dsp.o "$B"/modem.o "$B"/text.o -lm
gcc -O1 -no-pie -w -o "$B/render" test/render.c "$B"/fec.o "$B"/dsp.o "$B"/modem.o "$B"/text.o -lm
if python3 -c "import numpy" 2>/dev/null; then
  python3 test/room_test.py "$B"
else
  echo "(numpy missing: room tests skipped)"
fi
