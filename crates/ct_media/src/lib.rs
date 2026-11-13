#![allow(non_snake_case)]
use std::ffi::{CStr, CString};
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::os::raw::{c_char, c_float, c_int};
use std::path::Path;
use std::ptr::null_mut;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use jni::objects::{JClass, JShortArray, JString};
use jni::sys::{jint, jobject, jstring};
use jni::JNIEnv;

use ndk_sys::{
    media_status_t, AMediaCodec, AMediaCodecBufferInfo, AMediaCodec_configure,
    AMediaCodec_createCodecByName, AMediaCodec_createEncoderByType, AMediaCodec_createInputSurface,
    AMediaCodec_delete, AMediaCodec_dequeueOutputBuffer, AMediaCodec_getOutputBuffer,
    AMediaCodec_getOutputFormat, AMediaCodec_releaseOutputBuffer,
    AMediaCodec_signalEndOfInputStream, AMediaCodec_start, AMediaCodec_stop, AMediaFormat,
    AMediaFormat_delete, AMediaFormat_getBuffer, AMediaFormat_new, AMediaFormat_setFloat,
    AMediaFormat_setInt32, AMediaFormat_setString, ANativeWindow, ANativeWindow_release,
};

const AMEDIA_OK: media_status_t = media_status_t(0);
const INFO_OUTPUT_FORMAT_CHANGED: isize = -2;
const INFO_TRY_AGAIN_LATER: isize = -1;
const BUFFER_FLAG_KEY_FRAME: u32 = 1;
const BUFFER_FLAG_CODEC_CONFIG: u32 = 2;
const BUFFER_FLAG_END_OF_STREAM: u32 = 4;

#[link(name = "android")]
extern "C" {
    fn ANativeWindow_toSurface(
        env: *mut jni::sys::JNIEnv,
        window: *mut ANativeWindow,
    ) -> jni::sys::jobject;
}

#[repr(C)]
pub struct CtFfmpegBridgeOpaque {
    _private: [u8; 0],
}

type CtLogCallback = extern "C" fn(c_int, *const c_char);

extern "C" {
    fn ct_ff_create(
        output_path: *const c_char,
        mime_type: *const c_char,
        width: c_int,
        height: c_int,
        fps: c_int,
        audio_enabled: c_int,
        audio_codec_type: c_int,
        sample_rate: c_int,
        channels: c_int,
        audio_bitrate: c_int,
        opus_vbr_mode: c_int,
        audio_complexity: c_int,
        opus_frame_ms: c_float,
        flac_bit_depth: c_int,
        wav_fmt: *const c_char,
        custom_audio_args: *const c_char,
        log_cb: CtLogCallback,
    ) -> *mut CtFfmpegBridgeOpaque;

    fn ct_ff_set_video_csd_and_write_header(
        bridge: *mut CtFfmpegBridgeOpaque,
        csd: *const u8,
        csd_len: c_int,
    ) -> c_int;

    fn ct_ff_write_video_packet(
        bridge: *mut CtFfmpegBridgeOpaque,
        data: *const u8,
        len: c_int,
        pts_us: i64,
        is_keyframe: c_int,
    ) -> c_int;

    fn ct_ff_push_audio_pcm(
        bridge: *mut CtFfmpegBridgeOpaque,
        pcm_s16: *const i16,
        nb_samples_per_ch: c_int,
    ) -> c_int;

    fn ct_ff_finish_and_destroy(bridge: *mut CtFfmpegBridgeOpaque);
    fn ct_ff_last_error(bridge: *mut CtFfmpegBridgeOpaque) -> *const c_char;
}

#[repr(C)]
pub struct VideoConfigFFI {
    pub width: c_int,
    pub height: c_int,
    pub frame_rate: c_int,
    pub bit_rate: c_int,
    pub bitrate_mode: c_int,
    pub cq_quality: c_int,
    pub gop_frames: c_int,
    pub low_latency: c_int,
    pub qp_min: c_int,
    pub qp_max: c_int,
    pub qp_i_min: c_int,
    pub qp_i_max: c_int,
    pub qp_p_min: c_int,
    pub qp_p_max: c_int,
    pub qp_b_min: c_int,
    pub qp_b_max: c_int,
}

