//! A dnf-style model of Nix's `internal-json` log stream, replacing
//! nix-output-monitor.
//!
//! dnf knows its whole transaction before it starts; Nix discovers the work as
//! it goes and keeps revising its own totals. To get stable `[n/total]`
//! counters we therefore ask for the plan up front with `--dry-run`, and treat
//! that as the transaction: the log stream only tells us what has *finished*.
//!
//! Within the stream, the activities that matter are `actCopyPath` (a path
//! being substituted, carrying byte progress) and `actBuild` (a derivation
//! being built, carrying its phase).
//!
//! Nothing here writes to the terminal. Rows are rendered as ANSI strings and
//! handed to the TUI, which turns them into widgets.

use std::{
    collections::{HashMap, HashSet},
    io::{BufRead, BufReader},
    process::{Child, ChildStderr, Command, ExitStatus, Stdio},
    sync::mpsc::{Receiver, TryRecvError, channel},
    time::{Duration, Instant},
};

use eyre::{Context as _, Result};
use serde::Deserialize;
use serde_json::Value;

// Activity types, from Nix's `logging.hh`.
const ACT_COPY_PATH: u64 = 100;
const ACT_BUILD: u64 = 105;

// Result types.
const RES_BUILD_LOG_LINE: u64 = 101;
const RES_SET_PHASE: u64 = 104;
const RES_PROGRESS: u64 = 105;

const LOG_TAIL: usize = 40;

/// The transaction, as reported by `nix build --dry-run`.
#[derive(Default)]
pub struct Plan {
    pub builds: usize,
    pub fetches: HashSet<String>,
    /// Nix's own size note, e.g. "22.54 MiB download, 22.99 MiB unpacked".
    pub sizes: Option<String>,
}

/// Parses the plan out of `nix build --dry-run`'s stderr.
///
/// The shape is a header line naming a section, followed by indented store
/// paths, e.g. "these 101 paths will be fetched (22.54 MiB download, ...):".
pub fn parse_plan(stderr: &str) -> Plan {
    enum Section {
        None,
        Build,
        Fetch,
    }

    let mut plan = Plan::default();
    let mut section = Section::None;

    for line in stderr.lines() {
        let trimmed = line.trim();

        if trimmed.contains("will be built") {
            section = Section::Build;
            continue;
        }
        if trimmed.contains("will be fetched") {
            section = Section::Fetch;
            plan.sizes = trimmed
                .split_once('(')
                .and_then(|(_, rest)| rest.split_once(')'))
                .map(|(note, _)| note.to_owned());
            continue;
        }

        if !trimmed.starts_with("/nix/store/") {
            // Any other unindented text ends the list.
            if !line.starts_with(' ') && !trimmed.is_empty() {
                section = Section::None;
            }
            continue;
        }

        match section {
            Section::Build => plan.builds += 1,
            Section::Fetch => {
                plan.fetches.insert(trimmed.to_owned());
            }
            Section::None => {}
        }
    }

    plan
}

#[derive(Deserialize)]
struct Event {
    action: String,
    #[serde(default)]
    id: u64,
    #[serde(default)]
    fields: Vec<Value>,
    #[serde(default, rename = "type")]
    kind: u64,
    #[serde(default)]
    msg: Option<String>,
    #[serde(default)]
    level: u64,
}

// Nix mixes strings and integers in `fields`, positionally, so they are read
// back by index and type rather than into a fixed shape.
fn field_int(fields: &[Value], index: usize) -> Option<u64> {
    fields.get(index)?.as_u64()
}

fn field_text(fields: &[Value], index: usize) -> Option<&str> {
    fields.get(index)?.as_str()
}

#[derive(PartialEq, Eq, Clone, Copy)]
enum Kind {
    Download,
    Build,
}

struct Item {
    kind: Kind,
    name: String,
    done: u64,
    expected: u64,
    phase: Option<String>,
    started: Instant,
}

