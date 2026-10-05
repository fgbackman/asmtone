#!/bin/sh
# Builds asmtone's modem for ARM64 Linux and runs its self-tests (no Mac needed),
# then decodes a real recording made through a Mac's speaker and microphone.
set -e
cd "$(dirname "$0")/.."
B=${TMPDIR:-/tmp}/asmtone-linux
mkdir -p "$B"
for f in fec dsp modem selftest; do
  as --defsym LINUX=1 -I src -o "$B/$f.o" "src/$f.s"
done
gcc -O1 -no-pie -o "$B/modemtest" test/linux_main.c "$B"/fec.o "$B"/dsp.o "$B"/modem.o "$B"/selftest.o -lm
"$B/modemtest"
gcc -O1 -no-pie -w -o "$B/analyze" test/analyze.c "$B"/fec.o "$B"/dsp.o "$B"/modem.o -lm
if "$B/analyze" test/fixtures/room-piano.wav | grep -q "MESSAGE (24 bytes.*piano test one two three"; then
  echo "PASS  recorded room: Piano from the Mac mini's speaker, through its microphone"
else
  echo "FAIL  recorded room: Piano from the Mac mini's speaker, through its microphone"; exit 1
fi