#[repr(C)]
pub struct AudioConfigFFI {
    pub enabled: c_int,
    pub codec_type: c_int,
    pub sample_rate: c_int,
    pub channels: c_int,
    pub bit_rate: c_int,
    pub vbr_mode: c_int,
    pub complexity: c_int,
    pub frame_duration_ms: c_float,
    pub flac_bit_depth: c_int,
}

pub struct ActiveMediaEngine {
    codec: *mut AMediaCodec,
    window_surface: *mut ANativeWindow,
    bridge_addr: usize,
    running: Arc<AtomicBool>,
    worker: Option<JoinHandle<()>>,
}

unsafe impl Send for ActiveMediaEngine {}
unsafe impl Sync for ActiveMediaEngine {}

static ENGINE_INSTANCE: Mutex<Option<ActiveMediaEngine>> = Mutex::new(None);
static LAST_ERROR: Mutex<String> = Mutex::new(String::new());
static LOG_FILE_PATH: Mutex<String> = Mutex::new(String::new());
static LOG_ENABLED: AtomicBool = AtomicBool::new(false);

fn set_last_error(msg: impl Into<String>) {
    let text = msg.into();
    if !text.is_empty() {
        rust_log("ERROR", &text);
    }
    if let Ok(mut guard) = LAST_ERROR.lock() {
        *guard = text;
    }
}

fn rust_log(level: &str, msg: &str) {
    if !LOG_ENABLED.load(Ordering::Relaxed) {
        return;
    }
    if let Ok(path) = LOG_FILE_PATH.lock() {
        if !path.is_empty() {
            if let Ok(mut f) = OpenOptions::new().create(true).append(true).open(&*path) {
                let _ = writeln!(f, "[RUST/{}] {}", level, msg);
            }
        }
    }
}

extern "C" fn c_bridge_log_cb(level: c_int, msg_ptr: *const c_char) {
    if msg_ptr.is_null() {
        return;
    }
    unsafe {
        if let Ok(s) = CStr::from_ptr(msg_ptr).to_str() {
            let lvl = match level {
                2 => "ERROR",
                1 => "WARN",
                _ => "INFO",
            };
            rust_log(lvl, s);
        }
    }
}

unsafe fn set_optional_int32(format: *mut AMediaFormat, key: &str, value: c_int) {
    if value >= 0 {
        let key_c = CString::new(key).unwrap();
        AMediaFormat_setInt32(format, key_c.as_ptr(), value);
    }
}

unsafe fn extract_csd_from_format(out_format: *mut AMediaFormat) -> Vec<u8> {
    let mut csd = Vec::new();
    for key_name in ["csd-0", "csd-1"] {
        let key_c = CString::new(key_name).unwrap();
        let mut ptr: *mut std::os::raw::c_void = null_mut();
        let mut size: usize = 0;
        if AMediaFormat_getBuffer(out_format, key_c.as_ptr(), &mut ptr, &mut size)
            && !ptr.is_null()
            && size > 0
        {
            let slice = std::slice::from_raw_parts(ptr as *const u8, size);
            csd.extend_from_slice(slice);
        }
    }
    csd
}