/// Strips `/nix/store/<hash>-` and any `.drv` suffix, leaving the name a person
/// would recognise.
fn store_name(path: &str) -> String {
    let base = path.rsplit('/').next().unwrap_or(path);
    let base = base.strip_suffix(".drv").unwrap_or(base);
    base.split_once('-')
        .map_or(base, |(_, rest)| rest)
        .to_owned()
}

pub fn human_bytes(bytes: u64) -> String {
    const UNITS: [&str; 4] = ["B", "KiB", "MiB", "GiB"];
    let mut value = bytes as f64;
    let mut unit = 0;
    while value >= 1024.0 && unit < UNITS.len() - 1 {
        value /= 1024.0;
        unit += 1;
    }
    if unit == 0 {
        format!("{value:.0} {}", UNITS[unit])
    } else {
        format!("{value:.1} {}", UNITS[unit])
    }
}

pub fn human_duration(elapsed: Duration) -> String {
    let secs = elapsed.as_secs();
    format!("{:02}m{:02}s", secs / 60, secs % 60)
}

fn rate(bytes: u64, elapsed: Duration) -> String {
    let secs = elapsed.as_secs_f64();
    if secs < 0.05 || bytes == 0 {
        return "--".to_owned();
    }
    format!("{}/s", human_bytes((bytes as f64 / secs) as u64))
}

const GREEN: &str = "\x1b[32m";
const CYAN: &str = "\x1b[36m";
const DIM: &str = "\x1b[90m";
const RESET: &str = "\x1b[0m";

// Box-drawing rules rather than block glyphs: the bar reads as a slim line
// instead of a wall, and the light track is quieter than a shaded `░` fill.
// The trade is resolution — a heavy left-half gives half-cell precision where
// eighth-blocks gave an eighth — which is invisible at these widths.
const BAR_FULL: char = '━';
const BAR_HALF: char = '╸';
const BAR_TRACK: char = '─';

/// A proportional bar. Sub-cell progress is drawn with a half-width cap.
fn bar(fraction: f64, width: usize) -> String {
    let halves = (fraction.clamp(0.0, 1.0) * (width * 2) as f64).round() as usize;
    let full = (halves / 2).min(width);
    let half = halves % 2;

    let mut out = String::from(GREEN);
    out.extend(std::iter::repeat_n(BAR_FULL, full));

    let mut used = full;
    if half > 0 && used < width {
        out.push(BAR_HALF);
        used += 1;
    }

    out.push_str(DIM);
    out.extend(std::iter::repeat_n(BAR_TRACK, width - used));
    out.push_str(RESET);
    out
}

/// An indeterminate bar, for work whose fraction Nix does not report. A segment
/// slides back and forth so a long build still looks alive.
fn marquee(frame: usize, width: usize) -> String {
    let span = 5.min(width);
    let travel = width - span;
    let position = if travel == 0 {
        0
    } else {
        let cycle = travel * 2;
        let step = frame % cycle;
        if step <= travel { step } else { cycle - step }
    };

    let mut out = String::from(DIM);
    out.extend(std::iter::repeat_n(BAR_TRACK, position));
    out.push_str(CYAN);
    out.extend(std::iter::repeat_n(BAR_FULL, span));
    out.push_str(DIM);
    out.extend(std::iter::repeat_n(BAR_TRACK, width - position - span));
    out.push_str(RESET);
    out
}

/// Counts printable columns, ignoring SGR escape sequences.
pub fn display_width(text: &str) -> usize {
    let mut width = 0;
    let mut chars = text.chars();
    while let Some(ch) = chars.next() {
        if ch == '\x1b' {
            // Skip the CSI body; it ends at the first alphabetic byte.
            for escape in chars.by_ref() {
                if escape.is_ascii_alphabetic() {
                    break;
                }
            }
        } else {
            width += 1;
        }
    }
    width
}

