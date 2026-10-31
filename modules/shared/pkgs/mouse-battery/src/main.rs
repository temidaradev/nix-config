//! Battery for wireless mice that have no UPower support, as JSON lines.
//!
//! * LXDDZ / Xenta 2.4G receivers (1d57:fa60, fa65), used by Attack Shark and
//!   other brands. The receiver's vendor interface (report id 3, usage page
//!   0x0a) sends a heartbeat every few seconds: `03 xx 41 <online> <pct>`.
//!   Nothing has to be sent; ACKs (`03 xx 50`) and button events (`03 xx 30`)
//!   share the report id.
//! * Razer mice (1532:*), using the protocol documented by openrazer: a 90-byte
//!   feature report on interface 0 with transaction id, class/id, args and an
//!   XOR checksum. Battery is class 07 id 80 (args[1] = 0..255), charging is
//!   07 84. Polled every 30 s.
//!
//! Output: one line per change on stdout:
//!   {"mice":[{"id":"…","name":"…","connected":true,"level":96,"charging":false}]}

use std::collections::BTreeMap;
use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::os::fd::AsRawFd;
use std::path::Path;
use std::sync::mpsc::{self, Sender};
use std::thread;
use std::time::{Duration, Instant};

const LXDDZ_IDS: &[&str] = &["00001D57:0000FA60", "00001D57:0000FA65"];
const RAZER_VID: &str = "00001532:";
// No LXDDZ heartbeat for this long → mouse is off or asleep.
const STALE: Duration = Duration::from_secs(20);
const RAZER_POLL: Duration = Duration::from_secs(30);

fn debug() -> bool { std::env::var_os("MOUSE_BATTERY_DEBUG").is_some() }
fn hex(b: &[u8]) -> String { b.iter().map(|b| format!("{b:02x}")).collect() }

#[derive(PartialEq, Clone, Debug)]
struct Mouse { name: String, connected: bool, level: i32, charging: bool }

/// (id, Some(state)) to set, (id, None) to remove.
type Update = (String, Option<Mouse>);

struct Hidraw { node: String, sys: std::path::PathBuf, uevent: String, descriptor: Vec<u8> }

fn hidraws() -> Vec<Hidraw> {
    let mut out = vec![];
    let Ok(dir) = fs::read_dir("/sys/class/hidraw") else { return out };
    for e in dir.flatten() {
        let p = e.path();
        out.push(Hidraw {
            node: format!("/dev/{}", e.file_name().to_string_lossy()),
            sys: fs::canonicalize(p.join("device")).unwrap_or_default(),
            uevent: fs::read_to_string(p.join("device/uevent")).unwrap_or_default(),
            descriptor: fs::read(p.join("device/report_descriptor")).unwrap_or_default(),
        });
    }
    out.sort_by(|a, b| a.node.cmp(&b.node));
    out
}

fn uevent_field(ue: &str, key: &str) -> String {
    ue.lines().find_map(|l| l.strip_prefix(key)).unwrap_or("").to_string()
}

/// USB interface number of a hidraw's parent ("…/1-4:1.0/0003:…" → 0).
fn interface(sys: &Path) -> Option<u32> {
    let iface = sys.parent()?.file_name()?.to_string_lossy().to_string();
    iface.rsplit('.').next()?.parse().ok()
}

// ── LXDDZ ────────────────────────────────────────────────────────────────────