fn start_encoder_internal(
    config: VideoConfigFFI,
    audio: AudioConfigFFI,
    codec_name: &str,
    mime_str: &str,
    output_path: &str,
    wav_fmt: &str,
    custom_audio_args: &str,
) -> *mut ANativeWindow {
    set_last_error("");
    rust_log(
        "INFO",
        &format!(
            "Starting FFmpeg-backed pipeline: codec='{}' mime='{}' {}x{} @ {}fps audio={} out='{}'",
            codec_name, mime_str, config.width, config.height, config.frame_rate, audio.enabled, output_path
        ),
    );

    if let Some(parent) = Path::new(output_path).parent() {
        if let Err(e) = fs::create_dir_all(parent) {
            set_last_error(format!("Failed to create output directory: {}", e));
            return null_mut();
        }
    }

    unsafe {
        let out_c = CString::new(output_path).unwrap();
        let mime_c = CString::new(mime_str).unwrap();
        let wav_c = CString::new(wav_fmt).unwrap();
        let custom_c = CString::new(custom_audio_args).unwrap();

        let bridge = ct_ff_create(
            out_c.as_ptr(),
            mime_c.as_ptr(),
            config.width,
            config.height,
            config.frame_rate,
            audio.enabled,
            audio.codec_type,
            audio.sample_rate,
            audio.channels,
            audio.bit_rate,
            audio.vbr_mode,
            audio.complexity,
            audio.frame_duration_ms,
            audio.flac_bit_depth,
            wav_c.as_ptr(),
            custom_c.as_ptr(),
            c_bridge_log_cb,
        );

        if bridge.is_null() {
            set_last_error("ct_ff_create failed to initialize FFmpeg muxer/audio encoder");
            return null_mut();
        }

        let codec = if !codec_name.is_empty() {
            let cname = CString::new(codec_name).unwrap();
            let by_name = AMediaCodec_createCodecByName(cname.as_ptr());
            if by_name.is_null() {
                AMediaCodec_createEncoderByType(mime_c.as_ptr())
            } else {
                by_name
            }
        } else {
            AMediaCodec_createEncoderByType(mime_c.as_ptr())
        };

        if codec.is_null() {
            set_last_error(format!("Failed to allocate MediaCodec ({} / {})", codec_name, mime_str));
            ct_ff_finish_and_destroy(bridge);
            return null_mut();
        }

        let format = AMediaFormat_new();
        AMediaFormat_setString(format, ndk_sys::AMEDIAFORMAT_KEY_MIME, mime_c.as_ptr());
        AMediaFormat_setInt32(format, ndk_sys::AMEDIAFORMAT_KEY_WIDTH, config.width);
        AMediaFormat_setInt32(format, ndk_sys::AMEDIAFORMAT_KEY_HEIGHT, config.height);
        AMediaFormat_setInt32(format, ndk_sys::AMEDIAFORMAT_KEY_FRAME_RATE, config.frame_rate);
        AMediaFormat_setInt32(format, ndk_sys::AMEDIAFORMAT_KEY_BIT_RATE, config.bit_rate);
        AMediaFormat_setInt32(format, ndk_sys::AMEDIAFORMAT_KEY_COLOR_FORMAT, 0x7F000789);

        set_optional_int32(format, "operating-rate", config.frame_rate);
        set_optional_int32(format, "priority", 0);
        set_optional_int32(format, "bitrate-mode", config.bitrate_mode);

        if config.bitrate_mode == 0 && config.cq_quality >= 0 {
            set_optional_int32(format, "quality", config.cq_quality);
        }

        let safe_fps = config.frame_rate.max(1);
        let safe_gop_frames = config.gop_frames.max(1);
        if safe_gop_frames % safe_fps == 0 {
            AMediaFormat_setInt32(
                format,
                ndk_sys::AMEDIAFORMAT_KEY_I_FRAME_INTERVAL,
                safe_gop_frames / safe_fps,
            );
        } else {
            let gop_sec = (safe_gop_frames as f32) / (safe_fps as f32);
            AMediaFormat_setFloat(format, ndk_sys::AMEDIAFORMAT_KEY_I_FRAME_INTERVAL, gop_sec);
        }

        if config.low_latency == 1 {
            set_optional_int32(format, "latency", 0);
        }

        set_optional_int32(format, "video-qp-min", config.qp_min);
        set_optional_int32(format, "video-qp-max", config.qp_max);
        set_optional_int32(format, "video-qp-i-min", config.qp_i_min);
        set_optional_int32(format, "video-qp-i-max", config.qp_i_max);
        set_optional_int32(format, "video-qp-p-min", config.qp_p_min);
        set_optional_int32(format, "video-qp-p-max", config.qp_p_max);
        set_optional_int32(format, "video-qp-b-min", config.qp_b_min);
        set_optional_int32(format, "video-qp-b-max", config.qp_b_max);

        let config_status = AMediaCodec_configure(
            codec,
            format,
            null_mut(),
            null_mut(),
            ndk_sys::AMEDIACODEC_CONFIGURE_FLAG_ENCODE as u32,
        );
        AMediaFormat_delete(format);

        if config_status != AMEDIA_OK {
            set_last_error(format!("AMediaCodec_configure rejected parameters ({})", config_status.0));
            AMediaCodec_delete(codec);
            ct_ff_finish_and_destroy(bridge);
            return null_mut();
        }

        let mut window: *mut ANativeWindow = null_mut();
        if AMediaCodec_createInputSurface(codec, &mut window) != AMEDIA_OK || window.is_null() {
            set_last_error("AMediaCodec_createInputSurface failed");
            AMediaCodec_delete(codec);
            ct_ff_finish_and_destroy(bridge);
            return null_mut();
        }

        if AMediaCodec_start(codec) != AMEDIA_OK {
            set_last_error("AMediaCodec_start failed");
            ANativeWindow_release(window);
            AMediaCodec_delete(codec);
            ct_ff_finish_and_destroy(bridge);
            return null_mut();
        }

        let running = Arc::new(AtomicBool::new(true));
        let running_clone = Arc::clone(&running);
        let codec_addr = codec as usize;
        let bridge_addr = bridge as usize;

        let worker = thread::spawn(move || {
            let codec_ptr = codec_addr as *mut AMediaCodec;
            let bridge_ptr = bridge_addr as *mut CtFfmpegBridgeOpaque;
            let mut frame_count: u64 = 0;

            while running_clone.load(Ordering::Relaxed) {
                let mut info = AMediaCodecBufferInfo {
                    offset: 0,
                    size: 0,
                    presentationTimeUs: 0,
                    flags: 0,
                };

                let status = AMediaCodec_dequeueOutputBuffer(codec_ptr, &mut info, 10000);
                if status == INFO_OUTPUT_FORMAT_CHANGED {
                    let out_format = AMediaCodec_getOutputFormat(codec_ptr);
                    if !out_format.is_null() {
                        let csd = extract_csd_from_format(out_format);
                        AMediaFormat_delete(out_format);
                        if !csd.is_empty() {
                            if ct_ff_set_video_csd_and_write_header(
                                bridge_ptr,
                                csd.as_ptr(),
                                csd.len() as c_int,
                            ) != 0
                            {
                                let err_c = ct_ff_last_error(bridge_ptr);
                                if !err_c.is_null() {
                                    if let Ok(s) = CStr::from_ptr(err_c).to_str() {
                                        set_last_error(s.to_string());
                                    }
                                }
                            }
                        }
                    }
                } else if status >= 0 {
                    let mut buf_size: usize = 0;
                    let buf_ptr = AMediaCodec_getOutputBuffer(codec_ptr, status as usize, &mut buf_size);

                    if !buf_ptr.is_null() && info.size > 0 {
                        let slice = std::slice::from_raw_parts(
                            buf_ptr.offset(info.offset as isize),
                            info.size as usize,
                        );
                        if (info.flags & BUFFER_FLAG_CODEC_CONFIG) != 0 {
                            ct_ff_set_video_csd_and_write_header(
                                bridge_ptr,
                                slice.as_ptr(),
                                slice.len() as c_int,
                            );
                        } else {
                            let is_key = if (info.flags & BUFFER_FLAG_KEY_FRAME) != 0 { 1 } else { 0 };
                            ct_ff_write_video_packet(
                                bridge_ptr,
                                slice.as_ptr(),
                                slice.len() as c_int,
                                info.presentationTimeUs,
                                is_key,
                            );
                            frame_count += 1;
                        }
                    }

                    AMediaCodec_releaseOutputBuffer(codec_ptr, status as usize, false);
                    if (info.flags & BUFFER_FLAG_END_OF_STREAM) != 0 {
                        break;
                    }
                } else if status == INFO_TRY_AGAIN_LATER {
                    continue;
                }
            }

            rust_log("INFO", &format!("FFmpeg muxer worker ended (video frames: {})", frame_count));
        });

        let mut lock = ENGINE_INSTANCE.lock().unwrap();
        *lock = Some(ActiveMediaEngine {
            codec,
            window_surface: window,
            bridge_addr,
            running,
            worker: Some(worker),
        });

        window
    }
}