/// Truncates to `width` printable columns, keeping escape sequences intact so a
/// cut line cannot leak styling into the rest of the terminal.
fn truncate(line: &str, width: usize) -> String {
    if display_width(line) <= width {
        return line.to_owned();
    }

    let mut out = String::new();
    let mut used = 0;
    let mut chars = line.chars();
    while let Some(ch) = chars.next() {
        if ch == '\x1b' {
            out.push(ch);
            for escape in chars.by_ref() {
                out.push(escape);
                if escape.is_ascii_alphabetic() {
                    break;
                }
            }
        } else {
            if used + 1 >= width {
                break;
            }
            out.push(ch);
            used += 1;
        }
    }
    out.push_str(RESET);
    out
}

/// Fits a string into a fixed column, padding *and* truncating. Long package
/// names and version strings must not push the columns to their right around.
///
/// Escapes are not accounted for; the values this is used on come straight from
/// store paths, so they carry none.
pub fn fit(name: &str, width: usize) -> String {
    if name.chars().count() <= width {
        return format!("{name:<width$}");
    }
    name.chars().take(width).collect()
}

/// Column widths for a progress row, chosen from the terminal width.
fn progress_columns(width: usize) -> (usize, usize) {
    match width {
        0..=89 => (16, 18),
        90..=109 => (20, 20),
        110..=139 => (24, 22),
        _ => (30, 24),
    }
}

const PCT_COL: usize = 4;
const TIME_COL: usize = 6;

/// Lays out one progress row.
///
/// Every row — a download, a build, or the total — goes through here with the
/// same column widths, so they line up with each other. Anything that varies in
/// length (a store-path name, a build phase, a transfer rate) is padded *and*
/// truncated to its column rather than being allowed to shift the row.
fn compose(
    counter: &str,
    name: &str,
    percent: &str,
    detail: &str,
    time: &str,
    width: usize,
    draw: impl Fn(usize) -> String,
) -> String {
    let (name_col, detail_col) = progress_columns(width);

    // counter ␣ name ␣ bar ␣ pct ␣ detail ␣ time
    let fixed = display_width(counter) + name_col + detail_col + PCT_COL + TIME_COL + 5;
    let bar_width = width.saturating_sub(fixed).min(28);

    let bar = if bar_width >= 6 {
        draw(bar_width)
    } else {
        String::new()
    };

    let row = format!(
        "{counter} {name} {bar} {percent:>PCT_COL$} {detail} {time}",
        name = fit(name, name_col),
        detail = fit(detail, detail_col),
    );
    // A terminal too narrow for even the fixed columns would otherwise overflow.
    truncate(&row, width)
}

pub struct Monitor {
    items: HashMap<u64, Item>,
    plan: Plan,
    fetched: usize,
    built: usize,
    bytes_done: u64,
    frame: usize,
    started: Instant,
    /// Finished rows and any warnings, in order — the scrollback of the build.
    log: Vec<String>,
    /// The tail of the actual build output, so a failure can show why.
    build_log: Vec<String>,
}

impl Monitor {
    pub fn new(plan: Plan) -> Self {
        Self {
            items: HashMap::new(),
            plan,
            fetched: 0,
            built: 0,
            bytes_done: 0,
            frame: 0,
            started: Instant::now(),
            log: Vec::new(),
            build_log: Vec::new(),
        }
    }

    /// Digits needed by the larger of the two totals.
    ///
    /// Both counters are sized to it, so a `[  4/ 29]` build row and a
    /// `[  1/123]` download row occupy the same width and line up.
    fn digits(&self) -> usize {
        self.plan
            .fetches
            .len()
            .max(self.plan.builds)
            .max(1)
            .to_string()
            .len()
    }

    fn counter(&self, kind: Kind) -> String {
        let (done, total) = match kind {
            Kind::Download => (self.fetched + 1, self.plan.fetches.len()),
            Kind::Build => (self.built + 1, self.plan.builds),
        };
        let width = self.digits();
        format!("[{:>width$}/{total:>width$}]", done.min(total.max(1)))
    }

    /// The same width as `counter`, for rows that are not a numbered item.
    fn counter_slot(&self, label: &str) -> String {
        format!("{label:>width$}", width = self.digits() * 2 + 3)
    }

