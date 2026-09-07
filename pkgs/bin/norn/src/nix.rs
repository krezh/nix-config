use std::{
    ffi::{OsStr, OsString},
    fs,
    os::unix::fs::MetadataExt as _,
    path::{Path, PathBuf},
    process::{Command, Stdio},
};

use eyre::{Context as _, Result, bail};

use crate::progress::Plan;

pub const CURRENT_PROFILE: &str = "/run/current-system";
pub const SYSTEM_PROFILE: &str = "/nix/var/nix/profiles/system";

/// What to do with a freshly built system closure.
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Activation {
    Switch,
    Boot,
    Test,
}

impl Activation {
    fn verb(self) -> &'static str {
        match self {
            Self::Switch => "switch",
            Self::Boot => "boot",
            Self::Test => "test",
        }
    }

    /// `test` activates without touching the boot default, so it is the one
    /// variant that must not move the system profile.
    fn sets_profile(self) -> bool {
        self != Self::Test
    }
}

pub fn hostname() -> Result<String> {
    let raw = fs::read_to_string("/proc/sys/kernel/hostname")
        .context("failed to read the system hostname")?;
    let name = raw.trim().to_owned();
    if name.is_empty() {
        bail!("the system hostname is empty");
    }
    Ok(name)
}

pub fn toplevel_attr(flake: &str, host: &str) -> String {
    format!("{flake}#nixosConfigurations.{host}.config.system.build.toplevel")
}

/// Asks Nix what it would do, so the progress display knows the size of the
/// transaction before it begins.
pub fn dry_run(attr: &str, extra: &[String]) -> Result<Plan> {
    let output = Command::new("nix")
        .arg("build")
        .arg(attr)
        .args(["--dry-run", "--no-link"])
        .args(extra)
        .output()
        .context("failed to run `nix build --dry-run`")?;

    if !output.status.success() {
        bail!("{}", String::from_utf8_lossy(&output.stderr).trim());
    }

    Ok(crate::progress::parse_plan(&String::from_utf8_lossy(
        &output.stderr,
    )))
}

fn base_command(attr: &str, out_link: &Path, extra: &[String]) -> Command {
    let mut command = Command::new("nix");
    command
        .arg("build")
        .arg(attr)
        .arg("--out-link")
        .arg(out_link)
        .args(extra);
    command
}

/// The build, emitting Nix's structured log for the TUI to render.
///
/// No `-v`: the activities we render are already at the default verbosity, and
/// raising it only adds per-file "linking ..." noise.
pub fn build_command(attr: &str, out_link: &Path, extra: &[String]) -> Command {
    let mut command = base_command(attr, out_link, extra);
    command.args(["--log-format", "internal-json"]);
    command
}

/// The build with Nix's own output, for `--plain` and for non-terminals.
pub fn build_plain(attr: &str, out_link: &Path, extra: &[String]) -> Result<PathBuf> {
    let status = base_command(attr, out_link, extra)
        .status()
        .context("failed to run `nix build`")?;
    if !status.success() {
        bail!("`nix build` failed for {attr}");
    }
    canonical_result(out_link)
}

pub fn canonical_result(out_link: &Path) -> Result<PathBuf> {
    fs::canonicalize(out_link).with_context(|| {
        format!(
            "the build reported success but {link} is missing",
            link = out_link.display()
        )
    })
}

fn is_root() -> bool {
    fs::metadata("/proc/self")
        .map(|meta| meta.uid() == 0)
        .unwrap_or(false)
}

/// Runs a command as root, going through sudo unless we already are root.
fn run_elevated<I, S>(argv: I) -> Result<()>
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let argv: Vec<OsString> = argv
        .into_iter()
        .map(|arg| arg.as_ref().to_os_string())
        .collect();
    let Some((first, rest)) = argv.split_first() else {
        bail!("refusing to run an empty command");
    };

    let (program, args) = if is_root() {
        (first.clone(), rest.to_vec())
    } else {
        (OsString::from("sudo"), argv.clone())
    };

    let status = Command::new(&program)
        .args(&args)
        .stdin(Stdio::inherit())
        .status()
        .with_context(|| format!("failed to run {}", program.to_string_lossy()))?;

    if !status.success() {
        bail!(
            "{program} exited with {status}",
            program = program.to_string_lossy()
        );
    }
    Ok(())
}

pub fn activate(toplevel: &Path, action: Activation) -> Result<()> {
    if action.sets_profile() {
        run_elevated([
            OsStr::new("nix-env"),
            OsStr::new("-p"),
            OsStr::new(SYSTEM_PROFILE),
            OsStr::new("--set"),
            toplevel.as_os_str(),
        ])
        .context("failed to set the system profile")?;
    }

    let script = toplevel.join("bin/switch-to-configuration");
    run_elevated([script.as_os_str(), OsStr::new(action.verb())])
        .with_context(|| format!("failed to {} the new configuration", action.verb()))
}
