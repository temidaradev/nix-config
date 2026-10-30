use std::collections::BTreeMap;
use std::error::Error;
use std::process::exit;
use std::time::Duration;

use bluer::rfcomm::{Profile, ProfileHandle, Role, Stream};
use bluer::{Adapter, Device, Session, Uuid};
use futures::StreamExt;
use serde::Serialize;
use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader, Lines, Stdin, WriteHalf};
use tokio::time::{interval, sleep};

type Res<T> = Result<T, Box<dyn Error>>;
type Input = Lines<BufReader<Stdin>>;
type Table = &'static [(u8, &'static str)];

const UUID: Uuid = Uuid::from_u128(0xaeac4a03_dff5_498f_843a_34487cf133eb);

const ANC: Table = &[(1, "high"), (2, "mid"), (3, "low"), (4, "adaptive"), (5, "off"), (7, "transparency")];
const EQ: Table = &[(1, "rock"), (2, "electronic"), (3, "pop"), (4, "vocals"), (5, "classical"), (6, "custom"), (7, "dirac")];
const SIDE: Table = &[(2, "left"), (3, "right"), (4, "case")];
const GESTURE: Table = &[(2, "tap2"), (3, "tap3"), (7, "hold"), (9, "tap2hold")];
const ACTION: Table = &[
    (0x01, "off"), (0x02, "playpause"), (0x08, "previous"), (0x09, "next"), (0x0B, "assistant"),
    (0x12, "volup"), (0x13, "voldown"), (0x0A, "anc_cycle"), (0x16, "anc_transparency"),
    (0x14, "anc_off"), (0x15, "transparency_off"),
];

const GET_BATTERY: u16 = 0xC007;
const GET_FIRMWARE: u16 = 0xC042;
const GET_INEAR: u16 = 0xC00E;
const GET_ANC: u16 = 0xC01E;
const GET_EQ: u16 = 0xC050;
const GET_BASS: u16 = 0xC04E;
const GET_LATENCY: u16 = 0xC041;
const GET_SPATIAL: u16 = 0xC04F;
const GET_GESTURES: u16 = 0xC018;
const NOTIFY_BATTERY: u16 = 0xE001;
const NOTIFY_ANC: u16 = 0xE003;

const SET_FIND: u16 = 0xF002;
const SET_GESTURE: u16 = 0xF003;
const SET_INEAR: u16 = 0xF004;
const SET_ANC: u16 = 0xF00F;
const SET_EQ: u16 = 0xF01D;
const SET_LATENCY: u16 = 0xF040;
const SET_BASS: u16 = 0xF051;
const SET_SPATIAL: u16 = 0xF052;

const CONTROL: u16 = 0x0120;
const CONTROL_BATTERY: u16 = 0x5120;

fn name(t: Table, code: u8) -> Option<&'static str> {
    t.iter().find(|e| e.0 == code).map(|e| e.1)
}

fn code(t: Table, name: &str) -> Option<u8> {
    t.iter().find(|e| e.1 == name).map(|e| e.0)
}

fn debug() -> bool {
    std::env::var_os("CMF_BUDS_DEBUG").is_some()
}

fn crc16(data: &[u8]) -> u16 {
    let mut crc = 0xFFFFu16;
    for &b in data {
        crc ^= b as u16;
        for _ in 0..8 {
            crc = if crc & 1 != 0 { (crc >> 1) ^ 0xA001 } else { crc >> 1 };
        }
    }
    crc
}

fn frame(cmd: u16, payload: &[u8], control: u16) -> Vec<u8> {
    if debug() {
        eprintln!("-> {cmd:04x} {}", hex(payload));
    }
    let mut out = vec![0x55];
    out.extend_from_slice(&control.to_le_bytes());
    out.extend_from_slice(&cmd.to_le_bytes());
    out.extend_from_slice(&(payload.len() as u16).to_le_bytes());
    out.push(0);
    out.extend_from_slice(payload);
    let crc = crc16(&out);
    out.extend_from_slice(&crc.to_le_bytes());
    out
}

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

#[derive(Serialize, Clone)]
struct Battery {
    level: u8,
    charging: bool,
}

