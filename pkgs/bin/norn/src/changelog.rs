use std::{env, process::Command, sync::OnceLock, time::Duration};

use eyre::{Context as _, Result, bail};
use serde::Deserialize;
use serde_json::Value;
use url::Url;

const MAX_RELEASE_PAGES: u32 = 20;

#[derive(Deserialize, Default)]
struct Meta {
    homepage: Option<String>,
    changelog: Option<String>,
}

#[derive(Deserialize)]
struct PackageInfo {
    #[serde(default)]
    meta: Meta,
}

struct RepoRef {
    host: String,
    owner: String,
    repo: String,
}

struct Release {
    tag: String,
    body: String,
}

/// Reads a package's `meta` out of nixpkgs. Both fields are optional, so the
/// apply expression defaults every level rather than throwing on absence.
fn eval_meta(name: &str) -> Result<Meta> {
    let apply = "p: { meta = { \
                homepage = (p.meta or {}).homepage or null; \
                changelog = (p.meta or {}).changelog or null; \
              }; }";

    let output = Command::new("nix")
        .args([
            "eval",
            "--extra-experimental-features",
            "nix-command flakes",
            "--no-warn-dirty",
            "--json",
            &format!("nixpkgs#{name}"),
            "--apply",
            apply,
        ])
        .output()
        .context("failed to run `nix eval` — is Nix installed?")?;

    if !output.status.success() {
        bail!("no nixpkgs attribute named {name}");
    }

    let info: PackageInfo =
        serde_json::from_slice(&output.stdout).context("nix returned unexpected JSON")?;
    Ok(info.meta)
}

/// Looks up a host's token from Nix's own `access-tokens` setting, which is
/// reported already parsed as a `{host: token}` object, with an optional
/// `type:` prefix on the value (GitLab's `PAT:`/`OAuth2:`).
fn nix_access_token(host: &str) -> Option<String> {
    let output = Command::new("nix")
        .args(["config", "show", "--json"])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let config: Value = serde_json::from_slice(&output.stdout).ok()?;
    let token = config
        .get("access-tokens")?
        .get("value")?
        .get(host)?
        .as_str()?;
    Some(
        token
            .split_once(':')
            .map_or(token, |(_, rest)| rest)
            .to_owned(),
    )
}

fn github_token() -> Option<&'static str> {
    static TOKEN: OnceLock<Option<String>> = OnceLock::new();
    TOKEN
        .get_or_init(|| {
            env::var("GITHUB_TOKEN")
                .ok()
                .or_else(|| nix_access_token("github.com"))
        })
        .as_deref()
}

/// One shared agent, so every lookup is bounded: an unreachable forge has to
/// fail its row, not wedge it on "loading changelog…" forever.
fn agent() -> &'static ureq::Agent {
    static AGENT: OnceLock<ureq::Agent> = OnceLock::new();
    AGENT.get_or_init(|| {
        ureq::Agent::new_with_config(
            ureq::Agent::config_builder()
                .timeout_global(Some(Duration::from_secs(15)))
                .build(),
        )
    })
}

fn fetch_json(url: &str) -> Result<Value> {
    let mut request = agent().get(url).header("User-Agent", "norn");
    if url.starts_with("https://api.github.com")
        && let Some(token) = github_token()
    {
        request = request.header("Authorization", &format!("Bearer {token}"));
    }
    request
        .call()
        .with_context(|| format!("failed to fetch {url}"))?
        .body_mut()
        .read_json::<Value>()
        .context("failed to parse JSON response")
}

fn fetch_text(url: &str) -> Result<String> {
    agent()
        .get(url)
        .header("User-Agent", "norn")
        .call()
        .with_context(|| format!("failed to fetch {url}"))?
        .body_mut()
        .read_to_string()
        .context("failed to read response body")
}

fn repo_ref_from_url(raw: &str) -> Option<RepoRef> {
    let parsed = Url::parse(raw).ok()?;
    let host = parsed.host_str()?.to_owned();
    let mut segments = parsed.path_segments()?;
    let owner = segments.next()?.to_owned();
    let repo = segments.next()?.trim_end_matches(".git").to_owned();
    if owner.is_empty() || repo.is_empty() {
        return None;
    }
    Some(RepoRef { host, owner, repo })
}

fn normalize_version(version: &str) -> &str {
    version.strip_prefix(['v', 'V']).unwrap_or(version)
}

fn tag_matches(tag: &str, wanted: &str) -> bool {
    normalize_version(tag) == normalize_version(wanted)
}