fn lxddz(tx: Sender<Update>) {
    let name = std::env::var("MOUSE_NAME").unwrap_or_else(|_| "Mouse".into());
    let id = "lxddz".to_string();
    loop {
        let nodes: Vec<String> = hidraws().into_iter()
            .filter(|h| LXDDZ_IDS.iter().any(|i| h.uevent.contains(i)))
            .filter(|h| h.descriptor.windows(4).any(|w| w == [0x05, 0x0a, 0x09, 0x00]))
            .map(|h| h.node).collect();
        if nodes.is_empty() { thread::sleep(Duration::from_secs(3)); continue }
        if debug() { eprintln!("lxddz: reading {nodes:?}") }

        let (ptx, prx) = mpsc::channel::<Option<Vec<u8>>>();
        for n in nodes {
            let ptx = ptx.clone();
            thread::spawn(move || {
                let Ok(mut f) = File::open(&n) else { let _ = ptx.send(None); return };
                let mut buf = [0u8; 64];
                loop {
                    match f.read(&mut buf) {
                        Ok(k) if k > 0 => { if ptx.send(Some(buf[..k].to_vec())).is_err() { return } }
                        _ => { let _ = ptx.send(None); return }
                    }
                }
            });
        }
        drop(ptx);

        let mut last = Instant::now() - STALE;
        let mut state = Mouse { name: name.clone(), connected: false, level: -1, charging: false };
        let _ = tx.send((id.clone(), Some(state.clone())));
        loop {
            match prx.recv_timeout(Duration::from_secs(1)) {
                Ok(Some(p)) => {
                    if debug() { eprintln!("lxddz <- {}", hex(&p)) }
                    if p.len() >= 5 && p[0] == 0x03 && p[2] == 0x41 {
                        last = Instant::now();
                        let online = p[3] != 0;
                        let next = Mouse { connected: online, level: if online { (p[4] as i32).min(100) } else { -1 }, ..state.clone() };
                        if next != state { state = next; let _ = tx.send((id.clone(), Some(state.clone()))); }
                    }
                }
                Ok(None) | Err(mpsc::RecvTimeoutError::Disconnected) => break,
                Err(mpsc::RecvTimeoutError::Timeout) => {}
            }
            if state.connected && last.elapsed() > STALE {
                state = Mouse { connected: false, level: -1, ..state.clone() };
                let _ = tx.send((id.clone(), Some(state.clone())));
            }
        }
        let _ = tx.send((id.clone(), None)); // receiver unplugged
        thread::sleep(Duration::from_secs(2));
    }
}

// ── Razer ────────────────────────────────────────────────────────────────────

extern "C" { fn ioctl(fd: i32, req: std::ffi::c_ulong, ...) -> i32; }
const fn hidioc(nr: u64, len: u64) -> std::ffi::c_ulong { ((3 << 30) | (len << 16) | ((b'H' as u64) << 8) | nr) as _ }
const HIDIOCSFEATURE: std::ffi::c_ulong = hidioc(0x06, 91);
const HIDIOCGFEATURE: std::ffi::c_ulong = hidioc(0x07, 91);

/// Send one openrazer-style request, return (status, args[0..80]).
/// Status: 1 busy, 2 ok, 3 failure, 4 timeout (mouse unreachable), 5 unsupported.
fn razer_req(f: &File, tid: u8, class: u8, cmd: u8, size: u8) -> Option<(u8, Vec<u8>)> {
    let mut r = [0u8; 91]; // [0] = report id 0
    r[2] = tid; r[6] = size; r[7] = class; r[8] = cmd;
    r[89] = r[3..89].iter().fold(0, |a, b| a ^ b);
    if unsafe { ioctl(f.as_raw_fd(), HIDIOCSFEATURE, r.as_ptr()) } < 0 { return None }
    for _ in 0..10 {
        thread::sleep(Duration::from_millis(60));
        let mut b = [0u8; 91];
        if unsafe { ioctl(f.as_raw_fd(), HIDIOCGFEATURE, b.as_mut_ptr()) } < 0 { return None }
        if debug() { eprintln!("razer {class:02x}{cmd:02x} <- {}", hex(&b[1..12])) }
        if b[1] != 1 && b[7] == class && b[8] == cmd { return Some((b[1], b[9..89].to_vec())) }
    }
    Some((1, vec![]))
}

