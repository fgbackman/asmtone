#!/bin/sh
# Writes test/samples/{piano,chirp,fast}.wav: a message as asmtone would play it.
#   sh test/make_samples.sh "your message"      (ARM64 Linux)
set -e
cd "$(dirname "$0")/.."
B=${TMPDIR:-/tmp}/asmtone-samples
mkdir -p "$B" test/samples
for f in fec dsp modem; do as --defsym LINUX=1 -I src -o "$B/$f.o" "src/$f.s"; done
gcc -O1 -no-pie -o "$B/make_samples" test/make_samples.c "$B"/fec.o "$B"/dsp.o "$B"/modem.o -lm
"$B/make_samples" "${1:-Hello from asmtone!}" test/samples
