use std::env;
use std::process::Command;

/// Returns the build date in ISO 8601 format.
pub fn build_date() -> String {
    chrono::Utc::now()
        .format("%Y-%m-%d %H:%M:%S UTC")
        .to_string()
}

/// Returns the user running the build.
pub fn build_user() -> String {
    env::var("USER")
        .or_else(|_| env::var("USERNAME"))
        .unwrap_or_else(|_| {
            Command::new("whoami")
                .output()
                .ok()
                .and_then(|output| {
                    if output.status.success() {
                        String::from_utf8(output.stdout)
                            .ok()
                            .map(|s| s.trim().to_string())
                    } else {
                        None
                    }
                })
                .unwrap_or_else(|| "unknown".to_string())
        })
}

/// Returns the Rust compiler version and emits a cfg flag if nightly.
fn rust_version() -> String {
    match rustc_version::version_meta() {
        Ok(meta) => {
            if meta.channel == rustc_version::Channel::Nightly {
                println!("cargo:rustc-cfg=nightly_compiler");
            }
            format!("{} {} ({:?} channel)", meta.semver, meta.host, meta.channel)
        },
        Err(_) => "unknown".to_string(),
    }
}

/// Emit build metadata information (date and user).
pub fn emit_build_metadata() {
    let build_date = build_date();
    let build_user = build_user();
    println!("cargo:rustc-env=BUILD_DATE={build_date}");
    println!("cargo:rustc-env=BUILD_USER={build_user}");
}

/// Detect the compiler and emit related environment variables and cfg flags.
pub fn detect_compiler() {
    let version = rust_version();
    println!("cargo:rustc-env=TOOLCHAIN={version}");
    nightly();
    beta();
    stable();
    msrv();
}

#[rustversion::nightly]
fn nightly() {
    println!("cargo:rustc-cfg=nightly");
}
#[rustversion::not(nightly)]
fn nightly() {}

#[rustversion::beta]
fn beta() {
    println!("cargo:rustc-cfg=beta");
}
#[rustversion::not(beta)]
fn beta() {}

#[rustversion::stable]
fn stable() {
    println!("cargo:rustc-cfg=stable");
}
#[rustversion::not(stable)]
fn stable() {}

#[rustversion::since(1.67)]
fn msrv() {
    println!("cargo:rustc-cfg=msrv");
}
#[rustversion::before(1.67)]
fn msrv() {}