#[derive(Serialize, Clone)]
struct Bass {
    enabled: bool,
    level: u8,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct State {
    connected: bool,
    name: String,
    address: String,
    firmware: String,
    battery: BTreeMap<&'static str, Battery>,
    anc: Option<&'static str>,
    anc_level: &'static str,
    eq: Option<&'static str>,
    bass: Option<Bass>,
    in_ear: Option<bool>,
    low_latency: Option<bool>,
    spatial: Option<bool>,
    gestures: BTreeMap<&'static str, BTreeMap<&'static str, &'static str>>,
    finding: bool,
}

impl Default for State {
    fn default() -> Self {
        State {
            connected: false,
            name: String::new(),
            address: String::new(),
            firmware: String::new(),
            battery: BTreeMap::new(),
            anc: None,
            anc_level: "high",
            eq: None,
            bass: None,
            in_ear: None,
            low_latency: None,
            spatial: None,
            gestures: BTreeMap::new(),
            finding: false,
        }
    }
}

impl State {
    fn emit(&self) {
        println!("{}", serde_json::to_string(self).unwrap());
    }

    fn handle(&mut self, cmd: u16, p: &[u8]) -> bool {
        match cmd {
            GET_BATTERY | NOTIFY_BATTERY if !p.is_empty() => {
                self.battery = p[1..]
                    .chunks_exact(2)
                    .take(p[0] as usize)
                    .filter_map(|c| Some((name(SIDE, c[0])?, Battery { level: c[1] & 0x7F, charging: c[1] & 0x80 != 0 })))
                    .collect();
            }
            GET_ANC | NOTIFY_ANC if p.len() >= 3 => {
                let mode = p[p.len() - 2];
                self.anc = name(ANC, mode).or(self.anc);
                if cmd == GET_ANC && p.len() >= 5 {
                    self.anc_level = name(ANC, p[1]).unwrap_or(self.anc_level);
                }
                if (1..=4).contains(&mode) {
                    self.anc_level = name(ANC, mode).unwrap();
                }
            }
            GET_INEAR if p.len() >= 3 => self.in_ear = Some(p[2] == 1),
            GET_EQ | SET_EQ if !p.is_empty() => self.eq = name(EQ, p[0]).or(self.eq),
            GET_BASS | SET_BASS if !p.is_empty() => {
                let level = p.get(1).map_or(3, |&l| ((l as u16 + 1) / 2).clamp(1, 5) as u8);
                self.bass = Some(Bass { enabled: p[0] == 1, level });
            }
            GET_LATENCY if !p.is_empty() => self.low_latency = Some(p[0] == 1),
            GET_SPATIAL if !p.is_empty() => self.spatial = Some(p[0] == 1),
            GET_FIRMWARE => self.firmware = String::from_utf8_lossy(p).trim_end_matches('\0').to_string(),
            GET_GESTURES if !p.is_empty() => {
                self.gestures.clear();
                for c in p[1..].chunks_exact(4).take(p[0] as usize) {
                    let side = name(SIDE, c[0]).filter(|s| *s != "case");
                    if let (Some(side), Some(kind), Some(act)) = (side, name(GESTURE, c[2]), name(ACTION, c[3])) {
                        self.gestures.entry(side).or_default().insert(kind, act);
                    }
                }
            }
            _ => return false,
        }
        true
    }

