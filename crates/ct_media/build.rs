use std::env;
use std::path::PathBuf;

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let repo_root = manifest_dir.parent().unwrap().parent().unwrap();

    let ffmpeg_inc = repo_root.join("third_party/ffmpeg/include");
    let ffmpeg_lib = repo_root.join("third_party/ffmpeg/lib");
    let opus_inc = repo_root.join("third_party/opus/include");
    let opus_lib = repo_root.join("third_party/opus/lib");

    println!("cargo:rerun-if-changed=c_src/ffmpeg_bridge.c");
    println!("cargo:rustc-link-search=native={}", ffmpeg_lib.display());
    println!("cargo:rustc-link-search=native={}", opus_lib.display());
    println!("cargo:rustc-link-lib=dylib=ffmpeg");
    println!("cargo:rustc-link-lib=static=opus");

    cc::Build::new()
        .file("c_src/ffmpeg_bridge.c")
        .include(&ffmpeg_inc)
        .include(&opus_inc)
        .flag("--target=aarch64-linux-android24")
        .flag("-O2")
        .flag("-fPIC")
        .flag("-Wno-unused-result")
        .compile("ffmpeg_bridge");
}
