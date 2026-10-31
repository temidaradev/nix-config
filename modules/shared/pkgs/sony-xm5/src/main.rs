use std::collections::VecDeque;
use std::error::Error;
use std::process::exit;
use std::time::{Duration, Instant};

use bluer::rfcomm::{Profile, ProfileHandle, Role, Stream};
use bluer::{Adapter, Device, Session, Uuid};
use futures::StreamExt;
use serde::Serialize;
use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader, Lines, Stdin, WriteHalf};
use tokio::time::{interval, sleep};

type Res<T> = Result<T, Box<dyn Error>>;
type Input = Lines<BufReader<Stdin>>;
type Table = &'static [(u8, &'static str)];
type Req = (u8, Vec<u8>);

// Sony's MDR control channel; Gadgetbridge prefers V2 when the headset advertises it.
const UUID_V2: Uuid = Uuid::from_u128(0x956c7b26_d49a_4ba8_b03f_b17d393cb6e2);
const UUID_V1: Uuid = Uuid::from_u128(0x96cc203e_5068_46ad_b32d_e316f5e069ba);

const HEADER: u8 = 0x3e;
const TRAILER: u8 = 0x3c;
const ESCAPE: u8 = 0x3d;

const ACK: u8 = 0x01;
const CMD1: u8 = 0x0c;
const CMD2: u8 = 0x0e;

const EQ: Table = &[
    (0x00, "off"), (0x10, "bright"), (0x11, "excited"), (0x12, "mellow"), (0x13, "relaxed"), (0x14, "vocal"),
    (0x15, "treble"), (0x16, "bass"), (0x17, "speech"), (0xa0, "manual"), (0xa1, "custom1"), (0xa2, "custom2"),
];
const CODEC: Table = &[(0x01, "SBC"), (0x02, "AAC"), (0x10, "LDAC"), (0x20, "aptX"), (0x21, "aptX HD")];
const STC_SENSITIVITY: Table = &[(0, "auto"), (1, "high"), (2, "low")];
const STC_TIMEOUT: Table = &[(0, "short"), (1, "standard"), (2, "long"), (3, "off")];
const AUTO_OFF: &[([u8; 2], &str)] = &[
    ([0x11, 0x00], "off"), ([0x00, 0x00], "5m"), ([0x01, 0x01], "30m"),
    ([0x02, 0x02], "1h"), ([0x03, 0x03], "3h"), ([0x10, 0x00], "removed"),
];
// Which modes the NC/AMB button cycles through.
const NC_BUTTON: Table = &[(0x01, "nc_ambient_off"), (0x02, "nc_ambient"), (0x03, "nc_off"), (0x04, "ambient_off")];
const ASSISTANT: Table = &[(0x30, "phone"), (0x31, "google"), (0x32, "alexa"), (0xff, "off")];

// Noise control sub-id: firmware 2.x only answers 0x17 (Gadgetbridge sends 0x15).
const NCASM: u8 = 0x17;
const GET_AUDIO: u8 = 0xe6;
const RET_AUDIO: u8 = 0xe7;
const SET_AUDIO: u8 = 0xe8;
const NOTIFY_AUDIO: u8 = 0xe9;
const SET_SYSTEM_CONTROL: u8 = 0x98;