    fn row(&self, item: &Item, done: bool, width: usize) -> String {
        let elapsed = item.started.elapsed();
        let counter = self.counter(item.kind);
        let time = human_duration(elapsed);

        match item.kind {
            Kind::Download => {
                let fraction = if item.expected > 0 {
                    (item.done as f64 / item.expected as f64).min(1.0)
                } else if done {
                    1.0
                } else {
                    0.0
                };
                let detail = format!(
                    "{:>9} {:>9}",
                    rate(item.done, elapsed),
                    human_bytes(item.expected.max(item.done)),
                );
                compose(
                    &counter,
                    &item.name,
                    &format!("{}%", (fraction * 100.0).round() as u64),
                    &detail,
                    &time,
                    width,
                    |bar_width| bar(fraction, bar_width),
                )
            }
            Kind::Build => {
                let status = if done {
                    "built".to_owned()
                } else {
                    item.phase.clone().unwrap_or_else(|| "building".to_owned())
                };
                // Nix reports no fraction for a build, so an honest bar is
                // either full or indeterminate — never an invented percentage,
                // and the percent column stays empty rather than lying.
                compose(
                    &counter,
                    &item.name,
                    if done { "100%" } else { "" },
                    &status,
                    &time,
                    width,
                    |bar_width| {
                        if done {
                            bar(1.0, bar_width)
                        } else {
                            marquee(self.frame, bar_width)
                        }
                    },
                )
            }
        }
    }

    /// The dnf-style transaction table.
    pub fn summary(&self) -> Vec<String> {
        let mut lines = Vec::new();
        if !self.plan.fetches.is_empty() {
            let note = self
                .plan
                .sizes
                .as_deref()
                .map_or_else(String::new, |sizes| format!(" ({sizes})"));
            lines.push(format!("Fetching {} paths{note}", self.plan.fetches.len()));
        }
        if self.plan.builds > 0 {
            lines.push(format!("Building {} derivations", self.plan.builds));
        }
        if lines.is_empty() {
            lines.push("Nothing to do".to_owned());
        }
        lines
    }

    /// Finished rows and warnings, oldest first.
    pub fn log(&self) -> &[String] {
        &self.log
    }

    /// Rows for the work currently in flight, oldest first, plus however many
    /// did not fit.
    ///
    /// Nix happily runs dozens of downloads and builds at once. Rendering all
    /// of them would make the block grow and shrink every frame, so the display
    /// is capped and the remainder is reported as a count.
    pub fn active_rows(&self, width: usize, limit: usize) -> (Vec<String>, usize) {
        let mut rows: Vec<(&u64, &Item)> = self.items.iter().collect();
        // Activity ids increase monotonically, so sorting by id is oldest-first
        // and keeps rows from jumping around between frames.
        rows.sort_by_key(|(id, _)| **id);

        let hidden = rows.len().saturating_sub(limit);
        let visible = rows
            .iter()
            .take(limit)
            .map(|(_, item)| self.row(item, false, width))
            .collect();
        (visible, hidden)
    }

    /// Adopts the transaction once `--dry-run` has reported it.
    pub fn set_plan(&mut self, plan: Plan) {
        self.plan = plan;
    }

    /// The overall progress row, if there is a transaction to measure.
    pub fn total_row(&self, width: usize) -> Option<String> {
        let total = self.plan.fetches.len() + self.plan.builds;
        if total == 0 {
            return None;
        }

        let elapsed = self.started.elapsed();
        let fraction = ((self.fetched + self.built) as f64 / total as f64).min(1.0);
        let detail = format!(
            "{:>9} {:>9}",
            rate(self.bytes_done, elapsed),
            human_bytes(self.bytes_done),
        );
        Some(compose(
            &self.counter_slot(">>>"),
            "Total",
            &format!("{}%", (fraction * 100.0).round() as u64),
            &detail,
            &human_duration(elapsed),
            width,
            |bar_width| bar(fraction, bar_width),
        ))
    }

    pub fn build_log(&self) -> &[String] {
        &self.build_log
    }

