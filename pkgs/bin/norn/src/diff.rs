use std::{collections::HashSet, path::Path};

use dix::{PackageDiff, VersionDiff};
use eyre::Result;

use crate::progress::human_bytes;

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum ChangeKind {
    Upgraded,
    Added,
    Removed,
}

/// A single package that differs between two closures — the unit the changelog
/// browser works in.
#[derive(Clone)]
pub struct Change {
    pub name: String,
    /// Empty when the package was added.
    pub old: String,
    /// Empty when the package was removed.
    pub new: String,
    pub kind: ChangeKind,
    pub size_delta: i64,
}

/// Diffs two closures. Returns the version changes worth looking up a changelog
/// for, plus a one-line summary of the closure as a whole.
pub fn changes(old: &Path, new: &Path) -> Result<(Vec<Change>, String)> {
    let report = dix::query_diff_report(old, new, true)?;

    let paths = report.path_stats();
    let size_old = report.size_old().bytes();
    let size_new = report.size_new().bytes();
    let delta = size_new - size_old;

    let summary = format!(
        "{} → {} paths (+{}, -{})   {} → {}   {}{}",
        paths.old_count(),
        paths.new_count(),
        paths.added_count(),
        paths.removed_count(),
        human_bytes(size_old.unsigned_abs()),
        human_bytes(size_new.unsigned_abs()),
        if delta < 0 { "-" } else { "+" },
        human_bytes(delta.unsigned_abs()),
    );

    let mut seen = HashSet::new();
    let changes = report
        .diffs()
        .iter()
        .flat_map(version_changes)
        // A package can report several changed store paths (say a binary and
        // its shell completions); they all share one upstream changelog.
        .filter(|change| seen.insert(change.name.clone()))
        .collect();

    Ok((changes, summary))
}

fn version_changes(diff: &PackageDiff) -> Vec<Change> {
    // The system closure itself always "changes" and has nothing upstream.
    if diff.name.starts_with("nixos-system-") {
        return Vec::new();
    }

    let size_delta = diff.size.delta().bytes();

    diff.versions
        .iter()
        .filter_map(|version| {
            // An upgrade carries both versions; an install or a removal carries
            // only the one it has. `AmountChanged` is the same version at a
            // different multiplicity, which has nothing to read about.
            let (old, new, kind) = match version {
                VersionDiff::Changed { old, new } => (
                    old.version.name.clone(),
                    new.version.name.clone(),
                    ChangeKind::Upgraded,
                ),
                VersionDiff::Added(version) => (
                    String::new(),
                    version.version.name.clone(),
                    ChangeKind::Added,
                ),
                VersionDiff::Removed(version) => (
                    version.version.name.clone(),
                    String::new(),
                    ChangeKind::Removed,
                ),
                VersionDiff::AmountChanged { .. } => return None,
            };

            Some(Change {
                name: diff.name.clone(),
                old,
                new,
                kind,
                size_delta,
            })
        })
        .collect()
}
