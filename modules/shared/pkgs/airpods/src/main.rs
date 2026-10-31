//! AirPods control over Apple's AAP (L2CAP PSM 0x1001), as JSON lines.
//!
//! Protocol as reverse engineered by LibrePods (github.com/kavishdevar/librepods):
//!   handshake  00 00 04 00 01 00 02 00 00..      → ack 01 00 04 00 …
//!   features   04 00 04 00 4d 00 d7 00 00..      → ack 04 00 04 00 2b 00 …
//!   notify     04 00 04 00 0f 00 ff ff ff ff     → device starts pushing state
//! Every later packet is `04 00 04 00 <opcode> 00 <payload>`:
//!   04 battery   count, then count × [component, 01, level, status, 01]
//!                component 02 right / 04 left / 08 case; status 01 charging,
//!                02 discharging, 04 not present
//!   06 in-ear    primary, secondary (00 in ear, 01 out, 02 in case)
//!   09 control   id, v1, v2, v3, v4 (both directions: set and notify)
//!   1a rename    01, len, 00, utf-8 name
//!
//! stdin commands: anc off|nc|transparency|adaptive, strength <0-100>,
//! ca|advol|offoption|onebud|swipe|eardetect|casetone|sleep on|off, chime <0-100>,
//! cycle <mask>, mic|pressspeed|holdduration|swipespeed <n>, callcontrol mute|end,
//! eq on|off, eqbands <low> <mid> <high>, rename <name>, raw <hex>, refresh.

use std::collections::BTreeMap;
use std::error::Error;
use std::process::exit;
use std::time::Duration;

use bluer::l2cap::{SeqPacket, SocketAddr};
use bluer::{Adapter, AddressType, Device, Session};
use serde::Serialize;
use tokio::io::{AsyncBufReadExt, BufReader, Lines, Stdin};
use tokio::time::{interval, sleep, timeout};

type Res<T> = Result<T, Box<dyn Error>>;
type Input = Lines<BufReader<Stdin>>;

const PSM: u16 = 0x1001;
const APPLE: u32 = 0x004c;

const HANDSHAKE: &str = "00000400010002000000000000000000";
const FEATURES: &str = "040004004d00d700000000000000";
const NOTIFY: &str = "040004000f00ffffffff";

// control command ids (op 09)
const C_LISTENING: u8 = 0x0d;
const C_EAR_DETECT: u8 = 0x0a;
const C_CYCLE: u8 = 0x1a;
const C_ONE_BUD: u8 = 0x1b;
const C_CHIME: u8 = 0x1f;
const C_SWIPE: u8 = 0x25;
const C_ADVOL: u8 = 0x26;
const C_CA: u8 = 0x28;
const C_STRENGTH: u8 = 0x2e;
const C_CASE_TONE: u8 = 0x31;
const C_OFF_OPTION: u8 = 0x34;
const C_SLEEP: u8 = 0x35;
const C_MIC: u8 = 0x01;
const C_PRESS_SPEED: u8 = 0x17;
const C_HOLD_DURATION: u8 = 0x18;
const C_SWIPE_SPEED: u8 = 0x23;
const C_CALL: u8 = 0x24;

fn debug() -> bool { std::env::var_os("AIRPODS_DEBUG").is_some() }
fn hex(b: &[u8]) -> String { b.iter().map(|b| format!("{b:02x}")).collect() }
fn unhex(s: &str) -> Option<Vec<u8>> {
    let s: String = s.chars().filter(|c| !c.is_whitespace()).collect();
    if s.len() % 2 != 0 { return None }
    (0..s.len()).step_by(2).map(|i| u8::from_str_radix(&s[i..i + 2], 16).ok()).collect()
}
fn control(id: u8, v: [u8; 4]) -> Vec<u8> { vec![0x04, 0x00, 0x04, 0x00, 0x09, 0x00, id, v[0], v[1], v[2], v[3]] }
fn flag(on: bool) -> u8 { if on { 1 } else { 2 } }

#[derive(Serialize, Clone, Default, PartialEq)]
struct Pod { level: i32, charging: bool }

#[derive(Serialize, Clone, Default)]
struct Info { model: String, serial: String, firmware: String }

#[derive(Serialize, Clone, Default)]
struct Eq { on: bool, low: i32, mid: i32, high: i32 }