#[no_mangle]
pub extern "system" fn Java_com_cttools_capture_NativeMediaJni_setLogEnabled<'local>(
    _env: JNIEnv<'local>,
    _class: JClass<'local>,
    enabled: jni::sys::jboolean,
) {
    LOG_ENABLED.store(enabled != 0, Ordering::Relaxed);
}

#[no_mangle]
pub extern "system" fn Java_com_cttools_capture_NativeMediaJni_setLogPath<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    log_path_jstr: JString<'local>,
) {
    if let Ok(path) = env.get_string(&log_path_jstr) {
        if let Ok(mut guard) = LOG_FILE_PATH.lock() {
            *guard = path.into();
        }
    }
}

#[no_mangle]
pub extern "system" fn Java_com_cttools_capture_NativeMediaJni_createEncoderSurface<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    width: jint,
    height: jint,
    fps: jint,
    bit_rate: jint,
    bitrate_mode: jint,
    cq_quality: jint,
    gop_frames: jint,
    low_latency: jint,
    qp_min: jint,
    qp_max: jint,
    qp_i_min: jint,
    qp_i_max: jint,
    qp_p_min: jint,
    qp_p_max: jint,
    qp_b_min: jint,
    qp_b_max: jint,
    audio_enabled: jint,
    audio_codec_type: jint,
    audio_sample_rate: jint,
    audio_channels: jint,
    audio_bitrate: jint,
    opus_vbr_mode: jint,
    audio_complexity: jint,
    opus_frame_ms: c_float,
    flac_bit_depth: jint,
    wav_fmt_jstr: JString<'local>,
    custom_audio_jstr: JString<'local>,
    codec_name_jstr: JString<'local>,
    mime_jstr: JString<'local>,
    output_path_jstr: JString<'local>,
) -> jobject {
    let wav_fmt: String = env.get_string(&wav_fmt_jstr).map(|s| s.into()).unwrap_or_else(|_| "pcm_s16le".into());
    let custom_audio: String = env.get_string(&custom_audio_jstr).map(|s| s.into()).unwrap_or_default();
    let codec_name: String = env.get_string(&codec_name_jstr).map(|s| s.into()).unwrap_or_default();
    let mime: String = env.get_string(&mime_jstr).map(|s| s.into()).unwrap_or_else(|_| "video/avc".into());
    let output_path: String = env.get_string(&output_path_jstr).map(|s| s.into()).unwrap_or_else(|_| "/sdcard/Movies/CT-TOOLS/ct_capture.mkv".into());

    let vcfg = VideoConfigFFI {
        width,
        height,
        frame_rate: fps,
        bit_rate,
        bitrate_mode,
        cq_quality,
        gop_frames,
        low_latency,
        qp_min,
        qp_max,
        qp_i_min,
        qp_i_max,
        qp_p_min,
        qp_p_max,
        qp_b_min,
        qp_b_max,
    };

    let acfg = AudioConfigFFI {
        enabled: audio_enabled,
        codec_type: audio_codec_type,
        sample_rate: audio_sample_rate,
        channels: audio_channels,
        bit_rate: audio_bitrate,
        vbr_mode: opus_vbr_mode,
        complexity: audio_complexity,
        frame_duration_ms: opus_frame_ms,
        flac_bit_depth,
    };

    let window = start_encoder_internal(vcfg, acfg, &codec_name, &mime, &output_path, &wav_fmt, &custom_audio);
    if window.is_null() {
        return null_mut();
    }

    unsafe { ANativeWindow_toSurface(env.get_raw(), window) }
}

