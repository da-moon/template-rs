use gix_ref::Category;

/// Returns the full Git revision hash using gix.
pub fn revision() -> String {
    gix::open(".").map_or_else(
        |_| "unknown".to_string(),
        |repo| {
            repo.head_commit()
                .ok()
                .map(|commit| commit.id.to_hex().to_string())
                .map_or_else(|| "unknown".to_string(), |rev| rev)
        },
    )
}

/// Returns the short Git revision hash.
#[allow(dead_code)]
pub fn short_revision() -> String {
    gix::open(".").map_or_else(
        |_| "unknown".to_string(),
        |repo| {
            repo.head()
                .ok()
                .and_then(|mut head| {
                    head.try_peel_to_id_in_place()
                        .ok()
                        .flatten()
                        .map(|commit| commit.to_hex_with_len(8).to_string())
                })
                .map_or_else(|| "unknown".to_string(), |rev| rev)
        },
    )
}

/// Returns the current Git branch.
pub fn branch() -> String {
    gix::open(".").map_or_else(
        |_| "HEAD".to_string(),
        |repo| {
            repo.head()
                .ok()
                .and_then(gix::Head::try_into_referent)
                .map(|head_ref| head_ref.name().to_owned())
                .and_then(|name| {
                    name.category_and_short_name()
                        .filter(|(category, _)| *category == Category::LocalBranch)
                        .map(|(_, short_name)| short_name.to_string())
                })
                .map_or_else(|| "HEAD".to_string(), |branch| branch)
        },
    )
}

/// Emit Git revision and branch information for the build script.
pub fn emit_git_info() {
    let revision = revision();
    println!("cargo:rustc-env=BUILD_GIT_REVISION={revision}");

    let branch = branch();
    println!("cargo:rustc-env=BUILD_GIT_BRANCH={branch}");
}

/// Extract package version from the latest tag.
#[allow(dead_code)]
pub fn tag() -> Result<(), Box<dyn std::error::Error>> {
    let cargo_pkg_version = env!("CARGO_PKG_VERSION").to_string();
    let r = gix::discover(std::path::Path::new("."))?;
    let mut h = r.head().unwrap();
    let c = h.peel_to_commit_in_place().unwrap();
    let names = gix::commit::describe::SelectRef::AllTags;
    let t = c
        .describe()
        .names(names)
        .id_as_fallback(false)
        .format()
        .map(|mut fmt| {
            if fmt.depth > 0 {
                fmt.dirty_suffix = Some("dirty".to_string());
            }
            fmt.depth = 0;
            fmt.long = false;
            fmt.to_string()
        })
        .unwrap_or(cargo_pkg_version);
    println!("cargo:rustc-env=VERSION={t}");
    Ok(())
}