#[derive(Serialize, Default)]
#[serde(rename_all = "camelCase")]
struct State {
    info: Option<Info>,
    eq: Option<Eq>,
    /// Conversation Awareness: the wearer is talking right now
    speaking: bool,
    /// 0 auto, 1 always right, 2 always left
    mic: Option<i32>,
    /// 0 default, 1 slower, 2 slowest
    press_speed: Option<i32>,
    hold_duration: Option<i32>,
    /// 1 default, 2 longer, 3 longest
    swipe_speed: Option<i32>,
    /// "mute": press once mutes, twice hangs up; "end": the other way round
    call_control: Option<&'static str>,
    connected: bool,
    name: String,
    address: String,
    model: String,
    left: Option<Pod>,
    right: Option<Pod>,
    case: Option<Pod>,
    /// "ear" | "out" | "case"
    left_ear: Option<&'static str>,
    right_ear: Option<&'static str>,
    /// "off" | "nc" | "transparency" | "adaptive"
    anc: Option<&'static str>,
    strength: Option<i32>,
    conversation: Option<bool>,
    adaptive_volume: Option<bool>,
    off_option: Option<bool>,
    one_bud: Option<bool>,
    swipe: Option<bool>,
    ear_detect: Option<bool>,
    case_tone: Option<bool>,
    sleep_detect: Option<bool>,
    chime: Option<i32>,
    /// press-and-hold cycle bitmask: 1 off, 2 nc, 4 transparency, 8 adaptive
    cycle: Option<i32>,
    /// every control value seen, id → hex, for poking at unknown ones
    controls: BTreeMap<String, String>,
    #[serde(skip)]
    primary_left: bool,
}

const MODES: [&str; 4] = ["off", "nc", "transparency", "adaptive"];

fn on_off(v: u8) -> Option<bool> { match v { 1 => Some(true), 2 => Some(false), _ => None } }

impl State {
    fn emit(&self) {
        if let Ok(s) = serde_json::to_string(self) { println!("{s}") }
    }

    fn handle(&mut self, p: &[u8]) -> bool {
        if p.len() < 6 || p[..4] != [0x04, 0x00, 0x04, 0x00] { return false }
        let op = p[4];
        let d = &p[6..];
        match op {
            0x04 if !d.is_empty() => {
                let n = d[0] as usize;
                let mut first = true;
                for c in d[1..].chunks(5).take(n) {
                    if c.len() < 4 { break }
                    let pod = if c[3] == 0x04 { None } else { Some(Pod { level: c[2] as i32, charging: c[3] == 0x01 }) };
                    match c[0] {
                        0x04 => { self.left = pod; if first { self.primary_left = true } }
                        0x02 => { self.right = pod; if first { self.primary_left = false } }
                        0x08 => self.case = pod,
                        _ => {}
                    }
                    first = false;
                }
                true
            }
            0x06 if d.len() >= 2 => {
                let ear = |b: u8| match b { 0 => Some("ear"), 1 => Some("out"), 2 => Some("case"), _ => None };
                let (a, b) = (ear(d[0]), ear(d[1]));
                if self.primary_left { self.left_ear = a; self.right_ear = b } else { self.right_ear = a; self.left_ear = b }
                true
            }
            0x09 if d.len() >= 2 => {
                let (id, v) = (d[0], d[1]);
                self.controls.insert(format!("{id:02x}"), hex(&d[1..]));
                match id {
                    C_LISTENING => self.anc = MODES.get((v as usize).wrapping_sub(1)).copied(),
                    C_STRENGTH => self.strength = Some(v as i32),
                    C_CA => self.conversation = on_off(v),
                    C_ADVOL => self.adaptive_volume = on_off(v),
                    C_OFF_OPTION => self.off_option = on_off(v),
                    C_ONE_BUD => self.one_bud = on_off(v),
                    C_SWIPE => self.swipe = on_off(v),
                    C_EAR_DETECT => self.ear_detect = on_off(v),
                    C_CASE_TONE => self.case_tone = on_off(v),
                    C_SLEEP => self.sleep_detect = on_off(v),
                    C_CHIME => self.chime = Some(v as i32),
                    C_CYCLE => self.cycle = Some(v as i32),
                    C_MIC => self.mic = Some(v as i32),
                    C_PRESS_SPEED => self.press_speed = Some(v as i32),
                    C_HOLD_DURATION => self.hold_duration = Some(v as i32),
                    C_SWIPE_SPEED => self.swipe_speed = Some(v as i32),
                    C_CALL if d.len() >= 3 => self.call_control = match d[2] { 0x03 => Some("mute"), 0x02 => Some("end"), _ => None },
                    _ => {}
                }
                true
            }
            // device info: NUL-separated strings, the first two are binary
            0x1d => {
                let mut parts = d.split(|b| *b == 0).filter(|s| !s.is_empty()).map(|s| String::from_utf8_lossy(s).into_owned());
                parts.next();
                parts.next();
                let s: Vec<String> = parts.collect();
                // name, model, manufacturer, serial, version1 (firmware), version2, …
                self.info = Some(Info {
                    model: s.get(1).cloned().unwrap_or_default(),
                    serial: s.get(3).cloned().unwrap_or_default(),
                    firmware: s.get(4).cloned().unwrap_or_default(),
                });
                true
            }
            // custom EQ: len(2, LE) 01 state low mid high; state 2 = on
            0x63 if d.len() >= 7 => {
                self.eq = Some(Eq { on: d[3] == 2, low: d[4] as i32, mid: d[5] as i32, high: d[6] as i32 });
                true
            }
            // Conversation Awareness events: 01 voice started, 08/09 feature
            // toggled, anything else voice ended (as LibrePods reads it)
            0x4b if p.len() >= 10 => {
                let speaking = match p[9] { 0x01 => true, 0x08 | 0x09 => return false, _ => false };
                if speaking == self.speaking { return false }
                self.speaking = speaking;
                true
            }
            _ => false,
        }
    }