#[no_mangle]
pub extern "system" fn Java_com_cttools_capture_NativeMediaJni_pushAudioPcm<'local>(
    env: JNIEnv<'local>,
    _class: JClass<'local>,
    pcm_array: JShortArray<'local>,
    samples_per_channel: jint,
) -> jint {
    if samples_per_channel <= 0 {
        return 0;
    }

    let bridge_addr = match ENGINE_INSTANCE.lock() {
        Ok(guard) => match guard.as_ref() {
            Some(e) => e.bridge_addr,
            None => return -1,
        },
        Err(_) => return -1,
    };

    let len = match env.get_array_length(&pcm_array) {
        Ok(l) => l as usize,
        Err(_) => return -2,
    };

    let mut buf = vec![0i16; len];
    if env.get_short_array_region(&pcm_array, 0, &mut buf).is_err() {
        return -3;
    }

    unsafe {
        let bridge_ptr = bridge_addr as *mut CtFfmpegBridgeOpaque;
        ct_ff_push_audio_pcm(bridge_ptr, buf.as_ptr(), samples_per_channel)
    }
}

#[no_mangle]
pub extern "system" fn Java_com_cttools_capture_NativeMediaJni_getLastError<'local>(
    env: JNIEnv<'local>,
    _class: JClass<'local>,
) -> jstring {
    let err = LAST_ERROR.lock().map(|g| g.clone()).unwrap_or_default();
    env.new_string(err)
        .map(|s| s.into_raw())
        .unwrap_or(null_mut())
}