/// Fetches one page of releases, normalizing GitHub, GitLab and Forgejo/Gitea's
/// differing API shapes into a common form.
fn fetch_releases_page(repo: &RepoRef, page: u32) -> Result<Vec<Release>> {
    let (url, body_field) = match repo.host.as_str() {
        "github.com" => (
            format!(
                "https://api.github.com/repos/{owner}/{repo}/releases?per_page=100&page={page}",
                owner = repo.owner,
                repo = repo.repo
            ),
            "body",
        ),
        "gitlab.com" => (
            format!(
                "https://gitlab.com/api/v4/projects/{owner}%2F{repo}/releases?per_page=100&page={page}&order_by=released_at&sort=desc",
                owner = repo.owner,
                repo = repo.repo
            ),
            "description",
        ),
        host => (
            format!(
                "https://{host}/api/v1/repos/{owner}/{repo}/releases?limit=50&page={page}",
                owner = repo.owner,
                repo = repo.repo
            ),
            "body",
        ),
    };

    let json = fetch_json(&url)?;
    Ok(json
        .as_array()
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .map(|value| Release {
            tag: value["tag_name"].as_str().unwrap_or_default().to_owned(),
            body: value[body_field].as_str().unwrap_or_default().to_owned(),
        })
        .collect())
}

/// Collects the releases an upgrade actually brings in: everything after `old`
/// up to and including `new`. `old` itself is excluded — you were already
/// running it.
///
/// An empty `old` means the package is newly installed, so there is no span to
/// walk: just its own release notes.
fn releases_between(repo: &RepoRef, old: &str, new: &str) -> Result<Vec<Release>> {
    let mut collecting = false;
    let mut collected = Vec::new();

    'pages: for page in 1..=MAX_RELEASE_PAGES {
        let releases = fetch_releases_page(repo, page)?;
        if releases.is_empty() {
            break;
        }

        for release in releases {
            if !collecting {
                if tag_matches(&release.tag, new) {
                    collecting = true;
                } else {
                    continue;
                }
            }

            if old.is_empty() {
                collected.push(release);
                break 'pages;
            }
            if tag_matches(&release.tag, old) {
                break 'pages;
            }
            collected.push(release);
        }
    }

    if collected.is_empty() {
        bail!("no releases tagged between {old} and {new}");
    }

    collected.reverse();
    Ok(collected)
}

fn render(releases: &[Release]) -> String {
    let mut markdown = String::new();
    for release in releases {
        markdown.push_str(&format!("# {tag}\n\n", tag = release.tag));
        let body = release.body.trim();
        if body.is_empty() {
            markdown.push_str("_No release notes._\n\n");
        } else {
            markdown.push_str(body);
            markdown.push_str("\n\n");
        }
    }
    markdown
}

/// Last resort when a project publishes no matching releases: show whatever the
/// `meta.changelog` URL points at, if it is something we can render.
fn changelog_file(meta: &Meta) -> Option<String> {
    let raw = meta.changelog.as_deref()?;

    if let Ok(url) = Url::parse(raw)
        && url.host_str() == Some("github.com")
    {
        let segments: Vec<&str> = url.path_segments().map(Iterator::collect)?;
        if let [owner, repo, "blob", git_ref, rest @ ..] = segments.as_slice() {
            let raw_url = format!(
                "https://raw.githubusercontent.com/{owner}/{repo}/{git_ref}/{path}",
                path = rest.join("/")
            );
            return fetch_text(&raw_url).ok();
        }
    }

    if raw.ends_with(".md") || raw.ends_with(".markdown") {
        return fetch_text(raw).ok();
    }

    Some(format!("Changelog lives at <{raw}>.\n"))
}

/// Resolves a package's release notes for an upgrade, as markdown.
pub fn markdown_for(name: &str, old: &str, new: &str) -> Result<String> {
    let meta = eval_meta(name)?;

    let repo = meta
        .changelog
        .as_deref()
        .and_then(repo_ref_from_url)
        .or_else(|| meta.homepage.as_deref().and_then(repo_ref_from_url));

    if let Some(repo) = repo {
        match releases_between(&repo, old, new) {
            Ok(releases) => return Ok(render(&releases)),
            // Plenty of projects tag releases the API cannot match to a nixpkgs
            // version string. Fall through to the changelog file rather than fail.
            Err(_) => {}
        }
    }

    changelog_file(&meta).ok_or_else(|| eyre::eyre!("no changelog or homepage metadata for {name}"))
}
