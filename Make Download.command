#!/bin/bash
# Double-click me: runs the self-tests and makes dist/asmtone-<version>-mac-arm64.zip
# (asmtone.app + INSTALL.txt) for other Macs. The output is also saved to dist.log.
cd "$(dirname "$0")"
set -o pipefail
make dist 2>&1 | tee dist.log
