#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$PROJECT_ROOT/ct_tools_ui/android/app/src/main/jniLibs/arm64-v8a"

echo "[CT-TOOLS] Building native Rust crates (ct_core & ct_media for arm64-v8a)..."
cd "$PROJECT_ROOT"

cargo build --release -p ct_core -p ct_media --target aarch64-linux-android -j 2

mkdir -p "$TARGET_DIR"
cp "$PROJECT_ROOT/target/aarch64-linux-android/release/libct_core.so" "$TARGET_DIR/"
cp "$PROJECT_ROOT/target/aarch64-linux-android/release/libct_media.so" "$TARGET_DIR/"

echo "[CT-TOOLS] Deployed artifacts to: $TARGET_DIR"