const INIT: u8 = 0x00;
const INIT_REPLY: u8 = 0x01;
const GET_FIRMWARE: u8 = 0x04;
const RET_FIRMWARE: u8 = 0x05;
const GET_CODEC: u8 = 0x12;
const RET_CODEC: u8 = 0x13;
const NOTIFY_CODEC: u8 = 0x15;
const GET_BATTERY: u8 = 0x22;
const RET_BATTERY: u8 = 0x23;
const SET_POWER: u8 = 0x24;
const NOTIFY_BATTERY: u8 = 0x25;
const GET_POWER_OFF: u8 = 0x26;
const RET_POWER_OFF: u8 = 0x27;
const SET_POWER_OFF: u8 = 0x28;
const NOTIFY_POWER_OFF: u8 = 0x29;
const GET_EQ: u8 = 0x56;
const RET_EQ: u8 = 0x57;
const SET_EQ: u8 = 0x58;
const NOTIFY_EQ: u8 = 0x59;
const GET_ANC: u8 = 0x66;
const RET_ANC: u8 = 0x67;
const SET_ANC: u8 = 0x68;
const NOTIFY_ANC: u8 = 0x69;
const GET_SYSTEM: u8 = 0xf6;
const RET_SYSTEM: u8 = 0xf7;
const SET_SYSTEM: u8 = 0xf8;
const NOTIFY_SYSTEM: u8 = 0xf9;
const GET_STC: u8 = 0xfa;
const RET_STC: u8 = 0xfb;
const SET_STC: u8 = 0xfc;
const NOTIFY_STC: u8 = 0xfd;
const GET_GENERAL: u8 = 0xd6;
const RET_GENERAL: u8 = 0xd7;
const SET_GENERAL: u8 = 0xd8;
const NOTIFY_GENERAL: u8 = 0xd9;
// Connect Two Devices lives at general setting 0xd2 on the XM5 (Gadgetbridge PR #6517).
const MULTIPOINT: u8 = 0xd2;
// Answers on 2.5.1 and isn't multipoint; on other Sony models 0xd2 is the touch panel, so
// with that id taken this is most likely it.
const TOUCH_PANEL: u8 = 0xd1;
// COMMAND_2 payloads
const GET_PAIRING: u8 = 0x32;
const RET_PAIRING: u8 = 0x33;
const SET_PAIRING: u8 = 0x34;
const NOTIFY_PAIRING: u8 = 0x35;
const GET_PEERS: u8 = 0x36;
const RET_PEERS: u8 = 0x37;
const NOTIFY_PEERS: u8 = 0x39;
const SET_PEER: u8 = 0x3c;
const NOTIFY_PEER: u8 = 0x3d;
const GET_GUIDE: u8 = 0x46;
const RET_GUIDE: u8 = 0x47;
const SET_GUIDE: u8 = 0x48;
const NOTIFY_GUIDE: u8 = 0x49;

fn name(t: Table, code: u8) -> Option<&'static str> {
    t.iter().find(|e| e.0 == code).map(|e| e.1)
}

fn code(t: Table, name: &str) -> Option<u8> {
    t.iter().find(|e| e.1 == name).map(|e| e.0)
}

fn debug() -> bool {
    std::env::var_os("SONY_XM5_DEBUG").is_some()
}

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

fn encode(ty: u8, seq: u8, payload: &[u8]) -> Vec<u8> {
    if debug() && ty != ACK {
        eprintln!("-> {ty:02x}/{seq} {}", hex(payload));
    }
    let mut body = vec![ty, seq];
    body.extend_from_slice(&(payload.len() as u32).to_be_bytes());
    body.extend_from_slice(payload);
    body.push(body.iter().fold(0u8, |s, &b| s.wrapping_add(b)));
    let mut out = vec![HEADER];
    for b in body {
        if matches!(b, HEADER | TRAILER | ESCAPE) {
            out.extend_from_slice(&[ESCAPE, b & 0xEF]);
        } else {
            out.push(b);
        }
    }
    out.push(TRAILER);
    out
}

fn decode(raw: &[u8]) -> Option<(u8, u8, Vec<u8>)> {
    let mut m = Vec::with_capacity(raw.len());
    let mut it = raw.iter();
    while let Some(&b) = it.next() {
        m.push(if b == ESCAPE { it.next()? | 0x10 } else { b });
    }
    let (body, chk) = m.split_at(m.len().checked_sub(1)?);
    if body.len() < 6 || body.iter().fold(0u8, |s, &b| s.wrapping_add(b)) != chk[0] {
        return None;
    }
    let n = u32::from_be_bytes(body[2..6].try_into().ok()?) as usize;
    (n == body.len() - 6).then(|| (body[0], body[1], body[6..].to_vec()))
}

#[derive(Serialize, Clone)]
struct Battery {
    level: u8,
    charging: bool,
}

#[derive(Serialize, Clone)]
struct Eq {
    preset: &'static str,
    bass: i8,
    bands: Vec<i8>,
}

// Raw quick access function codes: Gadgetbridge only knows 0 (off) and 1 (Spotify Tap),
// newer firmware reports others, so pass them through untouched.
#[derive(Serialize, Clone)]
struct Quick {
    double: u8,
    triple: u8,
}

#[derive(Serialize, Clone)]
struct Peer {
    address: String,
    name: String,
    connected: bool,
}

