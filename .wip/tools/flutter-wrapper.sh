#!/usr/bin/env bash
# Session helper: several agents run `flutter test` in the same project at once.
# The tool keeps ONE compile cache per build directory and copies it without
# locking, so concurrent runs can read a half-written cache and the compiler
# then eats all memory. This wrapper gives every test run one of three slots,
# each with its own build directory (through a per-slot settings file), and
# makes extra runs wait for a free slot. Everything else passes straight through.
#
# The slot lock stays in THIS process: the run gets its own process group with
# the lock closed, so a tester that outlives its run can never keep a slot, and
# whatever a run leaves behind is killed when the slot is next taken.
REAL=/opt/sdk/flutter/bin/flutter.real
BASE=/tmp/kk-flutter-slots
LIMIT=${KK_FLUTTER_TEST_LIMIT:-1500}
is_test=0
for a in "$@"; do
  case "$a" in
    test) is_test=1; break ;;
    -*) ;;
    *) break ;;
  esac
done
if [ "$is_test" != 1 ]; then exec "$REAL" "$@"; fi

child=
end_group() {
  [ -n "$child" ] || return 0
  kill -TERM -- -"$child" 2>/dev/null
  for _ in 1 2 3 4 5; do
    kill -0 -- -"$child" 2>/dev/null || return 0
    sleep 0.2
  done
  kill -KILL -- -"$child" 2>/dev/null
}
trap 'end_group; exit 143' INT TERM HUP

while true; do
  for n in 1 2 3; do
    exec {fd}>"$BASE/slot$n.lock"
    if flock -n "$fd"; then
      # A run that was cut off without a chance to clean up may still be alive.
      old=$(cat "$BASE/slot$n.pgid" 2>/dev/null)
      if [ -n "$old" ] && pgrep -g "$old" -f 'flutter|dart' >/dev/null 2>&1; then
        kill -KILL -- -"$old" 2>/dev/null
        sleep 0.3
      fi
      export XDG_CONFIG_HOME="$BASE/slot$n"
      setsid timeout --kill-after=10 "$LIMIT" "$REAL" "$@" {fd}>&- &
      child=$!
      echo "$child" > "$BASE/slot$n.pgid"
      wait "$child"
      status=$?
      # Nothing of this run may outlive it.
      kill -KILL -- -"$child" 2>/dev/null
      : > "$BASE/slot$n.pgid"
      exit "$status"
    fi
    exec {fd}>&-
  done
  sleep 1
done
