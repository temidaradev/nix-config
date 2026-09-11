#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root: sudo $0" >&2
  exit 1
fi

rapl=/sys/class/powercap/intel-rapl-mmio/intel-rapl-mmio:0
pl1="$rapl/constraint_0_power_limit_uw"
pl2="$rapl/constraint_1_power_limit_uw"
ac=/sys/class/power_supply/AC/online

[ -r "$pl1" ] && [ -w "$pl1" ] || { echo "MMIO RAPL PL1 is unavailable" >&2; exit 1; }
[ "$(cat "$ac")" = 1 ] || { echo "AC power is not connected" >&2; exit 1; }

old_pl1=$(cat "$pl1")
old_pl2=$(cat "$pl2")
start=$(date +%s)

restore() {
  printf '%s\n' "$old_pl1" > "$pl1" 2>/dev/null || true
  printf '%s\n' "$old_pl2" > "$pl2" 2>/dev/null || true
}
trap restore EXIT INT TERM

printf 'original PL1=%s PL2=%s\n' "$old_pl1" "$old_pl2"
printf '%s\n' 35000000 > "$pl1"
printf 'single write PL1=%s\n' "$(cat "$pl1")"
echo 'Run turbostat/stress-ng in another terminal now; this audit never rewrites the value.'

while :; do
  now=$(date +%s)
  current=$(cat "$pl1")
  printf '%s PL1=%s PL2=%s\n' "$(date --iso-8601=seconds)" "$current" "$(cat "$pl2")"
  [ "$current" = 35000000 ] || {
    echo "PL1 changed externally; stopping and restoring the original values." >&2
    exit 2
  }
  [ $((now - start)) -lt 120 ] || break
  sleep 1
done

echo 'PL1 remained 35 W for 120 seconds; values will now be restored.'