// Device list: count, then per device a 17-char ASCII address, 1 or 4 status bytes
// (firmware dependent, first is the connection slot), a name length and the name.
fn parse_peers(p: &[u8], status_len: usize) -> Option<Vec<Peer>> {
    let mut i = 3;
    let mut out = Vec::new();
    for _ in 0..*p.get(2)? {
        let address = std::str::from_utf8(p.get(i..i + 17)?).ok()?;
        let valid = address.split(':').count() == 6 && address.split(':').all(|o| o.len() == 2 && o.chars().all(|c| c.is_ascii_hexdigit()));
        if !valid {
            return None;
        }
        let slot = *p.get(i + 17)?;
        i += 17 + status_len;
        let len = *p.get(i)? as usize;
        let name = String::from_utf8_lossy(p.get(i + 1..i + 1 + len)?).to_string();
        i += 1 + len;
        out.push(Peer { address: address.to_uppercase(), name, connected: slot != 0 });
    }
    out.sort_by_key(|d| !d.connected);
    Some(out)
}

#[derive(Serialize, Default)]
#[serde(rename_all = "camelCase")]
struct State {
    connected: bool,
    name: String,
    address: String,
    firmware: String,
    codec: Option<&'static str>,
    battery: Option<Battery>,
    anc: Option<&'static str>,
    focus_voice: bool,
    ambient_level: u8,
    eq: Option<Eq>,
    speak_to_chat: Option<bool>,
    stc_sensitivity: Option<&'static str>,
    stc_timeout: Option<&'static str>,
    pause_on_remove: Option<bool>,
    auto_off: Option<&'static str>,
    voice_guide: Option<bool>,
    quick: Option<Quick>,
    dsee: Option<bool>,
    sound_quality: Option<bool>,
    nc_button: Option<&'static str>,
    assistant: Option<&'static str>,
    touch_panel: Option<bool>,
    multipoint: Option<bool>,
    pairing: bool,
    peers: Vec<Peer>,
    local_address: String,
    #[serde(skip)]
    want_peers: bool,
}

impl State {
    fn emit(&self) {
        println!("{}", serde_json::to_string(self).unwrap());
    }

    fn handle(&mut self, ty: u8, p: &[u8]) -> bool {
        let n = p.len();
        match (ty, p[0]) {
            (CMD1, RET_FIRMWARE) if n >= 3 && p[1] == 0x02 => {
                self.firmware = String::from_utf8_lossy(&p[3..]).trim_end_matches('\0').to_string();
            }
            (CMD1, RET_CODEC | NOTIFY_CODEC) if n == 3 && p[1] == 0x02 => self.codec = name(CODEC, p[2]),
            (CMD1, RET_BATTERY | NOTIFY_BATTERY) if n >= 4 && p[1] == 0x00 => {
                self.battery = Some(Battery { level: p[2], charging: p[3] == 1 });
            }
            (CMD1, RET_POWER_OFF | NOTIFY_POWER_OFF) if n == 4 && p[1] == 0x05 => {
                self.auto_off = AUTO_OFF.iter().find(|e| e.0 == p[2..4]).map(|e| e.1).or(self.auto_off);
            }
            (CMD1, RET_SYSTEM | NOTIFY_SYSTEM) if n == 3 && p[1] == 0x01 => self.pause_on_remove = Some(p[2] == 0),
            (CMD1, RET_SYSTEM | NOTIFY_SYSTEM) if n == 3 && p[1] == 0x04 => {
                self.assistant = name(ASSISTANT, p[2]).or(self.assistant);
            }
            (CMD1, RET_STC | NOTIFY_STC) if n == 7 && p[1] == 0x03 => self.nc_button = name(NC_BUTTON, p[6]).or(self.nc_button),
            (CMD1, RET_AUDIO | NOTIFY_AUDIO) if n == 3 && p[1] == 0x01 => self.dsee = Some(p[2] == 1),
            (CMD1, RET_AUDIO | NOTIFY_AUDIO) if n == 3 && p[1] == 0x02 => self.sound_quality = Some(p[2] == 0),
            (CMD1, RET_GENERAL | NOTIFY_GENERAL) if n == 4 && p[1] == TOUCH_PANEL && p[2] == 0 => {
                self.touch_panel = Some(p[3] == 0);
            }
            (CMD1, RET_EQ | NOTIFY_EQ) if n == 10 => {
                let preset = name(EQ, p[2]).unwrap_or("manual");
                let bands = p[5..10].iter().map(|&b| b as i8 - 10).collect();
                self.eq = Some(Eq { preset, bass: p[4] as i8 - 10, bands });
            }
            (CMD1, RET_ANC | NOTIFY_ANC) if (7..=8).contains(&n) && matches!(p[1], 0x15 | 0x17) => {
                self.anc = Some(match (p[3], p[4]) {
                    (0, _) => "off",
                    (_, 1) => "ambient",
                    _ => "nc",
                });
                self.focus_voice = p[n - 2] == 1;
                self.ambient_level = p[n - 1].min(20);
            }
            (CMD1, RET_SYSTEM | NOTIFY_SYSTEM) if n == 4 && p[1] == 0x0c => self.speak_to_chat = Some(p[2] == 0),
            (CMD1, RET_SYSTEM | NOTIFY_SYSTEM) if n == 5 && p[1] == 0x0d => self.quick = Some(Quick { double: p[3], triple: p[4] }),
            (CMD1, RET_GENERAL | NOTIFY_GENERAL) if n == 4 && p[1] == MULTIPOINT && p[2] == 0 => {
                self.multipoint = Some(p[3] == 0);
            }
            (CMD2, RET_PEERS | NOTIFY_PEERS) if n >= 3 && p[1] == 0x00 => {
                self.peers = parse_peers(p, 1).or_else(|| parse_peers(p, 4)).unwrap_or_default();
            }
            (CMD2, RET_PAIRING | NOTIFY_PAIRING) if n >= 3 && p[1] == 0x00 => {
                self.pairing = p[2] == 1 && (n < 4 || p[3] == 1);
            }
            (CMD2, NOTIFY_PEER) => {
                self.want_peers = true;
                return false;
            }
            (CMD1, RET_STC | NOTIFY_STC) if n == 4 && p[1] == 0x0c => {
                self.stc_sensitivity = name(STC_SENSITIVITY, p[2]).or(self.stc_sensitivity);
                self.stc_timeout = name(STC_TIMEOUT, p[3]).or(self.stc_timeout);
            }
            (CMD2, RET_GUIDE | NOTIFY_GUIDE) if n == 4 && p[1] == 0x01 => self.voice_guide = Some(p[2] == 0),
            _ => return false,
        }
        true
    }

