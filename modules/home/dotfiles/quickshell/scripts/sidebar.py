"""Small, argv-only backend for the shell workbench. Never executes shell input."""
import contextlib
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import math
import struct
import subprocess
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "quickshell/sidebar"
DEFAULT = {"tasks": [], "notes": "", "pins": [], "favorites": ["audio", "capture", "power", "network"], "layouts": {}, "scroll": {}, "lastTab": "home"}


def run(*args, optional=False, timeout=8, input=None):
    try:
        p = subprocess.run([str(a) for a in args], input=input, capture_output=True, timeout=timeout)
        if p.returncode and not optional:
            raise ValueError(p.stderr.decode(errors="replace").strip() or p.stdout.decode(errors="replace").strip() or f"{args[0]} exited {p.returncode}")
        return p.stdout.decode(errors="replace") if p.returncode == 0 else ""
    except (FileNotFoundError, subprocess.TimeoutExpired):
        if not optional:
            raise ValueError(f"{args[0]} is unavailable or did not respond")
        return ""


def js(*args, default=None):
    try:
        return json.loads(run(*args, optional=True))
    except (ValueError, TypeError):
        return [] if default is None else default


def read(path, default=""):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return default


def atomic(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    tmp = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    with open(tmp, "w", opener=lambda p, f: os.open(p, f, 0o600)) as f:
        f.write(value)
    os.replace(tmp, path)


@contextlib.contextmanager
def state():
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (STATE / "sidebar.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = DEFAULT | js_file(STATE / "sidebar.json", {})
        yield data
        serialized = json.dumps(data)
        if serialized != read(STATE / "sidebar.json"):
            atomic(STATE / "sidebar.json", serialized)


def js_file(path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


def local():
    with state() as data:
        now = time.time()
        for task in data["tasks"]:
            if not task.get("done") and task.get("due", 0) and task["due"] <= now and not task.get("notified"):
                try:
                    run("notify-send", "-a", "Reminders", "-u", "normal", "Reminder", task["text"])
                    task["notified"] = True
                except ValueError:
                    pass
        return data


def audio():
    kinds = ["sinks", "sources", "cards", "sink-inputs", "source-outputs"]
    with ThreadPoolExecutor(max_workers=6) as pool:
        vals = list(pool.map(lambda k: js("pactl", "-f", "json", "list", k), kinds))
    result = dict(zip(kinds, vals))
    result["available"] = bool(shutil.which("pactl"))
    result["defaultSink"] = run("pactl", "get-default-sink", optional=True).strip()
    result["defaultSource"] = run("pactl", "get-default-source", optional=True).strip()
    result["sources"] = [s for s in result["sources"] if not s["name"].endswith(".monitor")]
    metadata = run("pw-metadata", "-n", "settings", optional=True)
    result["clock"] = dict(re.findall(r"key:'([^']+)' value:'([^']*)'", metadata))
    result["effects"] = bool(shutil.which("easyeffects"))
    result["presets"] = [p.stem for p in (Path.home() / ".config/easyeffects/output").glob("*.json")]
    result["effectsBypass"] = bool(js_file(STATE / "effects.json", {}).get("bypass", False))
    return result


def outputs():
    raw = js("niri", "msg", "--json", "outputs", default={})
    return [dict(v, name=k) for k, v in raw.items()]


def displays():
    data = js_file(STATE / "sidebar.json", {})
    return {"outputs": outputs(), "layouts": list(data.get("layouts", {})), "pending": pending_display(), "temperature": js_file(STATE / "night.json", {}).get("temperature", 6500)}


def power():
    batteries = []
    for b in Path("/sys/class/power_supply").glob("*"):
        if read(b / "type") != "Battery":
            continue
        def number(key):
            try:
                return float(read(b / key))
            except ValueError:
                return 0
        full = number("energy_full") or number("charge_full")
        design = number("energy_full_design") or number("charge_full_design")
        watts = number("power_now") / 1e6 or number("current_now") * number("voltage_now") / 1e12
        batteries.append({"name": b.name, "status": read(b / "status"), "watts": round(watts, 2), "health": round(100 * full / design, 1) if design else 0, "cycles": read(b / "cycle_count", "—"), "start": read(b / "charge_control_start_threshold"), "end": read(b / "charge_control_end_threshold")})
    return {"batteries": batteries, "chargeControl": bool(shutil.which("battery-charge-ctl")), "governor": read("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"), "epp": read("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"), "profile": read("/sys/firmware/acpi/platform_profile")}


def network():
    tail = js("tailscale", "status", "--json", default={})
    peers = [{"name": p.get("HostName", ""), "ip": (p.get("TailscaleIPs") or [""])[0], "online": p.get("Online", False), "os": p.get("OS", ""), "relay": p.get("Relay", "")} for p in (tail.get("Peer") or {}).values()]
    interfaces = []
    for p in Path("/sys/class/net").glob("*"):
        if p.name == "lo":
            continue
        interfaces.append({"name": p.name, "rx": int(read(p / "statistics/rx_bytes", "0")), "tx": int(read(p / "statistics/tx_bytes", "0"))})
    return {"tailscale": bool(shutil.which("tailscale")), "tailState": tail.get("BackendState", "Unavailable"), "tailIP": (tail.get("TailscaleIPs") or [""])[0], "peers": sorted(peers, key=lambda p: (not p["online"], p["name"])), "mullvad": run("mullvad", "status", optional=True).strip(), "hasMullvad": bool(shutil.which("mullvad")), "interfaces": interfaces, "dns": run("nmcli", "-g", "IP4.DNS", "device", "show", optional=True).strip()}


def system():
    failed = []
    for user in (True, False):
        cmd = ["systemctl"] + (["--user"] if user else [])
        for line in run(*cmd, "--failed", "--no-legend", "--plain", optional=True).splitlines():
            p = line.split(None, 4)
            if len(p) >= 4:
                failed.append({"name": p[0], "user": user, "description": p[-1]})
    processes = []
    for line in run("ps", "-u", str(os.getuid()), "-o", "pid=,pcpu=,rss=,comm=", "--sort=-pcpu", optional=True).splitlines()[:12]:
        p = line.split(None, 3)
        if len(p) == 4:
            processes.append({"pid": int(p[0]), "cpu": p[1], "memory": int(p[2]) * 1024, "name": p[3]})
    return {"failed": failed, "processes": processes, "errors": run("journalctl", "-b", "-p", "err", "-n", "15", "--no-pager", "-o", "short", optional=True)[-6000:], "generation": os.path.realpath("/run/current-system"), "storeSize": run("df", "-h", "--output=avail", "/nix/store", optional=True).strip().splitlines()[-1:]}


def clipboard():
    CACHE.mkdir(parents=True, exist_ok=True, mode=0o700)
    items = []
    previews = 0
    for line in run("cliphist", "list", optional=True).splitlines()[:100]:
        key, sep, text = line.partition("\t")
        if not sep or not key.isdigit():
            continue
        image = "binary data" in text and bool(re.search(r"\b(png|jpeg|jpg|webp|gif|bmp)\b", text, re.I))
        preview = ""
        if image and previews < 12:
            previews += 1
            path = CACHE / (key + ".png")
            if not path.exists():
                p = subprocess.run(["cliphist", "decode", key], capture_output=True, timeout=5)
                if p.returncode == 0 and len(p.stdout) < 12_000_000:
                    path.write_bytes(p.stdout)
                    path.chmod(0o600)
            if path.exists():
                preview = str(path)
        items.append({"id": key, "text": text, "image": image, "preview": preview})
    live = {i["id"] + ".png" for i in items}
    for path in CACHE.glob("*.png"):
        if path.name not in live:
            path.unlink(missing_ok=True)
    return {"items": items, "paused": (STATE / "clipboard-paused").exists()}


def captures():
    recdir = Path.home() / "Videos/Recordings"
    files = sorted(recdir.glob("*"), key=lambda p: p.stat().st_mtime, reverse=True)[:12] if recdir.exists() else []
    return {"recent": [{"name": p.name, "path": str(p), "size": p.stat().st_size} for p in files if p.is_file()]}


def meter():
    child = subprocess.Popen(["pw-cat", "--record", "--raw", "--format", "f32", "--rate", "16000", "--channels", "1", "-"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    def stop(*_):
        child.terminate()
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, stop)
    try:
        while chunk := child.stdout.read(6400):
            samples = struct.unpack("<" + "f" * (len(chunk) // 4), chunk[:len(chunk) // 4 * 4])
            peak = min(1, max((abs(s) for s in samples if math.isfinite(s)), default=0))
            print(json.dumps({"peak": peak}), flush=True)
    finally:
        child.terminate()
        child.wait(timeout=3)


def record(config):
    modules = []
    child = None
    cancelled = False
    def stop(*_):
        nonlocal cancelled
        cancelled = True
        if child and child.poll() is None:
            child.send_signal(signal.SIGINT)
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    def video_args(codec):
        args = ["-c", codec, "-p", "b=" + str(safe_int(config.get("bitrate", 12), 1, 100) * 1_000_000)]
        if codec.endswith("_vaapi"):
            renders = sorted(Path("/dev/dri").glob("renderD*"))
            if not renders:
                return None
            return args + ["-d", str(renders[0])]
        return args + ["-x", "yuv420p"]

    def audio_args():
        source = config.get("audio", "none")
        if source == "none":
            return []
        sink = run("pactl", "get-default-sink").strip()
        mic = run("pactl", "get-default-source").strip()
        if source == "both":
            name = "qs_recording_" + str(os.getpid())
            modules.append(run("pactl", "load-module", "module-null-sink", "sink_name=" + name).strip())
            for src in (sink + ".monitor", mic):
                modules.append(run("pactl", "load-module", "module-loopback", "source=" + src, "sink=" + name, "latency_msec=30", "source_dont_move=true", "sink_dont_move=true").strip())
            source = name + ".monitor"
        elif source == "desktop":
            source = sink + ".monitor"
        elif source == "microphone":
            source = mic
        return ["--audio=" + source, "-C", "aac", "-P", "b=" + str(safe_int(config.get("audioBitrate", 192), 64, 320) * 1000)]

    def notify(text):
        run("notify-send", "-a", "Recorder", "Recording", text, optional=True)

    try:
        base = ["wf-recorder", "-y", "-f", config["file"], "-r", str(safe_int(config.get("fps", 60), 15, 120))]
        codec = config.get("codec", "libx264")
        if codec not in ("libx264", "libx265", "libvpx-vp9", "h264_vaapi", "hevc_vaapi"):
            raise ValueError("Unsupported encoder")
        if config.get("geometry"):
            base += ["-g", config["geometry"]]
        elif config.get("output"):
            base += ["-o", config["output"]]
        try:
            audio = audio_args()
        except ValueError as e:
            audio = []
            notify(f"Audio unavailable, recording video only ({e})")
        Path(config["file"]).parent.mkdir(parents=True, exist_ok=True)
        attempts = [codec] + (["libx264"] if codec.endswith("_vaapi") else [])
        code = 1
        for i, attempt in enumerate(attempts):
            video = video_args(attempt)
            if video is None:
                continue
            if cancelled:
                return 0
            started = time.monotonic()
            child = subprocess.Popen(base + video + audio)
            if cancelled:
                stop()
            code = child.wait()
            if code == 0 or cancelled or time.monotonic() - started > 3 or i == len(attempts) - 1:
                return code
            notify(f"{attempt} failed, retrying with software encoding")
        return code
    finally:
        for module in reversed(modules):
            run("pactl", "unload-module", module, optional=True)


def agenda():
    cfg = js_file(STATE / "sidebar.json", {})
    path = cfg.get("calendarFile", "")
    events = []
    # Deliberately local: calendar credentials never enter the Nix store.
    if path:
        from icalendar import Calendar
        from dateutil.rrule import rrulestr
        cal = Calendar.from_ical(Path(path).expanduser().read_bytes())
        now = dt.datetime.now().astimezone()
        until = now + dt.timedelta(days=30)
        for ev in cal.walk("VEVENT"):
            if not ev.get("DTSTART"):
                continue
            start = ev.decoded("DTSTART")
            if not isinstance(start, dt.datetime):
                start = dt.datetime.combine(start, dt.time(), tzinfo=now.tzinfo)
            elif start.tzinfo is None:
                start = start.replace(tzinfo=now.tzinfo)
            starts = [start]
            if ev.get("RRULE"):
                rule = ev["RRULE"].to_ical().decode()
                starts = list(rrulestr(rule, dtstart=start).between(now - dt.timedelta(days=1), until, inc=True))[:40]
            excluded = set()
            excluded_days = set()
            ex = ev.get("EXDATE", [])
            for entry in ex if isinstance(ex, list) else [ex]:
                for item in entry.dts:
                    value = item.dt
                    if isinstance(value, dt.datetime):
                        if value.tzinfo is None:
                            value = value.replace(tzinfo=start.tzinfo)
                        excluded.add(value.timestamp())
                    else:
                        excluded_days.add(value)
            for occurrence in starts:
                if occurrence.timestamp() in excluded or occurrence.date() in excluded_days or occurrence.date() < now.date() or occurrence > until:
                    continue
                events.append({"title": str(ev.get("SUMMARY", "Untitled")), "start": occurrence.timestamp(), "when": occurrence.strftime("%a %d %b · %H:%M"), "location": str(ev.get("LOCATION", ""))})
    return {"events": sorted(events, key=lambda e: e["start"])[:60], "file": path}


def safe_int(value, lo, hi):
    number = int(value)
    if not lo <= number <= hi:
        raise ValueError("Value is outside the supported range")
    return number


def restore_display(saved):
    for output in saved:
        name, logical = output["name"], output.get("logical")
        if logical is None:
            run("niri", "msg", "output", name, "off", optional=True)
            continue
        run("niri", "msg", "output", name, "on", optional=True)
        idx = output.get("current_mode")
        if idx is not None:
            mode = output["modes"][idx]
            run("niri", "msg", "output", name, "mode", f'{mode["width"]}x{mode["height"]}@{mode["refresh_rate"] / 1000}', optional=True)
        run("niri", "msg", "output", name, "scale", logical["scale"], optional=True)
        transform = str(logical.get("transform", "Normal")).lower()
        transform = {"flipped90": "flipped-90", "flipped180": "flipped-180", "flipped270": "flipped-270"}.get(transform, transform)
        run("niri", "msg", "output", name, "transform", transform, optional=True)
        run("niri", "msg", "output", name, "position", "set", "--", logical["x"], logical["y"], optional=True)


def display_watch(token):
    time.sleep(18)
    with state():
        saved = js_file(STATE / "display-pending.json", {})
        if saved.get("token") == token:
            restore_display(saved["outputs"])
            (STATE / "display-pending.json").unlink(missing_ok=True)


def pending_display():
    path = STATE / "display-pending.json"
    saved = js_file(path, {})
    if saved and saved.get("until", 0) + 10 < time.time():
        path.unlink(missing_ok=True)
        return {}
    return saved


def begin_display():
    path = STATE / "display-pending.json"
    if pending_display():
        raise ValueError("Keep or revert the previous display change first")
    token = uuid.uuid4().hex
    atomic(path, json.dumps({"token": token, "outputs": outputs(), "until": time.time() + 18}))
    subprocess.Popen([sys.executable, __file__, "display-watch", token], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def action(a):
    op = a["op"]
    if op == "local":
        with state() as data:
            for k in ("notes", "favorites", "scroll", "lastTab", "homeCards"):
                if k in a:
                    data[k] = a[k]
    elif op.startswith("task-"):
        with state() as data:
            if op == "task-add":
                text = str(a.get("text", "")).strip()[:1000]
                if not text:
                    raise ValueError("Enter a task")
                due = str(a.get("due", "")).strip()
                stamp = dt.datetime.fromisoformat(due).astimezone().timestamp() if due else 0
                data["tasks"].append({"id": uuid.uuid4().hex, "text": text, "due": stamp, "done": False})
            elif op == "task-toggle":
                for task in data["tasks"]:
                    if task["id"] == a["id"]:
                        task["done"] = not task["done"]
            elif op == "task-delete":
                data["tasks"] = [t for t in data["tasks"] if t["id"] != a["id"]]
    elif op == "calendar-file":
        path = Path(a["path"]).expanduser()
        if not path.is_file() or path.suffix.lower() != ".ics":
            raise ValueError("Choose an existing .ics calendar file")
        with state() as data:
            data["calendarFile"] = str(path)
    elif op == "audio-rate":
        rate = safe_int(a["value"], 0, 192000)
        if rate not in (0, 44100, 48000, 88200, 96000, 192000):
            raise ValueError("Unsupported sample rate")
        run("pw-metadata", "-n", "settings", "0", "clock.force-rate", rate)
    elif op == "audio-quantum":
        quantum = safe_int(a["value"], 0, 2048)
        if quantum not in (0, 64, 128, 256, 512, 1024, 2048):
            raise ValueError("Unsupported buffer size")
        run("pw-metadata", "-n", "settings", "0", "clock.force-quantum", quantum)
    elif op == "audio-move":
        run("pactl", "move-source-output" if a.get("recording") else "move-sink-input", safe_int(a["index"], 0, 2**32 - 1), a["target"])
    elif op == "audio-profile":
        run("pactl", "set-card-profile", a["card"], a["profile"])
    elif op == "audio-port":
        run("pactl", "set-source-port" if a.get("input") else "set-sink-port", a["name"], a["port"])
    elif op == "audio-effects":
        if "preset" in a:
            run("easyeffects", "--load-preset", a["preset"])
        else:
            run("easyeffects", "--bypass", "1" if a["bypass"] else "2")
            atomic(STATE / "effects.json", json.dumps({"bypass": a["bypass"]}))
    elif op == "charge":
        mode = a["mode"]
        if mode not in ("full", "limit"):
            raise ValueError("Invalid charging mode")
        run("sudo", "-n", "/run/current-system/sw/bin/battery-charge-ctl", mode, timeout=15)
    elif op == "display":
        name, kind, value = a["name"], a["kind"], str(a["value"])
        available = {o["name"]: o for o in outputs()}
        if name not in available or kind not in ("mode", "scale", "transform", "vrr", "on", "off", "position"):
            raise ValueError("Unsupported display change")
        if kind == "off" and sum(o.get("logical") is not None for o in available.values()) <= 1:
            raise ValueError("Keep at least one display enabled")
        begin_display()
        args = ["niri", "msg", "output", name, kind]
        if kind == "position":
            args += ["set", "--", str(safe_int(a["x"], -32768, 32768)), str(safe_int(a["y"], -32768, 32768))]
        elif kind not in ("on", "off"):
            args.append(value)
        try:
            run(*args)
        except ValueError:
            (STATE / "display-pending.json").unlink(missing_ok=True)
            raise
    elif op == "display-keep":
        (STATE / "display-pending.json").unlink(missing_ok=True)
    elif op == "display-revert":
        saved = js_file(STATE / "display-pending.json", {})
        restore_display(saved.get("outputs", []))
        (STATE / "display-pending.json").unlink(missing_ok=True)
    elif op == "layout-save":
        name = str(a["name"]).strip()[:80]
        if not name:
            raise ValueError("Enter a layout name")
        with state() as data:
            data["layouts"][name] = outputs()
    elif op == "layout-apply":
        saved = js_file(STATE / "sidebar.json", {}).get("layouts", {}).get(a["name"])
        if not saved:
            raise ValueError("Layout not found")
        connected = {o["name"] for o in outputs()}
        enabled = [o for o in saved if o["name"] in connected and o.get("logical")]
        if not enabled:
            raise ValueError("No enabled display in this layout is connected")
        begin_display()
        restore_display([o for o in saved if o["name"] in connected])
    elif op == "night":
        value = safe_int(a["value"], 2500, 6500)
        old = js_file(STATE / "night.json", {})
        pid = old.get("pid", 0)
        if pid and Path(f"/proc/{pid}/comm").exists() and read(f"/proc/{pid}/comm") == "wlsunset":
            os.kill(pid, signal.SIGTERM)
        new = {"temperature": value}
        if value < 6500:
            p = subprocess.Popen(["wlsunset", "-t", str(value), "-T", str(value + 1), "-S", "06:00", "-s", "18:00"], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            new["pid"] = p.pid
        atomic(STATE / "night.json", json.dumps(new))
    elif op == "clipboard-pause":
        if a["paused"]:
            atomic(STATE / "clipboard-paused", "paused\n")
        else:
            (STATE / "clipboard-paused").unlink(missing_ok=True)
    elif op in ("clipboard-delete", "clipboard-pin", "clipboard-copy"):
        key = str(a["id"])
        if not key.isdigit():
            raise ValueError("Invalid clipboard entry")
        if op == "clipboard-delete":
            run("cliphist", "delete", input=(key + "\t").encode())
        else:
            p = subprocess.run(["cliphist", "decode", key], capture_output=True, timeout=5, check=True)
            if op == "clipboard-copy":
                run("wl-copy", input=p.stdout)
            else:
                pin = uuid.uuid4().hex
                path = STATE / "pins" / pin
                path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                path.write_bytes(p.stdout)
                path.chmod(0o600)
                with state() as data:
                    data["pins"].append({"id": pin, "text": str(a.get("text", "Pinned item"))[:500], "image": bool(a.get("image")), "path": str(path)})
    elif op in ("pin-copy", "pin-delete"):
        key = str(a["id"])
        if not re.fullmatch(r"[0-9a-f]{32}", key):
            raise ValueError("Invalid pin")
        if op == "pin-copy":
            run("wl-copy", input=(STATE / "pins" / key).read_bytes())
        else:
            with state() as data:
                data["pins"] = [p for p in data["pins"] if p["id"] != key]
            (STATE / "pins" / key).unlink(missing_ok=True)
    elif op == "clipboard-wipe":
        run("cliphist", "wipe")
        for p in CACHE.glob("*.png"):
            p.unlink(missing_ok=True)
    elif op == "copy":
        run("wl-copy", input=str(a["text"]).encode())
    elif op == "vpn":
        if a["provider"] == "mullvad":
            run("mullvad", "connect" if a["on"] else "disconnect")
        elif a["provider"] == "tailscale":
            run("pkexec", "tailscale", "up" if a["on"] else "down", timeout=120)
    elif op == "hotspot":
        run("nmcli", "device", "wifi", "hotspot", "ssid", str(a["ssid"]), "password", str(a["password"]), timeout=25)
    elif op == "ping":
        host = str(a["host"]).strip()
        if not re.fullmatch(r"[\w.:-]{1,253}", host) or host.startswith("-"):
            raise ValueError("Enter a hostname or IP address")
        return run("ping", "-c", "3", "-W", "2", "--", host, timeout=10)
    elif op == "service-restart":
        name = str(a["name"])
        if not re.fullmatch(r"[A-Za-z0-9_.@:-]+\.(service|socket|timer|mount)", name):
            raise ValueError("Unsupported unit name")
        cmd = ["systemctl", "--user"] if a.get("user") else ["pkexec", "systemctl"]
        run(*cmd, "restart", name, timeout=120)
    elif op == "process-stop":
        pid = safe_int(a["pid"], 2, 2**31 - 1)
        status = read(f"/proc/{pid}/status")
        uid = re.search(r"^Uid:\s+(\d+)", status, re.M)
        if not uid or int(uid[1]) != os.getuid() or pid == os.getpid():
            raise ValueError("Only your own running processes can be stopped")
        os.kill(pid, signal.SIGTERM)
    elif op == "diagnostics":
        report = {"system": system(), "audio": audio(), "power": power(), "displays": outputs()}
        run("wl-copy", input=json.dumps(report, indent=2).encode())
    else:
        raise ValueError("Unknown sidebar action")
    return "Done"


SNAPSHOTS = {"audio": audio, "displays": displays, "power": power, "network": network, "system": system, "clipboard": clipboard, "capture": captures, "local": local, "calendar": agenda}


def main():
    if sys.argv[1] == "watch-audio":
        os.execvp("pactl", ["pactl", "subscribe"])
    if sys.argv[1] == "meter":
        meter()
        return
    if sys.argv[1] == "record":
        sys.exit(record(json.loads(sys.argv[2])))
    if sys.argv[1] == "display-watch":
        display_watch(sys.argv[2])
        return
    try:
        if sys.argv[1] == "snapshot":
            section = sys.argv[2]
            print(json.dumps({"ok": True, "section": section, "data": SNAPSHOTS[section]()}))
        elif sys.argv[1] == "action":
            print(json.dumps({"ok": True, "message": action(json.loads(sys.argv[2]))}))
    except Exception as e:
        print(json.dumps({"ok": False, "message": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