    fn command(&mut self, line: &str) -> Option<(Vec<Vec<u8>>, bool)> {
        let a: Vec<&str> = line.split_whitespace().collect();
        let arg = a.get(1).copied().unwrap_or("");
        let on = matches!(arg, "on" | "1" | "true");
        let f = |cmd, p: &[u8]| vec![frame(cmd, p, CONTROL)];
        let frames = match *a.first()? {
            "anc" => {
                let c = code(ANC, arg)?;
                self.anc = name(ANC, c);
                if (1..=4).contains(&c) {
                    self.anc_level = name(ANC, c).unwrap();
                }
                f(SET_ANC, &[1, c, 0])
            }
            "eq" => {
                let c = code(EQ, arg)?;
                self.eq = name(EQ, c);
                f(SET_EQ, &[c, 0])
            }
            "bass" => {
                let current = self.bass.as_ref().map_or(3, |b| b.level);
                let level = a.get(2).and_then(|l| l.parse().ok()).unwrap_or(current).clamp(1, 5);
                self.bass = Some(Bass { enabled: on, level });
                f(SET_BASS, &[on as u8, level * 2])
            }
            "inear" => {
                self.in_ear = Some(on);
                f(SET_INEAR, &[1, 1, on as u8])
            }
            "latency" => {
                self.low_latency = Some(on);
                f(SET_LATENCY, &[if on { 1 } else { 2 }])
            }
            "spatial" => {
                self.spatial = Some(on);
                f(SET_SPATIAL, &[on as u8])
            }
            "find" => {
                self.finding = on;
                f(SET_FIND, &[on as u8])
            }
            "gesture" if a.len() == 4 => {
                let side = code(SIDE, a[1]).filter(|&s| s != 4)?;
                let (kind, act) = (code(GESTURE, a[2])?, code(ACTION, a[3])?);
                self.gestures.entry(name(SIDE, side)?).or_default().insert(name(GESTURE, kind)?, name(ACTION, act)?);
                f(SET_GESTURE, &[1, side, 1, kind, act])
            }
            "refresh" => return Some((queries(), false)),
            _ => return None,
        };
        Some((frames, true))
    }
}

fn queries() -> Vec<Vec<u8>> {
    let mut out = vec![frame(GET_BATTERY, &[], CONTROL_BATTERY)];
    for c in [GET_FIRMWARE, GET_INEAR, GET_ANC, GET_EQ, GET_BASS, GET_LATENCY, GET_SPATIAL, GET_GESTURES] {
        out.push(frame(c, &[], CONTROL));
    }
    out
}

fn parse(buf: &mut Vec<u8>, st: &mut State) -> bool {
    let mut changed = false;
    while buf.len() >= 8 {
        if buf[0] != 0x55 {
            buf.remove(0);
            continue;
        }
        let ctrl = u16::from_le_bytes([buf[1], buf[2]]);
        let cmd = u16::from_le_bytes([buf[3], buf[4]]);
        let n = u16::from_le_bytes([buf[5], buf[6]]) as usize;
        let total = 8 + n + if ctrl & 0x20 != 0 { 2 } else { 0 };
        if buf.len() < total {
            break;
        }
        let payload: Vec<u8> = buf[8..8 + n].to_vec();
        buf.drain(..total);
        if debug() {
            eprintln!("<- {:04x} ctrl={ctrl:04x} {}", cmd | 0x8000, hex(&payload));
        }
        if ctrl & 0x1F == 0 {
            changed |= st.handle(cmd | 0x8000, &payload);
        }
    }
    changed
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
    let want_name = std::env::var("CMF_BUDS_NAME").unwrap_or_else(|_| "CMF Buds".into());
    let want_addr = std::env::var("CMF_BUDS_ADDRESS").unwrap_or_default().to_uppercase();
    for addr in adapter.device_addresses().await? {
        let dev = adapter.device(addr)?;
        if !dev.is_connected().await? {
            continue;
        }
        let name = dev.name().await?.unwrap_or_default();
        let addr = addr.to_string();
        let hit = if want_addr.is_empty() { name.starts_with(&want_name) } else { addr == want_addr };
        if hit {
            return Ok(Some((dev, name, addr)));
        }
    }
    Ok(None)
}

async fn connect(dev: &Device, handle: &mut ProfileHandle) -> Res<Stream> {
    let request = dev.connect_profile(&UUID);
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

async fn write_all(wr: &mut WriteHalf<Stream>, frames: Vec<Vec<u8>>) -> Res<()> {
    for f in frames {
        wr.write_all(&f).await?;
        sleep(Duration::from_millis(30)).await;
    }
    Ok(())
}

async fn run(stream: Stream, st: &mut State, input: &mut Input) -> Res<()> {
    let (mut rd, mut wr) = tokio::io::split(stream);
    write_all(&mut wr, queries()).await?;
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
                if parse(&mut buf, st) {
                    st.emit();
                }
            }
            line = next_line(input) => {
                if let Some((frames, changed)) = st.command(line.trim()) {
                    if changed {
                        st.emit();
                    }
                    write_all(&mut wr, frames).await?;
                }
            }
            _ = battery.tick() => wr.write_all(&frame(GET_BATTERY, &[], CONTROL_BATTERY)).await?,
        }
    }
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> Res<()> {
    let session = Session::new().await?;
    let adapter = session.default_adapter().await?;
    let mut handle = session
        .register_profile(Profile {
            uuid: UUID,
            name: Some("cmf-buds".into()),
            role: Some(Role::Client),
            require_authentication: Some(false),
            require_authorization: Some(false),
            auto_connect: Some(false),
            ..Default::default()
        })
        .await?;
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
        let stream = match connect(&dev, &mut handle).await {
            Ok(s) => s,
            Err(e) => {
                eprintln!("connect {address}: {e}");
                idle(&mut input, Duration::from_secs(5)).await;
                continue;
            }
        };
        st = State { connected: true, name, address, ..Default::default() };
        st.emit();
        if let Err(e) = run(stream, &mut st, &mut input).await {
            eprintln!("session: {e}");
        }
        st = State::default();
        st.emit();
        idle(&mut input, Duration::from_secs(2)).await;
    }
}