    fn anc_frame(&self) -> Req {
        let mode = self.anc.unwrap_or("nc");
        let level = self.ambient_level;
        (CMD1, vec![SET_ANC, NCASM, 0x01, (mode != "off") as u8, (mode == "ambient") as u8, self.focus_voice as u8, level])
    }

    fn command(&mut self, line: &str) -> Option<(Vec<Req>, bool)> {
        let a: Vec<&str> = line.split_whitespace().collect();
        let arg = a.get(1).copied().unwrap_or("");
        let on = matches!(arg, "on" | "1" | "true");
        let frames = match *a.first()? {
            "anc" => {
                self.anc = Some(["nc", "ambient", "off"].into_iter().find(|m| *m == arg)?);
                vec![self.anc_frame()]
            }
            "ambient" => {
                self.ambient_level = arg.parse::<u8>().ok()?.min(20);
                self.anc = Some("ambient");
                vec![self.anc_frame()]
            }
            "focus" => {
                self.focus_voice = on;
                vec![self.anc_frame()]
            }
            "eq" => {
                let c = code(EQ, arg)?;
                let eq = self.eq.get_or_insert(Eq { preset: "off", bass: 0, bands: vec![0; 5] });
                eq.preset = name(EQ, c)?;
                vec![(CMD1, vec![SET_EQ, 0x00, c, 0x00])]
            }
            "bands" if a.len() == 7 => {
                let v: Vec<i8> = a[1..].iter().map(|s| s.parse::<i8>().map(|x| x.clamp(-10, 10))).collect::<Result<_, _>>().ok()?;
                self.eq = Some(Eq { preset: "manual", bass: v[0], bands: v[1..].to_vec() });
                let mut p = vec![SET_EQ, 0x00, 0xa0, 0x06];
                p.extend(v.iter().map(|&x| (x + 10) as u8));
                vec![(CMD1, p)]
            }
            "stc" => {
                self.speak_to_chat = Some(on);
                vec![(CMD1, vec![SET_SYSTEM, 0x0c, !on as u8, 0x01])]
            }
            "stcconfig" if a.len() == 3 => {
                let (s, t) = (code(STC_SENSITIVITY, a[1])?, code(STC_TIMEOUT, a[2])?);
                self.stc_sensitivity = name(STC_SENSITIVITY, s);
                self.stc_timeout = name(STC_TIMEOUT, t);
                vec![(CMD1, vec![SET_STC, 0x0c, s, t])]
            }
            "pause" => {
                self.pause_on_remove = Some(on);
                vec![(CMD1, vec![SET_SYSTEM, 0x01, !on as u8])]
            }
            "autooff" => {
                let e = AUTO_OFF.iter().find(|e| e.1 == arg)?;
                self.auto_off = Some(e.1);
                vec![(CMD1, vec![SET_POWER_OFF, 0x05, e.0[0], e.0[1]])]
            }
            "guide" => {
                self.voice_guide = Some(on);
                vec![(CMD2, vec![SET_GUIDE, 0x01, !on as u8])]
            }
            "quick" if a.len() == 3 => {
                let (double, triple) = (a[1].parse().ok()?, a[2].parse().ok()?);
                self.quick = Some(Quick { double, triple });
                vec![(CMD1, vec![SET_SYSTEM, 0x0d, 0x02, double, triple])]
            }
            "dsee" => {
                self.dsee = Some(on);
                vec![(CMD1, vec![SET_AUDIO, 0x01, on as u8])]
            }
            "quality" => {
                self.sound_quality = Some(on);
                vec![(CMD1, vec![SET_AUDIO, 0x02, !on as u8])]
            }
            "ncbutton" => {
                let c = code(NC_BUTTON, arg)?;
                self.nc_button = name(NC_BUTTON, c);
                vec![(CMD1, vec![SET_STC, 0x03, 0x01, 0x35, 0x01, 0x00, c])]
            }
            "touch" => {
                self.touch_panel = Some(on);
                vec![(CMD1, vec![SET_GENERAL, TOUCH_PANEL, 0x00, !on as u8])]
            }
            // Switching to or from Google/Alexa only takes effect after a reboot, like Gadgetbridge does.
            "assistant" => {
                let c = code(ASSISTANT, arg)?;
                self.assistant = name(ASSISTANT, c);
                vec![(CMD1, vec![SET_SYSTEM, 0x04, c]), (CMD1, vec![SET_SYSTEM_CONTROL, 0x00, 0x16, 0x01])]
            }
            "multipoint" => {
                self.multipoint = Some(on);
                vec![(CMD1, vec![SET_GENERAL, MULTIPOINT, 0x00, !on as u8]), (CMD2, vec![GET_PEERS, 0x00])]
            }
            "pairing" => {
                self.pairing = on;
                vec![(CMD2, vec![SET_PAIRING, 0x00, on as u8, 0x00])]
            }
            "peer" if a.len() == 3 => {
                let action = match a[1] {
                    "disconnect" => 0x00,
                    "connect" => 0x01,
                    _ => return None,
                };
                let addr = a[2].to_uppercase();
                if addr.len() != 17 {
                    return None;
                }
                let mut p = vec![SET_PEER, 0x00, action];
                p.extend_from_slice(addr.as_bytes());
                return Some((vec![(CMD2, p)], false));
            }
            "poweroff" => return Some((vec![(CMD1, vec![SET_POWER, 0x03, 0x01])], false)),
            // raw <type> <hex payload>, for poking at the protocol with SONY_XM5_DEBUG set
            "raw" if a.len() == 3 => {
                let ty = u8::from_str_radix(a[1], 16).ok()?;
                let p = (0..a[2].len()).step_by(2).map(|i| u8::from_str_radix(a[2].get(i..i + 2)?, 16).ok()).collect::<Option<Vec<u8>>>()?;
                return Some((vec![(ty, p)], false));
            }
            "refresh" => return Some((queries(), false)),
            _ => return None,
        };
        Some((frames, true))
    }
}

