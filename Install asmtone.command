#!/bin/bash
# Double-click me: builds asmtone, runs its self-tests, installs it to /Applications,
# pins it to the Dock and launches it. The output is also saved to install.log.
# Every successful install is committed to git ("build N installed").
cd "$(dirname "$0")"
LOCK="${TMPDIR:-/tmp}/asmtone-install.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -f "$LOCK/pid" ] && kill -0 "$(cat "$LOCK/pid" 2>/dev/null)" 2>/dev/null; then
    echo "Another asmtone install is already running - this one will not start."
    sleep 5
    exit 1
  fi
fi
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT
set -o pipefail
sh ./install.sh 2>&1 | tee install.log
rc=$?
sleep 8
if pgrep -x asmtone >/dev/null; then echo "health: asmtone still running after 8 s" >> install.log
else
  echo "health: asmtone is NOT running" >> install.log
  f=$(ls -t ~/Library/Logs/DiagnosticReports/*asmtone* 2>/dev/null | head -1)
  [ -n "$f" ] && { echo "crash report: $f"; head -c 40000 "$f"; } > crash.log
  rc=1
fi
if [ $rc -eq 0 ] && [ -d .git ]; then
  b=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' Info.plist 2>/dev/null)
  git add -A
  if git diff --cached --quiet; then echo "git: nothing new to commit" >> install.log
  else git commit -q -m "build $b installed" && echo "git: committed build $b" >> install.log
  fi
fi
exit $rc
