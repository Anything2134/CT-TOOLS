# CT-TOOLS // Hardware Multimedia & Extensible Host Ecosystem

[![License](https://img.shields.io/badge/License-Apache_2.0-red.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android_14%2B_ARM64-black.svg)]()
[![Rust](https://img.shields.io/badge/Rust-2021_Edition-orange.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.47_Native-blue.svg)]()

**CT-TOOLS** is a modular, high-performance host application for Android designed to execute sub-applications, install hot-updatable packages from P2P/HTTP repositories, and provide a low-overhead multimedia engine.

The first integrated subsystem is an advanced **Hardware Screen & Audio Recorder** powered by Android `MediaCodec` NDK, `ANativeWindow`, `libffmpeg` (`libavformat`), and custom static Xiph `libopus 1.5.2`.

---

## ⚡ Architecture Overview

```text
┌────────────────────────────────────────────────────────┐
│                   Flutter UI (Dart)                    │
│    OLED Crimson / Pure Noir / Mpv∞ Themes              │
│    Floating Bubble Controller & Home Widget Provider   │
└───────────────────────────┬────────────────────────────┘
                            │ MethodChannel & Dart FFI
┌───────────────────────────▼────────────────────────────┐
│                    Host Engine (Rust)                  │
│  - ct_core: EventBus, Ed25519/SHA-256 verifier, A/B    │
│  - ct_media: MediaCodec NDK Bridge + FFmpeg Muxer      │
│  - Xiph libopus 1.5.2 (6 - 510 kbps, VBR, 2.5 - 60ms)  │
└─────────────┬────────────────────────────┬─────────────┘
              │ JNI / ANativeWindow        │ libavformat
┌─────────────▼─────────────┐ ┌────────────▼─────────────┐
│       Android Kotlin      │ │     Storage & Outputs     │
│  - MediaProjection Service│ │  - Streaming MKV (.mkv)  │
│  - AudioCaptureEngine     │ │  - Fast-Seek MP4 (.mp4)  │
│  - Partial WakeLock Guard │ │  - Pure Audio (Opus/FLAC)│
└───────────────────────────┘ └──────────────────────────┘

✨ Features

🎥 Hardware Video Pipeline

  - Zero-Copy Surface Ingestion: Binds Android's MediaProjection directly to
    AMediaCodec_createInputSurface with hardware texture sharing
    (COLOR_FormatSurface = 0x7F000789).
  - Real ASIC Limits Querying: Dynamically discovers device encoders (c2.mtk...,
    c2.qti..., video/av01, video/hevc, video/avc), reading their maximum
    width/height, alignment, and FPS limits directly from MediaCodecList.
  - Full Native Landscape & Aspect-Fit: Supports full unscaled screen resolution
    in landscape (e.g. 2712x1220 @ 120Hz on 20:9 panels) and auto-fits within
    codec ASIC capabilities.
  - Low-Level Codec Tuning: Granular controls for -b:v, -bitrate_mode (CQ, VBR,
    CBR, CBR_FD), KEY_QUALITY, GOP size in exact frames, -r target framerate,
    and per-frame QP limits (video-qp-min/max, I/P/B).

🎙️ Advanced Audio Subsystem

  - Xiph Opus 1.5.2 Native Integration: Unrestricted bitrate selection (6 to 510
    kbps), VBR modes (Off, On, Constrained), complexity factors (0 to 10), and
    frame durations (2.5, 5.0, 10.0, 20.0, 40.0, 60.0 ms) with valid OpusHead
    headers.
  - Lossless & Uncompressed Options: High-fidelity FLAC (16/24-bit,
    compression 0–12) and raw PCM WAV/MKV.
  - Synchronized Audio Capture: Records Internal System Audio
    (AudioPlaybackCaptureConfiguration), Microphone (AudioRecord), or
    simultaneous real-time mixing.

🛡️ System Guard & Usability

  - Floating Bubble & Desktop Widget: Draggable floating overlay button with
    live REC/STOP states and an OLED Android Home Screen widget.
  - WakeLock & Battery Protection: Holds PARTIAL_WAKE_LOCK during recording and
    guides users to set background battery usage to Unrestricted.
  - Crash-Safe Matroska (.mkv) & MP4: Produces fully playable containers with
    thumbnails and instant seeking.
  - 3 Minimalist OLED Themes:
    1.  OLED Crimson: Pure Black (#000000) with Intense Red (#FF002B) accents.
    2.  Pure Noir: Pure Black & White high-contrast interface.
    3.  Mpv∞ Minimal: Subtle dark gray card aesthetic inspired by Mpv∞.

🛠️ Building Natively on Android (Termux)

No chroot or proot required. Compiles directly on Android ARM64 using Bionic
libc:

# 1. Compile native Rust & C libraries
./scripts/build_native.sh

# 2. Build the ARM64 Android APK
cd ct_tools_ui
flutter build apk --debug --target-platform android-arm64

📄 License

Licensed under the Apache License, Version 2.0 (the "License"). You may obtain a
copy of the License in the LICENSE file or at:

http://www.apache.org/licenses/LICENSE-2.0 

