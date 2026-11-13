#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$PROJECT_ROOT/ct_tools_ui/android/app/src/main/jniLibs/arm64-v8a"

echo "[CT-TOOLS] Compiling native Rust media engine (arm64-v8a)..."
cd "$PROJECT_ROOT/crates/ct_media"

cargo build --release --target aarch64-linux-android

mkdir -p "$TARGET_DIR"
cp "$PROJECT_ROOT/target/aarch64-linux-android/release/libct_media.so" "$TARGET_DIR/"

echo "[CT-TOOLS] Artifact successfully deployed: $TARGET_DIR/libct_media.so"
