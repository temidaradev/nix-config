#!/usr/bin/env bash
# Prints one JSON object per second with cpu/mem/swap/temps/gpu/net stats.
# cpu is in tenths of a percent; temps in millidegrees; bytes raw; net is bytes/s.

tempf=""; gputempf=""; nvmetempf=""
for d in /sys/class/hwmon/hwmon*; do
    case "$(cat "$d/name" 2>/dev/null)" in
        k10temp|coretemp) tempf="$d/temp1_input" ;;
        nvme) [ -z "$nvmetempf" ] && nvmetempf="$d/temp1_input" ;;
        xe|i915|amdgpu)
            for l in "$d"/temp*_label; do
                [ -r "$l" ] || continue
                case "$(cat "$l")" in pkg|edge|junction) gputempf="${l%_label}_input" ;; esac
            done
            [ -z "$gputempf" ] && [ -r "$d/temp1_input" ] && gputempf="$d/temp1_input"
            ;;
    esac
done
cores=$(nproc)

gpu_busy=""; gpu_used=""; gpu_total=""
for c in /sys/class/drm/card?/device; do
    [ -r "$c/gpu_busy_percent" ] && gpu_busy="$c/gpu_busy_percent"
    [ -r "$c/mem_info_vram_used" ] && gpu_used="$c/mem_info_vram_used"
    [ -r "$c/mem_info_vram_total" ] && gpu_total="$c/mem_info_vram_total"
done
[ -z "$gpu_total" ] && for t in /sys/class/drm/card?/device/tile0/physical_vram_size_bytes; do
    [ -r "$t" ] && gpu_total="$t"
done

rd() { [ -n "$1" ] && cat "$1" 2>/dev/null || echo 0; }

prev_total=0 prev_idle=0 prev_rx=0 prev_tx=0 first=1
while :; do
    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idl=$((idle + iowait))
    dt=$((total - prev_total)); di=$((idl - prev_idle))
    cpu=0; [ "$dt" -gt 0 ] && cpu=$(( (dt - di) * 1000 / dt ))
    prev_total=$total; prev_idle=$idl

    eval "$(awk '/^MemTotal/{print "mt="$2} /^MemAvailable/{print "ma="$2} /^SwapTotal/{print "st="$2} /^SwapFree/{print "sf="$2}' /proc/meminfo)"

    read -r rx tx <<< "$(awk -F'[: ]+' 'NR>2 && $2 ~ /^(en|eth|wl)/ {r+=$3; t+=$11} END{print r+0, t+0}' /proc/net/dev)"
    rxs=0; txs=0
    if [ "$first" = 0 ]; then rxs=$((rx - prev_rx)); txs=$((tx - prev_tx)); fi
    prev_rx=$rx; prev_tx=$tx; first=0

    printf '{"cpu":%d,"cores":%d,"temp":%d,"gpuTemp":%d,"nvmeTemp":%d,"memTotal":%d,"memUsed":%d,"swapTotal":%d,"swapUsed":%d,"gpu":%d,"gpuUsed":%d,"gpuTotal":%d,"rx":%d,"tx":%d}\n' \
        "$cpu" "$cores" "$(rd "$tempf")" "$(rd "$gputempf")" "$(rd "$nvmetempf")" \
        $((mt * 1024)) $(((mt - ma) * 1024)) $((st * 1024)) $(((st - sf) * 1024)) \
        "$(rd "$gpu_busy")" "$(rd "$gpu_used")" "$(rd "$gpu_total")" "$rxs" "$txs"
    sleep 1
done