fn queries() -> Vec<Req> {
    vec![
        (CMD1, vec![GET_FIRMWARE, 0x02]),
        (CMD1, vec![GET_CODEC, 0x02]),
        (CMD1, vec![GET_BATTERY, 0x00]),
        (CMD1, vec![GET_ANC, NCASM]),
        (CMD1, vec![GET_EQ, 0x00]),
        (CMD1, vec![GET_SYSTEM, 0x0c]),
        (CMD1, vec![GET_STC, 0x0c]),
        (CMD1, vec![GET_SYSTEM, 0x01]),
        (CMD1, vec![GET_POWER_OFF, 0x05]),
        (CMD1, vec![GET_SYSTEM, 0x0d]),
        (CMD1, vec![GET_SYSTEM, 0x04]),
        (CMD1, vec![GET_STC, 0x03]),
        (CMD1, vec![GET_AUDIO, 0x01]),
        (CMD1, vec![GET_AUDIO, 0x02]),
        (CMD2, vec![GET_GUIDE, 0x01]),
        (CMD1, vec![GET_GENERAL, TOUCH_PANEL]),
        (CMD1, vec![GET_GENERAL, MULTIPOINT]),
        (CMD2, vec![GET_PEERS, 0x00]),
    ]
}

// The headset takes one request at a time: each must be ACKed before the next goes out,
// and the ACK carries the sequence number for the following request.
struct Link {
    wr: WriteHalf<Stream>,
    seq: u8,
    queue: VecDeque<Req>,
    pending: Option<Instant>,
    ready: bool,
    init_tries: u8,
}