    /// Packets to send for a stdin command; updates state optimistically.
    fn command(&mut self, line: &str) -> Option<Vec<Vec<u8>>> {
        let (cmd, arg) = line.split_once(' ').unwrap_or((line, ""));
        let arg = arg.trim();
        let on = arg == "on";
        let mut set = |id: u8, field: &mut Option<bool>| { *field = Some(on); Some(vec![control(id, [flag(on), 0, 0, 0])]) };
        match cmd {
            "anc" => {
                let i = MODES.iter().position(|m| *m == arg)?;
                self.anc = Some(MODES[i]);
                Some(vec![control(C_LISTENING, [i as u8 + 1, 0, 0, 0])])
            }
            "strength" => {
                let v: u8 = arg.parse::<u8>().ok()?.min(100);
                self.strength = Some(v as i32);
                Some(vec![control(C_STRENGTH, [v, 0, 0, 0])])
            }
            "chime" => {
                let v: u8 = arg.parse::<u8>().ok()?.min(100);
                self.chime = Some(v as i32);
                Some(vec![control(C_CHIME, [v, 0x50, 0, 0])])
            }
            "mic" | "pressspeed" | "holdduration" | "swipespeed" => {
                let v: u8 = arg.parse().ok()?;
                let (id, max, field) = match cmd {
                    "mic" => (C_MIC, 2, &mut self.mic),
                    "pressspeed" => (C_PRESS_SPEED, 2, &mut self.press_speed),
                    "holdduration" => (C_HOLD_DURATION, 2, &mut self.hold_duration),
                    _ => (C_SWIPE_SPEED, 3, &mut self.swipe_speed),
                };
                if v > max { return None }
                *field = Some(v as i32);
                Some(vec![control(id, [v, 0, 0, 0])])
            }
            "callcontrol" => {
                let (code, name) = match arg { "mute" => (0x03, "mute"), "end" => (0x02, "end"), _ => return None };
                self.call_control = Some(name);
                Some(vec![control(C_CALL, [0x00, code, 0, 0])])
            }
            "eq" | "eqbands" => {
                // never invent bands: only change an EQ the AirPods have reported
                let mut eq = self.eq.clone()?;
                if cmd == "eq" {
                    eq.on = on;
                } else {
                    let v: Vec<i32> = arg.split_whitespace().filter_map(|x| x.parse().ok()).collect();
                    if v.len() != 3 { return None }
                    (eq.low, eq.mid, eq.high) = (v[0].clamp(0, 100), v[1].clamp(0, 100), v[2].clamp(0, 100));
                }
                let p = vec![0x04, 0x00, 0x04, 0x00, 0x63, 0x00, 0x05, 0x00, 0x01, if eq.on { 2 } else { 1 }, eq.low as u8, eq.mid as u8, eq.high as u8];
                self.eq = Some(eq);
                Some(vec![p])
            }
            "cycle" => {
                let v: u8 = arg.parse::<u8>().ok()? & 0x0f;
                if v.count_ones() < 2 { return None } // the stem needs at least two modes
                self.cycle = Some(v as i32);
                Some(vec![control(C_CYCLE, [v, 0, 0, 0])])
            }
            "ca" => set(C_CA, &mut self.conversation),
            "advol" => set(C_ADVOL, &mut self.adaptive_volume),
            "offoption" => set(C_OFF_OPTION, &mut self.off_option),
            "onebud" => set(C_ONE_BUD, &mut self.one_bud),
            "swipe" => set(C_SWIPE, &mut self.swipe),
            "eardetect" => set(C_EAR_DETECT, &mut self.ear_detect),
            "casetone" => set(C_CASE_TONE, &mut self.case_tone),
            "sleep" => set(C_SLEEP, &mut self.sleep_detect),
            "rename" if !arg.is_empty() => {
                let name = arg.as_bytes();
                let mut p = vec![0x04, 0x00, 0x04, 0x00, 0x1a, 0x00, 0x01, name.len().min(255) as u8, 0x00];
                p.extend_from_slice(&name[..name.len().min(255)]);
                self.name = arg.to_string();
                Some(vec![p])
            }
            "raw" => Some(vec![unhex(arg)?]),
            "refresh" => Some(vec![unhex(NOTIFY)?]),
            _ => None,
        }
    }
}