    /// A one-line account of what the transaction did.
    pub fn outcome(&self) -> String {
        let mut parts = Vec::new();
        if self.fetched > 0 {
            parts.push(format!("{} fetched", self.fetched));
        }
        if self.built > 0 {
            parts.push(format!("{} built", self.built));
        }
        if parts.is_empty() {
            parts.push("nothing to do".to_owned());
        }
        format!(
            "{} in {}",
            parts.join(", "),
            human_duration(self.started.elapsed())
        )
    }

    /// Advances the animation of any indeterminate bars.
    pub fn tick(&mut self) {
        self.frame = self.frame.wrapping_add(1);
    }

    pub fn handle_line(&mut self, line: &str, width: usize) {
        let Some(payload) = line.strip_prefix("@nix ") else {
            if !line.trim().is_empty() {
                self.log.push(line.to_owned());
            }
            return;
        };
        if let Ok(event) = serde_json::from_str::<Event>(payload) {
            self.handle(&event, width);
        }
    }

    fn handle(&mut self, event: &Event, width: usize) {
        match event.action.as_str() {
            "start" => self.on_start(event),
            "result" => self.on_result(event),
            "stop" => self.on_stop(event.id, width),
            "msg" => {
                // Only errors and warnings. Anything chattier (Nix's per-file
                // "linking ..." notices, say) would drown the display.
                if event.level <= 1
                    && let Some(msg) = event.msg.clone()
                {
                    self.log.push(msg);
                }
            }
            _ => {}
        }
    }

    fn on_start(&mut self, event: &Event) {
        let Some(path) = field_text(&event.fields, 0) else {
            return;
        };

        let kind = match event.kind {
            ACT_BUILD => Kind::Build,
            // Nix copies locally built outputs into the store too, so only
            // paths the plan said would be fetched count as downloads.
            ACT_COPY_PATH if self.plan.fetches.contains(path) => Kind::Download,
            _ => return,
        };

        self.items.insert(
            event.id,
            Item {
                kind,
                name: store_name(path),
                done: 0,
                expected: 0,
                phase: None,
                started: Instant::now(),
            },
        );
    }

    fn on_result(&mut self, event: &Event) {
        match event.kind {
            RES_PROGRESS => {
                if let Some(item) = self.items.get_mut(&event.id) {
                    item.done = field_int(&event.fields, 0).unwrap_or(0);
                    item.expected = field_int(&event.fields, 1).unwrap_or(0);
                }
            }
            RES_SET_PHASE => {
                if let Some(phase) = field_text(&event.fields, 0)
                    && let Some(item) = self.items.get_mut(&event.id)
                {
                    item.phase = Some(phase.to_owned());
                }
            }
            RES_BUILD_LOG_LINE => {
                if let Some(line) = field_text(&event.fields, 0) {
                    self.build_log.push(line.to_owned());
                    if self.build_log.len() > LOG_TAIL {
                        self.build_log.remove(0);
                    }
                }
            }
            _ => {}
        }
    }

    fn on_stop(&mut self, id: u64, width: usize) {
        let Some(item) = self.items.remove(&id) else {
            return;
        };
        // Render before counting: `counter` reports the ordinal of the item in
        // flight, which for the one just finishing is its own number.
        let line = self.row(&item, true, width);
        match item.kind {
            Kind::Download => {
                self.bytes_done += item.expected.max(item.done);
                self.fetched += 1;
            }
            Kind::Build => self.built += 1,
        }
        self.log.push(line);
    }
}

fn reader_thread(stderr: ChildStderr) -> Receiver<String> {
    let (tx, rx) = channel();
    std::thread::spawn(move || {
        for line in BufReader::new(stderr).lines().map_while(Result::ok) {
            if tx.send(line).is_err() {
                break;
            }
        }
    });
    rx
}

/// A running `nix build`, whose structured log the caller pumps into a
/// `Monitor` between frames.
pub struct BuildStream {
    child: Child,
    lines: Receiver<String>,
    ended: bool,
}