impl Link {
    async fn pump(&mut self) -> Res<()> {
        if self.pending.is_none() {
            if let Some((ty, p)) = self.queue.pop_front() {
                self.wr.write_all(&encode(ty, self.seq, &p)).await?;
                self.pending = Some(Instant::now());
            }
        }
        Ok(())
    }

    async fn ack(&mut self, seq: u8) -> Res<()> {
        self.wr.write_all(&encode(ACK, 1 - seq, &[])).await?;
        Ok(())
    }

    async fn tick(&mut self) -> Res<()> {
        if self.pending.is_some_and(|t| t.elapsed() > Duration::from_millis(1500)) {
            self.pending = None;
            if !self.ready {
                self.init_tries += 1;
                if self.init_tries >= 3 {
                    return Err("no reply to init".into());
                }
                self.queue.push_front((CMD1, vec![INIT, 0x00]));
            }
        }
        self.pump().await
    }
}

fn split_frames(buf: &mut Vec<u8>) -> Vec<(u8, u8, Vec<u8>)> {
    let mut out = Vec::new();
    loop {
        match buf.iter().position(|&b| b == HEADER) {
            Some(i) => drop(buf.drain(..i)),
            None => {
                buf.clear();
                break;
            }
        }
        let Some(end) = buf.iter().position(|&b| b == TRAILER) else { break };
        let raw: Vec<u8> = buf.drain(..=end).collect();
        match decode(&raw[1..raw.len() - 1]) {
            Some(m) => out.push(m),
            None if debug() => eprintln!("<- bad frame {}", hex(&raw)),
            None => {}
        }
    }
    out
}

async fn next_line(input: &mut Input) -> String {
    match input.next_line().await {
        Ok(Some(line)) => line,
        _ => exit(0),
    }
}

async fn idle(input: &mut Input, dur: Duration) {
    tokio::select! {
        _ = sleep(dur) => {}
        _ = next_line(input) => {}
    }
}

async fn find_device(adapter: &Adapter) -> Res<Option<(Device, String, String)>> {
    let want_name = std::env::var("SONY_XM5_NAME").unwrap_or_else(|_| "WH-1000XM5".into());
    let want_addr = std::env::var("SONY_XM5_ADDRESS").unwrap_or_default().to_uppercase();
    for addr in adapter.device_addresses().await? {
        let dev = adapter.device(addr)?;
        if !dev.is_connected().await? {
            continue;
        }
        let name = dev.name().await?.unwrap_or_default();
        let addr = addr.to_string();
        let hit = if want_addr.is_empty() { name.contains(&want_name) } else { addr == want_addr };
        if hit {
            return Ok(Some((dev, name, addr)));
        }
    }
    Ok(None)
}

async fn connect(dev: &Device, handles: &mut [(Uuid, ProfileHandle); 2]) -> Res<Stream> {
    let uuids = dev.uuids().await?.unwrap_or_default();
    let i = handles.iter().position(|(u, _)| uuids.contains(u)).unwrap_or(1);
    let (uuid, handle) = &mut handles[i];
    let request = dev.connect_profile(uuid);
    tokio::pin!(request);
    let deadline = sleep(Duration::from_secs(15));
    tokio::pin!(deadline);
    let mut requested = false;
    loop {
        tokio::select! {
            r = &mut request, if !requested => {
                requested = true;
                r?;
            }
            req = handle.next() => return Ok(req.ok_or("profile unregistered")?.accept()?),
            _ = &mut deadline => return Err("timed out waiting for the control channel".into()),
        }
    }
}

