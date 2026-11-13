#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$PROJECT_ROOT/ct_tools_ui/android/app/src/main/jniLibs/arm64-v8a"
FFMPEG_SO="$PROJECT_ROOT/third_party/ffmpeg/lib/libffmpeg.so"

export CC_aarch64_linux_android="clang"
export AR_aarch64_linux_android="llvm-ar"
export CFLAGS_aarch64_linux_android="--target=aarch64-linux-android24 -O2 -fPIC"

echo "[CT-TOOLS] Building native Rust & FFmpeg/Opus C crates (arm64-v8a)..."
cd "$PROJECT_ROOT"

cargo build --release -p ct_core -p ct_media --target aarch64-linux-android -j 2

mkdir -p "$TARGET_DIR"
cp "$PROJECT_ROOT/target/aarch64-linux-android/release/libct_core.so" "$TARGET_DIR/"
cp "$PROJECT_ROOT/target/aarch64-linux-android/release/libct_media.so" "$TARGET_DIR/"
cp "$FFMPEG_SO" "$TARGET_DIR/libffmpeg.so"

echo "[CT-TOOLS] Checking dynamic dependencies of libct_media.so:"
readelf -d "$TARGET_DIR/libct_media.so" | grep NEEDED || true

echo "[CT-TOOLS] Deployed artifacts to: $TARGET_DIR"
ls -lh "$TARGET_DIR"