impl BuildStream {
    pub fn start(command: &mut Command) -> Result<Self> {
        let mut child = command
            .stderr(Stdio::piped())
            // The TUI owns stdout. Anything Nix writes there would land in the
            // middle of a frame and corrupt the display.
            .stdout(Stdio::null())
            .spawn()
            .context("failed to run `nix build`")?;
        let stderr = child.stderr.take().expect("stderr was piped");
        Ok(Self {
            child,
            lines: reader_thread(stderr),
            ended: false,
        })
    }

    /// Drains whatever the build has emitted since the last call. Returns false
    /// once Nix has closed its log, meaning the build is over.
    pub fn pump(&mut self, monitor: &mut Monitor, width: usize) -> bool {
        loop {
            match self.lines.try_recv() {
                Ok(line) => monitor.handle_line(&line, width),
                Err(TryRecvError::Empty) => return !self.ended,
                Err(TryRecvError::Disconnected) => {
                    self.ended = true;
                    return false;
                }
            }
        }
    }

    pub fn wait(&mut self) -> Result<ExitStatus> {
        self.child.wait().context("failed to wait for `nix build`")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const DRY_RUN: &str = "\
warning: Git tree is dirty
these 2 derivations will be built:
  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo-1.0.drv
  /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-bar-2.0.drv
these 3 paths will be fetched (22.54 MiB download, 22.99 MiB unpacked):
  /nix/store/cccccccccccccccccccccccccccccccc-baz-3.0
  /nix/store/dddddddddddddddddddddddddddddddd-qux-4.0
  /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-quux-5.0
";

    const FETCHED: &str = "/nix/store/cccccccccccccccccccccccccccccccc-baz-3.0";

    fn monitor_with_plan() -> Monitor {
        let mut plan = Plan::default();
        plan.builds = 1;
        plan.fetches.insert(FETCHED.to_owned());
        Monitor::new(plan)
    }

    fn start_fetch(monitor: &mut Monitor) {
        monitor.handle_line(
            &format!(
                r#"@nix {{"action":"start","id":1,"type":100,"fields":["{FETCHED}","https://cache.nixos.org","local"]}}"#
            ),
            100,
        );
    }

    #[test]
    fn parses_both_sections() {
        let plan = parse_plan(DRY_RUN);
        assert_eq!(plan.builds, 2);
        assert_eq!(plan.fetches.len(), 3);
        assert!(plan.fetches.contains(FETCHED));
        assert_eq!(
            plan.sizes.as_deref(),
            Some("22.54 MiB download, 22.99 MiB unpacked")
        );
    }

    #[test]
    fn empty_plan_when_nothing_to_do() {
        let plan = parse_plan("warning: Git tree is dirty\n");
        assert_eq!(plan.builds, 0);
        assert!(plan.fetches.is_empty());
        assert_eq!(
            Monitor::new(plan).summary(),
            vec!["Nothing to do".to_owned()]
        );
    }

    #[test]
    fn tracks_planned_fetches_but_not_local_copies() {
        let mut monitor = monitor_with_plan();
        start_fetch(&mut monitor);
        assert_eq!(monitor.items.len(), 1);

        // Nix also copies locally built outputs into the store; those are not
        // downloads and must not consume a fetch slot.
        monitor.handle_line(
            r#"@nix {"action":"start","id":2,"type":100,"fields":["/nix/store/ffffffffffffffffffffffffffffffff-etc-fstab","",""]}"#,
            100,
        );
        assert_eq!(monitor.items.len(), 1);
    }

    #[test]
    fn counts_completions_against_the_plan() {
        let mut monitor = monitor_with_plan();
        start_fetch(&mut monitor);
        monitor.handle_line(
            r#"@nix {"action":"start","id":3,"type":105,"fields":["/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo-1.0.drv","",1,1]}"#,
            100,
        );
        monitor.handle_line(
            r#"@nix {"action":"result","id":3,"type":104,"fields":["buildPhase"]}"#,
            100,
        );
        assert_eq!(monitor.items[&3].phase.as_deref(), Some("buildPhase"));

        // The first completed item must read as [1/n], not [2/n].
        assert!(
            monitor
                .row(&monitor.items[&3], true, 100)
                .starts_with("[1/1]")
        );

        monitor.handle_line(r#"@nix {"action":"stop","id":1}"#, 100);
        monitor.handle_line(r#"@nix {"action":"stop","id":3}"#, 100);

        assert_eq!(monitor.fetched, 1);
        assert_eq!(monitor.built, 1);
        assert!(monitor.items.is_empty());
        assert_eq!(monitor.log().len(), 2, "both finished rows are logged");
    }

    #[test]
    fn suppresses_chatty_messages() {
        let mut monitor = monitor_with_plan();
        monitor.handle_line(
            r#"@nix {"action":"msg","level":4,"msg":"linking '/nix/store/x' to '/nix/store/y'"}"#,
            100,
        );
        assert!(monitor.log().is_empty());

        // Warnings are the operator's business and must survive.
        monitor.handle_line(
            r#"@nix {"action":"msg","level":1,"msg":"warning: something real"}"#,
            100,
        );
        assert_eq!(monitor.log().len(), 1);
    }

    #[test]
    fn bars_occupy_exactly_their_width() {
        for fraction in [0.0, 0.01, 0.5, 0.999, 1.0] {
            assert_eq!(display_width(&bar(fraction, 20)), 20, "bar({fraction})");
        }
    }

    #[test]
    fn marquee_occupies_its_width_at_every_frame() {
        for frame in 0..64 {
            assert_eq!(display_width(&marquee(frame, 20)), 20, "frame {frame}");
        }
    }

    #[test]
    fn rows_fit_the_terminal() {
        let mut monitor = monitor_with_plan();
        start_fetch(&mut monitor);
        monitor.handle_line(
            r#"@nix {"action":"result","id":1,"type":105,"fields":[512,1024,0,0]}"#,
            100,
        );

        for width in [60, 80, 100, 120, 200] {
            let row = monitor.row(&monitor.items[&1], false, width);
            assert!(
                display_width(&row) <= width,
                "row overflowed a {width}-column terminal"
            );
        }
    }

    /// Downloads, builds and the total all share one column schema, so a mixed
    /// live block lines up instead of jittering between kinds.
    #[test]
    fn every_row_kind_has_the_same_width() {
        let mut plan = Plan::default();
        plan.builds = 29;
        plan.fetches.insert(FETCHED.to_owned());
        for n in 0..150 {
            plan.fetches.insert(format!("/nix/store/{n:032}-pkg-{n}"));
        }
        let mut monitor = Monitor::new(plan);

        start_fetch(&mut monitor);
        monitor.handle_line(
            r#"@nix {"action":"result","id":1,"type":105,"fields":[512,1024,0,0]}"#,
            100,
        );
        monitor.handle_line(
            r#"@nix {"action":"start","id":2,"type":105,"fields":["/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-a-very-long-package-name-1.0.drv","",1,1]}"#,
            100,
        );
        monitor.handle_line(
            r#"@nix {"action":"result","id":2,"type":104,"fields":["updateAutotoolsGnuConfigScriptsPhase"]}"#,
            100,
        );

        for width in [80, 100, 120, 160] {
            let download = monitor.row(&monitor.items[&1], false, width);
            let build = monitor.row(&monitor.items[&2], false, width);
            let finished = monitor.row(&monitor.items[&2], true, width);
            let total = monitor.total_row(width).expect("plan is not empty");

            let widths = [
                display_width(&download),
                display_width(&build),
                display_width(&finished),
                display_width(&total),
            ];
            assert!(
                widths.windows(2).all(|pair| pair[0] == pair[1]),
                "at {width} columns the row kinds differ: {widths:?}"
            );
            assert!(
                widths[0] <= width,
                "row of {} overflowed {width} columns",
                widths[0]
            );
        }
    }

    #[test]
    fn store_name_strips_hash_and_drv() {
        assert_eq!(
            store_name("/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo-1.0.drv"),
            "foo-1.0"
        );
    }
}
