extern crate version_check;

use std::env;
use std::path::Path;
use std::process::Command;

#[path = "build/git.rs"]
mod git;
#[path = "build/metadata.rs"]
mod metadata;

fn main() {
    // Rebuild if this file changes.
    println!("cargo:rerun-if-changed=build.rs");

    // Determine the target triple
    let version = env::var("CARGO_PKG_VERSION").unwrap_or_else(|_| "unknown".into());
    println!("cargo:rustc-env=VERSION={version}");

    // Re-run if Git HEAD changes (e.g., after a commit or branch switch)
    if Path::new(".git/HEAD").exists() {
        println!("cargo:rerun-if-changed=.git/HEAD");
    }

    // Extract Git information
    git::emit_git_info();

    // Get build date and user
    metadata::emit_build_metadata();

    // Get Rust version
    metadata::detect_compiler();

    // Common linking arg for static
    // println!("cargo:rustc-link-arg=-static");

    // Handle target-specific configuration
    let target = env::var("TARGET").unwrap_or_default();
    let is_musl = target.contains("musl");

    if is_musl {
        // Musl-based build
        // Typically no additional link instructions are required.
        // Musl is designed for easy static linking by default.
        println!("cargo:warning=Building for musl target: {target}. Expect a fully static binary.");
    } else {
        // Not building for musl
        // Possibly glibc-based linking or another libc (e.g. bionic, etc.)

        // 1) If the user wants to build a fully static binary with glibc (not recommended),
        //    they'd typically need to manually install glibc-static or link in static libs.
        //    We'll warn them about the pitfalls of that approach.

        println!("cargo:warning=Detected non-musl target: {target}. ");
        println!("cargo:warning=Fully static linking with glibc may be problematic.");

        // 2) Optionally, you could link in typical static system libs:
        //
        // println!("cargo:rustc-link-lib=static=ssl");
        // println!("cargo:rustc-link-lib=static=crypto");
        // println!("cargo:rustc-link-lib=static=z");
        // println!("cargo:rustc-link-lib=static=pthread");
        // println!("cargo:rustc-link-lib=static=dl");
        // println!("cargo:rustc-link-lib=static=rt");
        //
        // But you'd need to ensure they're installed as static libs on your system (e.g.,
        // on Debian/Ubuntu: `sudo apt-get install -y libssl-dev zlib1g-dev ...`
        // plus the -dev or -static variants). Even then, glibc remains tricky to fully statically link.

        // 3) Additionally, if this build is happening without an explicit CARGO_BUILD_TARGET,
        //    show a friendly message about using musl for a safer static approach.
        if env::var("CARGO_BUILD_TARGET").is_err() {
            let musl_target = "x86_64-unknown-linux-musl";
            let output = Command::new("rustc")
                .args(["--print", "target-list"])
                .output()
                .expect("Failed to run rustc to get target list");
            let target_list = String::from_utf8_lossy(&output.stdout);
            if target_list.contains(musl_target) {
                println!(
                    "cargo:warning=Consider using musl for a reliably static binary:\n  cargo build --target={musl_target}"
                );
            } else {
                println!(
                    "cargo:warning=If you need a fully static binary, install the musl target:\n  rustup target add {musl_target}\nThen build with:\n  cargo build --target={musl_target}"
                );
            }
        }
    }
}