async fn next_line(input: &mut Input) -> String {
    match input.next_line().await { Ok(Some(l)) => l, _ => exit(0) }
}

async fn idle(input: &mut Input, dur: Duration) {
    tokio::select! { _ = sleep(dur) => {} _ = next_line(input) => {} }
}

async fn find_device(adapter: &Adapter) -> Res<Option<(Device, String, String)>> {
    let want_addr = std::env::var("AIRPODS_ADDRESS").unwrap_or_default().to_uppercase();
    for addr in adapter.device_addresses().await? {
        let dev = adapter.device(addr)?;
        if !dev.is_connected().await? { continue }
        let name = dev.alias().await.unwrap_or_default();
        let modalias = dev.modalias().await.ok().flatten();
        let model = modalias.as_ref().filter(|m| m.vendor == APPLE).map(|m| format!("{:04x}", m.product));
        let hit = if !want_addr.is_empty() { addr.to_string() == want_addr }
            else { model.as_deref().is_some_and(|p| p.starts_with("20")) || name.contains("AirPods") };
        if hit { return Ok(Some((dev, name, model.unwrap_or_default()))) }
    }
    Ok(None)
}

async fn run(sock: SeqPacket, st: &mut State, input: &mut Input) -> Res<()> {
    let send = |p: Vec<u8>| {
        let sock = &sock;
        async move {
            if debug() { eprintln!("-> {}", hex(&p)) }
            sock.send(&p).await.map(|_| ())
        }
    };
    send(unhex(HANDSHAKE).unwrap()).await?;
    let mut buf = [0u8; 1024];
    let mut ready = false;
    // AirPods only push battery when asked; re-requesting notifications
    // makes them resend it (and ear/noise state) straight away.
    let mut poll = interval(Duration::from_secs(60));
    poll.tick().await;
    loop {
        tokio::select! {
            n = sock.recv(&mut buf) => {
                let n = n?;
                if n == 0 { return Ok(()) }
                let p = &buf[..n];
                if debug() { eprintln!("<- {}", hex(p)) }
                if p.starts_with(&[0x01, 0x00, 0x04, 0x00]) {
                    send(unhex(FEATURES).unwrap()).await?;
                } else if p.starts_with(&[0x04, 0x00, 0x04, 0x00, 0x2b, 0x00]) {
                    if !ready { ready = true; send(unhex(NOTIFY).unwrap()).await?; }
                } else if p == [0x00, 0x01, 0x00, 0x00] {
                    return Ok(()); // AirPods hung up (taken by another device)
                } else if st.handle(p) {
                    st.emit();
                }
            }
            _ = poll.tick() => {
                if ready { send(unhex(NOTIFY).unwrap()).await?; }
            }
            line = next_line(input) => {
                // commands before the AirPods report their state would act on guesses
                if !ready || st.anc.is_none() { continue }
                if let Some(packets) = st.command(line.trim()) {
                    st.emit();
                    for p in packets { send(p).await?; }
                }
            }
        }
    }
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> Res<()> {
    let session = Session::new().await?;
    let adapter = session.default_adapter().await?;
    let mut input = BufReader::new(tokio::io::stdin()).lines();
    let mut st = State::default();
    st.emit();
    loop {
        let (dev, name, model) = match find_device(&adapter).await {
            Ok(Some(found)) => found,
            Ok(None) => { idle(&mut input, Duration::from_secs(5)).await; continue }
            Err(e) => { eprintln!("scan: {e}"); idle(&mut input, Duration::from_secs(5)).await; continue }
        };
        let addr = dev.address();
        let sock = match timeout(Duration::from_secs(10), SeqPacket::connect(SocketAddr::new(addr, AddressType::BrEdr, PSM))).await {
            Ok(Ok(s)) => s,
            Ok(Err(e)) => { eprintln!("connect {addr}: {e}"); idle(&mut input, Duration::from_secs(5)).await; continue }
            Err(_) => { eprintln!("connect {addr}: timed out"); idle(&mut input, Duration::from_secs(5)).await; continue }
        };
        st = State { connected: true, name, address: addr.to_string(), model, ..Default::default() };
        st.emit();
        if let Err(e) = run(sock, &mut st, &mut input).await { eprintln!("session: {e}") }
        st = State::default();
        st.emit();
        idle(&mut input, Duration::from_secs(3)).await;
    }
}
