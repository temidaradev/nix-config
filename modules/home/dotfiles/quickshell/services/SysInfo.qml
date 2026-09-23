pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Static hardware/software facts for the System tab; read once at start.
Singleton {
    id: root
    property string os: ""
    property string kernel: ""
    property string cpu: ""
    property string cpuShort: ""
    property string cpuDetail: ""
    property int threads: 0
    property var gpus: []
    readonly property var primaryGpu: gpus.find(g => g.primary) ?? gpus[0] ?? null
    readonly property string gpu: primaryGpu?.name ?? ""
    readonly property string gpuShort: primaryGpu?.short ?? "GPU"
    readonly property string gpuDriver: primaryGpu?.driver ?? ""
    property string host: ""
    property string board: ""
    property string bios: ""
    property string shell: "quickshell"
    property string wm: ""
    property string memory: ""
    property string rootDisk: ""
    property string locale: ""
    property string session: ""
    property string user: ""
    property var displays: []
    property int packages: 0

    function junk(s) { return !s || /to be filled|system product|system version|default string|not applicable|not specified|^none$|^0+$/i.test(s.trim()) }

    function cleanCpu(s) {
        return s.replace(/\((R|TM)\)/gi, "").replace(/\s+@.*$/, "").replace(/\s+\d+-Core Processor/i, "")
            .replace(/\b(CPU|Processor)\b/g, "").replace(/\s+/g, " ").trim()
    }

    function expand(list) {
        const out = []
        for (const part of (list || "").split(",")) {
            const [a, b] = part.split("-").map(Number)
            if (isNaN(a)) continue
            for (let i = a; i <= (isNaN(b) ? a : b); i++) out.push(i)
        }
        return out
    }

    function vendorShort(v) {
        if (/intel/i.test(v)) return "Intel"
        if (/nvidia/i.test(v)) return "NVIDIA"
        if (/amd|ati|advanced micro/i.test(v)) return "AMD"
        if (/^0x/.test(v)) return ({ "0x8086": "Intel", "0x10de": "NVIDIA", "0x1002": "AMD" })[v] ?? v
        return v.split(/\s+/)[0]
    }

    function gpuNames(vendor, device) {
        const vs = vendorShort(vendor)
        const brackets = (device.match(/\[[^\]]+\]/g) || []).map(b => b.slice(1, -1))
        const code = device.replace(/\s*\[[^\]]*\]/g, "").trim()
        const model = brackets.length ? brackets[brackets.length - 1] : ""
        if (model === "" || /^((intel|amd)\s+)?graphics$/i.test(model))
            return { name: vs + " Graphics" + (code ? " (" + code + ")" : ""), short: code || vs + " Graphics" }
        const name = model.toLowerCase().startsWith(vs.toLowerCase()) ? model : vs + " " + model
        return { name, short: model.includes("/") ? (code || model) : model }
    }

    function displayName(make) {
        return (make || "").replace(/,?\s+(Inc\.?|Corporation|Corp\.?|Co\.,? Ltd\.?|Ltd\.?|Electronics.*|Technology.*)$/i, "").trim()
    }

    function uniq(xs) { return xs.map(s => (s || "").trim()).filter((s, i, a) => s !== "" && a.indexOf(s) === i) }
    function options(cands, none) {
        const c = { none }
        for (const s of cands) c[s] = "Show the text \"" + s + "\""
        return c
    }
    function chosen(a) { return a && a.choice !== "none" ? a.choice : "" }

    function describeHost(kv, p) {
        const ok = (f, fallback) => p && (f in p) ? p[f].noul >= 0.5 : fallback
        const version = ok("hostVersion", !junk(kv.hostVersion) && kv.hostVersion.length > 4)
        const name = ok("hostName", !junk(kv.hostName))
        const vendor = ok("sysVendor", !!kv.sysVendor && !junk(kv.sysVendor))
        root.bios = kv.bios && ok("bios", !junk(kv.bios.split(" (")[0])) ? kv.bios : ""
        root.host = version ? kv.hostVersion : name ? (vendor ? kv.sysVendor + " " : "") + kv.hostName : kv.board
    }
    function askHost(kv) {
        const fields = {}
        for (const f of ["hostVersion", "hostName", "sysVendor"]) if (kv[f]) fields[f] = kv[f]
        if (kv.bios) fields.bios = kv.bios.split(" (")[0]
        const q = {}
        const placeholder = "rather than an unfilled firmware placeholder such as \"To Be Filled By O.E.M.\", \"System Product Name\", \"Default string\" or \"0\""
        if (fields.hostVersion) q.hostVersion = { type: "noul", instructions: "Does `fields.hostVersion` (DMI product_version) name the computer's product model, such as \"ThinkPad X1 Carbon Gen 11\", " + placeholder + " or a bare revision number like \"1.0\"?" }
        if (fields.hostName) q.hostName = { type: "noul", instructions: "Is `fields.hostName` (DMI product_name) a real product name or machine-type code set by the manufacturer, " + placeholder + "?" }
        if (fields.sysVendor) q.sysVendor = { type: "noul", instructions: "Is `fields.sysVendor` (DMI sys_vendor) a real manufacturer name, " + placeholder + "?" }
        if (fields.bios) q.bios = { type: "noul", instructions: "Is `fields.bios` (DMI bios_version) a real firmware version string, " + placeholder + "?" }
        if (Object.keys(q).length === 0) return
        Jev.ask("dmi:v1:" + JSON.stringify(fields), { fields }, q, a => { if (a) describeHost(kv, a) })
    }

    function askGpu(i, vendor, device, n) {
        if (!device) return
        const vs = vendorShort(vendor)
        const brackets = (device.match(/\[[^\]]+\]/g) || []).map(b => b.slice(1, -1))
        const code = device.replace(/\s*\[[^\]]*\]/g, "").trim()
        const withVendor = s => s.toLowerCase().startsWith(vs.toLowerCase()) ? s : vs + " " + s
        const names = uniq([n.name].concat(brackets.map(withVendor), [code ? vs + " " + code : "", vs + " Graphics"]))
        const shorts = uniq([n.short].concat(brackets, [code, vs + " Graphics"]))
        const about = "`device` is the lspci device string of a GPU made by `vendor`: a chip codename, then marketing names in brackets, sometimes several sibling models joined by slashes, or a generic \"Graphics\" label."
        Jev.ask("gpu:v1:" + vendor + "|" + device, { vendor, device }, {
            name: { type: "choice", instructions: about + " Which label names this GPU best in a system-information panel?", criteria: options(names, "None of these names the GPU") },
            short: { type: "choice", instructions: about + " Which label is the best compact name for this GPU in a narrow status bar?", criteria: options(shorts, "None of these names the GPU") }
        }, a => {
            if (!a) return
            root.gpus = root.gpus.map((g, j) => j !== i ? g : Object.assign({}, g, { name: chosen(a.name) || g.name, short: chosen(a.short) || g.short }))
        })
    }

    function askDisplay(i, o, name, suffix) {
        const make = displayName(o.make)
        const cands = uniq([name, (o.make || "") + " " + (o.model || ""), make + " " + (o.model || ""), o.model, make, o.name])
        Jev.ask("display:v1:" + o.make + "|" + o.model + "|" + o.name, { make: o.make, model: o.model, connector: o.name }, {
            name: {
                type: "choice",
                instructions: "`make` and `model` come from a monitor's EDID and may be a registered company name, a hex product code or \"Unknown\"; `connector` is the output port. Which label best names this monitor in a system-information panel?",
                criteria: options(cands, "None of these names the monitor")
            }
        }, a => {
            const pick = chosen(a && a.name)
            if (pick) root.displays = root.displays.map((d, j) => j !== i ? d : Object.assign({}, d, { name: pick + suffix }))
        })
    }

    Process {
        running: true
        command: ["sh", "-c", `
            . /etc/os-release 2>/dev/null
            echo "os=$PRETTY_NAME"
            echo "kernel=$(uname -r)"
            echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2)"
            echo "threads=$(nproc --all)"
            echo "maxFreq=$(cat /sys/devices/system/cpu/cpu[0-9]*/cpufreq/cpuinfo_max_freq 2>/dev/null | sort -n | tail -1)"
            echo "pcpus=$(cat /sys/devices/cpu_core/cpus 2>/dev/null)"
            echo "ecpus=$(cat /sys/devices/cpu_atom/cpus 2>/dev/null)"
            grep -H . /sys/devices/system/cpu/cpu[0-9]*/topology/core_id /sys/devices/system/cpu/cpu[0-9]*/topology/physical_package_id 2>/dev/null | sed 's/^/topo=/'
            if command -v lspci >/dev/null; then
                lspci -mm -D 2>/dev/null | grep -E '"(VGA compatible controller|3D controller|Display controller)"' | while IFS= read -r l; do
                    s=\${l%% *}; d=/sys/bus/pci/devices/$s
                    echo "gpu=$(basename "$(readlink $d/driver)" 2>/dev/null)|$(cat $d/boot_vga 2>/dev/null)|$([ -d $d/hwmon ] && echo 1)|$l"
                done
            else
                for c in /sys/class/drm/card[0-9]; do
                    d=$(readlink -f $c/device); [ -r $d/vendor ] || continue
                    echo "gpu=$(basename "$(readlink $d/driver)")|$(cat $d/boot_vga 2>/dev/null)|$([ -d $d/hwmon ] && echo 1)|x \\"Display\\" \\"$(cat $d/vendor)\\" \\"Device $(cat $d/device)\\""
                done
            fi
            dmi=/sys/devices/virtual/dmi/id
            echo "hostVersion=$(cat $dmi/product_version 2>/dev/null)"
            echo "hostName=$(cat $dmi/product_name 2>/dev/null)"
            echo "sysVendor=$(cat $dmi/sys_vendor 2>/dev/null)"
            echo "board=$(cat $dmi/board_vendor 2>/dev/null) $(cat $dmi/board_name 2>/dev/null)"
            echo "bios=$(cat $dmi/bios_version 2>/dev/null) ($(cat $dmi/bios_date 2>/dev/null))"
            echo "shell=quickshell $(qs --version 2>/dev/null | head -1 | grep -oE '[0-9]+(\\.[0-9]+)+' | head -1)"
            echo "wm=$(niri --version 2>/dev/null | sed 's/ (.*//')"
            echo "memory=$(awk '/^MemTotal/{printf "%.1f GiB", $2/1048576}' /proc/meminfo)"
            echo "rootDisk=$(df -h --output=fstype,used,size,pcent / 2>/dev/null | awk 'NR==2{print $2" of "$3" used ("$4")  ·  "$1}')"
            echo "locale=$LANG"
            echo "session=$XDG_SESSION_TYPE / $XDG_CURRENT_DESKTOP"
            echo "user=$USER@$(hostname)"
            echo "packages=$(nix-store --query --requisites /run/current-system 2>/dev/null | wc -l)"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {}, topo = {}, gpuLines = []
                for (const l of text.split("\n")) {
                    const i = l.indexOf("="); if (i < 0) continue
                    const k = l.slice(0, i), v = l.slice(i + 1).trim()
                    if (k === "topo") {
                        const m = v.match(/cpu(\d+)\/topology\/(\w+):(\d+)/)
                        if (m) (topo[m[1]] = topo[m[1]] || {})[m[2]] = m[3]
                    } else if (k === "gpu") gpuLines.push(v)
                    else kv[k] = v
                }

                for (const k of ["os", "kernel", "board", "shell", "wm", "memory", "rootDisk", "locale", "session", "user"])
                    if (kv[k] !== undefined) root[k] = kv[k]
                root.packages = parseInt(kv.packages) || 0
                root.describeHost(kv, null)
                root.askHost(kv)

                root.cpu = cleanCpu(kv.cpu || "")
                root.cpuShort = root.cpu.replace(/^(Intel|AMD)\s+/, "")
                root.threads = parseInt(kv.threads) || Object.keys(topo).length
                const core = c => topo[c] ? topo[c].physical_package_id + ":" + topo[c].core_id : "cpu" + c
                const cores = new Set(Object.keys(topo).map(core)).size || root.threads
                const p = new Set(expand(kv.pcpus).map(core)).size, e = new Set(expand(kv.ecpus).map(core)).size
                const lp = cores - p - e
                const parts = []
                parts.push(p > 0 && e > 0 ? p + "P + " + e + "E" + (lp > 0 ? " + " + lp + " LP-E" : "") + " cores" : cores + " cores")
                if (root.threads !== cores) parts.push(root.threads + " threads")
                const mhz = parseInt(kv.maxFreq) / 1000
                if (mhz > 0) parts.push("up to " + (mhz / 1000).toFixed(1) + " GHz")
                root.cpuDetail = parts.join("  ·  ")

                const raw = []
                const gs = gpuLines.map(l => {
                    const [driver, boot, hwmon, ...rest] = l.split("|")
                    const q = (rest.join("|").match(/"[^"]*"/g) || []).map(s => s.slice(1, -1))
                    const n = gpuNames(q[1] || "", q[2] || "")
                    raw.push({ vendor: q[1] || "", device: q[2] || "", n })
                    return { name: n.name, short: n.short, driver: driver || "", boot: boot === "1", hwmon: hwmon === "1", primary: false }
                })
                const primary = gs.find(g => g.hwmon) ?? gs.find(g => g.boot) ?? gs[0]
                if (primary) primary.primary = true
                root.gpus = gs
                raw.forEach((r, i) => root.askGpu(i, r.vendor, r.device, r.n))
            }
        }
    }

    Process {
        id: outputs
        running: true
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const outs = Object.values(JSON.parse(text)).filter(o => o.current_mode !== null && o.current_mode !== undefined)
                    root.displays = outs.map(o => {
                        const m = o.modes[o.current_mode]
                        const [w, h] = o.physical_size || [0, 0]
                        const inches = w > 0 && h > 0 ? Math.sqrt(w * w + h * h) / 25.4 : 0
                        const builtin = /^(eDP|LVDS|DSI)/.test(o.name)
                        const badModel = !o.model || /^0x[0-9a-f]+$/i.test(o.model) || /unknown/i.test(o.model)
                        const make = root.displayName(o.make)
                        const name = builtin ? "Built-in display"
                                   : badModel ? (make || o.name)
                                   : (make && !o.model.toLowerCase().startsWith(make.toLowerCase()) ? make + " " : "") + o.model
                        const sub = [m.width + "×" + m.height + " @ " + Math.round(m.refresh_rate / 1000) + " Hz"]
                        if (o.logical && o.logical.scale !== 1) sub.push("scale " + o.logical.scale)
                        if (o.vrr_enabled) sub.push("VRR")
                        sub.push(o.name)
                        const suffix = inches > 0 ? "  " + inches.toFixed(1) + "″" : ""
                        return { name: name + suffix, sub: sub.join("  ·  "), base: name, suffix, builtin }
                    })
                    root.displays.forEach((d, i) => { if (!d.builtin) root.askDisplay(i, outs[i], d.base, d.suffix) })
                } catch (e) { root.displays = [] }
            }
        }
    }
    function refreshDisplays() { outputs.running = true }
}