#[no_mangle]
pub extern "system" fn Java_com_cttools_capture_NativeMediaJni_stopCapture<'local>(
    _env: JNIEnv<'local>,
    _class: JClass<'local>,
) -> jint {
    ct_media_stop_pipeline()
}

#[no_mangle]
pub extern "C" fn ct_media_initialize_video(
    config: VideoConfigFFI,
    mime_ptr: *const c_char,
    output_path_ptr: *const c_char,
) -> *mut ANativeWindow {
    unsafe {
        let mime_str = if mime_ptr.is_null() { "video/avc" } else { CStr::from_ptr(mime_ptr).to_str().unwrap_or("video/avc") };
        let out_str = if output_path_ptr.is_null() { "/sdcard/Movies/CT-TOOLS/ct_capture.mkv" } else { CStr::from_ptr(output_path_ptr).to_str().unwrap_or("/sdcard/Movies/CT-TOOLS/ct_capture.mkv") };
        let acfg = AudioConfigFFI {
            enabled: 0,
            codec_type: 0,
            sample_rate: 48000,
            channels: 2,
            bit_rate: 128000,
            vbr_mode: 1,
            complexity: 10,
            frame_duration_ms: 20.0,
            flac_bit_depth: 16,
        };
        start_encoder_internal(config, acfg, "", mime_str, out_str, "pcm_s16le", "")
    }
}

#[no_mangle]
pub extern "C" fn ct_media_stop_pipeline() -> c_int {
    let mut lock = ENGINE_INSTANCE.lock().unwrap();
    if let Some(mut engine) = lock.take() {
        unsafe {
            if !engine.codec.is_null() {
                AMediaCodec_signalEndOfInputStream(engine.codec);
            }
        }
        thread::sleep(Duration::from_millis(250));
        engine.running.store(false, Ordering::Relaxed);
        if let Some(handle) = engine.worker.take() {
            let _ = handle.join();
        }
        unsafe {
            if !engine.codec.is_null() {
                AMediaCodec_stop(engine.codec);
                AMediaCodec_delete(engine.codec);
            }
            if !engine.window_surface.is_null() {
                ANativeWindow_release(engine.window_surface);
            }
            if engine.bridge_addr != 0 {
                ct_ff_finish_and_destroy(engine.bridge_addr as *mut CtFfmpegBridgeOpaque);
            }
        }
        0
    } else {
        -1
    }
}