fn razer(tx: Sender<Update>) {
    // node → transaction id that worked
    let mut tids: BTreeMap<String, u8> = BTreeMap::new();
    let mut known: BTreeMap<String, Mouse> = BTreeMap::new();
    loop {
        let all = hidraws();
        // Razer interface-0 nodes of USB devices that expose a mouse somewhere.
        let mice: Vec<&Hidraw> = all.iter()
            .filter(|h| h.uevent.contains(RAZER_VID) && interface(&h.sys) == Some(0))
            .filter(|h| {
                let usb = h.sys.parent().and_then(|p| p.parent());
                all.iter().any(|o| o.sys.parent().and_then(|p| p.parent()) == usb
                    && o.descriptor.windows(4).any(|w| w == [0x05, 0x01, 0x09, 0x02]))
            })
            .collect();

        let mut seen = vec![];
        for h in mice {
            let id = format!("razer:{}", h.sys.parent().and_then(|p| p.parent()).map(|p| p.display().to_string()).unwrap_or_default());
            seen.push(id.clone());
            let name = uevent_field(&h.uevent, "HID_NAME=").replacen("Razer Razer ", "Razer ", 1);
            let Ok(f) = OpenOptions::new().read(true).write(true).open(&h.node) else { continue };

            let candidates: Vec<u8> = match tids.get(&h.node) { Some(t) => vec![*t], None => vec![0x1f, 0x3f, 0xff] };
            let mut state = Mouse { name, connected: false, level: -1, charging: false };
            for tid in candidates {
                match razer_req(&f, tid, 0x07, 0x80, 0x02) {
                    Some((2, a)) => {
                        tids.insert(h.node.clone(), tid);
                        state.connected = true;
                        state.level = ((a[1] as i32) * 100 + 127) / 255;
                        if let Some((2, c)) = razer_req(&f, tid, 0x07, 0x84, 0x02) { state.charging = c[1] != 0 }
                        break;
                    }
                    _ => continue, // asleep / out of range / wrong tid
                }
            }
            if known.get(&id) != Some(&state) {
                known.insert(id.clone(), state.clone());
                let _ = tx.send((id, Some(state)));
            }
        }
        let gone: Vec<String> = known.keys().filter(|k| !seen.contains(k)).cloned().collect();
        for id in gone { known.remove(&id); let _ = tx.send((id, None)); }
        tids.retain(|n, _| all.iter().any(|h| &h.node == n));

        // poll faster while nothing answers, so a woken mouse shows up soon
        let wait = if known.values().all(|m| m.connected) { RAZER_POLL } else { Duration::from_secs(10) };
        thread::sleep(wait);
    }
}

// ── main ─────────────────────────────────────────────────────────────────────

fn json_str(s: &str) -> String {
    let mut o = String::from("\"");
    for c in s.chars() {
        match c { '"' => o.push_str("\\\""), '\\' => o.push_str("\\\\"), c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)), c => o.push(c) }
    }
    o.push('"');
    o
}

fn emit(mice: &BTreeMap<String, Mouse>) {
    let items: Vec<String> = mice.iter().map(|(id, m)| format!(
        "{{\"id\":{},\"name\":{},\"connected\":{},\"level\":{},\"charging\":{}}}",
        json_str(id), json_str(&m.name), m.connected, m.level, m.charging
    )).collect();
    let mut o = std::io::stdout().lock();
    let _ = writeln!(o, "{{\"mice\":[{}]}}", items.join(","));
    let _ = o.flush();
}

fn main() {
    let (tx, rx) = mpsc::channel::<Update>();
    { let tx = tx.clone(); thread::spawn(move || lxddz(tx)); }
    thread::spawn(move || razer(tx));

    let mut mice = BTreeMap::new();
    emit(&mice);
    for (id, m) in rx {
        let changed = match m {
            Some(m) => mice.insert(id, m.clone()).as_ref() != Some(&m),
            None => mice.remove(&id).is_some(),
        };
        if changed { emit(&mice) }
    }
}