async fn run(stream: Stream, st: &mut State, input: &mut Input) -> Res<()> {
    let (mut rd, wr) = tokio::io::split(stream);
    // Writing straight after the channel opens gets ignored.
    sleep(Duration::from_millis(500)).await;
    let mut link = Link { wr, seq: 0, queue: VecDeque::from([(CMD1, vec![INIT, 0x00])]), pending: None, ready: false, init_tries: 0 };
    link.pump().await?;
    let mut ticker = interval(Duration::from_millis(250));
    let mut battery = interval(Duration::from_secs(60));
    battery.tick().await;
    let mut buf = Vec::new();
    let mut chunk = [0u8; 1024];
    loop {
        tokio::select! {
            n = rd.read(&mut chunk) => {
                let n = n?;
                if n == 0 {
                    return Ok(());
                }
                buf.extend_from_slice(&chunk[..n]);
                let mut changed = false;
                for (ty, seq, p) in split_frames(&mut buf) {
                    if ty == ACK {
                        if seq != link.seq {
                            link.seq = seq;
                            link.pending = None;
                        }
                        continue;
                    }
                    if debug() {
                        eprintln!("<- {ty:02x}/{seq} {}", hex(&p));
                    }
                    link.ack(seq).await?;
                    if p.is_empty() {
                        continue;
                    }
                    if ty == CMD1 && p[0] == INIT_REPLY && !link.ready {
                        if p.len() != 8 {
                            eprintln!("init reply {} doesn't look like protocol v2", hex(&p));
                        }
                        link.ready = true;
                        link.queue.extend(queries());
                        continue;
                    }
                    changed |= st.handle(ty, &p);
                    if std::mem::take(&mut st.want_peers) {
                        link.queue.push_back((CMD2, vec![GET_PEERS, 0x00]));
                    }
                }
                if changed {
                    st.emit();
                }
                link.pump().await?;
            }
            line = next_line(input) => {
                if !link.ready {
                    continue;
                }
                if let Some((frames, changed)) = st.command(line.trim()) {
                    if changed {
                        st.emit();
                    }
                    link.queue.extend(frames);
                    link.pump().await?;
                }
            }
            _ = ticker.tick() => link.tick().await?,
            _ = battery.tick() => {
                if link.ready {
                    link.queue.push_back((CMD1, vec![GET_BATTERY, 0x00]));
                    link.pump().await?;
                }
            }
        }
    }
}

async fn profile(session: &Session, uuid: Uuid, name: &str) -> Res<(Uuid, ProfileHandle)> {
    let handle = session
        .register_profile(Profile {
            uuid,
            name: Some(name.into()),
            role: Some(Role::Client),
            require_authentication: Some(false),
            require_authorization: Some(false),
            auto_connect: Some(false),
            ..Default::default()
        })
        .await?;
    Ok((uuid, handle))
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> Res<()> {
    let session = Session::new().await?;
    let adapter = session.default_adapter().await?;
    let local_address = adapter.address().await?.to_string();
    let mut handles = [profile(&session, UUID_V2, "sony-xm5-v2").await?, profile(&session, UUID_V1, "sony-xm5-v1").await?];
    let mut input = BufReader::new(tokio::io::stdin()).lines();
    let mut st = State::default();
    st.emit();
    loop {
        let (dev, name, address) = match find_device(&adapter).await {
            Ok(Some(found)) => found,
            Ok(None) => {
                idle(&mut input, Duration::from_secs(5)).await;
                continue;
            }
            Err(e) => {
                eprintln!("scan: {e}");
                idle(&mut input, Duration::from_secs(5)).await;
                continue;
            }
        };
        let stream = match connect(&dev, &mut handles).await {
            Ok(s) => s,
            Err(e) => {
                eprintln!("connect {address}: {e}");
                idle(&mut input, Duration::from_secs(5)).await;
                continue;
            }
        };
        st = State { connected: true, name, address, local_address: local_address.clone(), ..Default::default() };
        st.emit();
        if let Err(e) = run(stream, &mut st, &mut input).await {
            eprintln!("session: {e}");
        }
        st = State::default();
        st.emit();
        idle(&mut input, Duration::from_secs(2)).await;
    }
}
