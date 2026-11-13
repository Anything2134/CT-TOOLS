use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_float, c_int};
use std::ptr::null_mut;
use std::sync::Mutex;
use ndk_sys::{
    AMediaCodec, AMediaFormat, AMediaFormat_new, AMediaFormat_delete,
    AMediaFormat_setString, AMediaFormat_setInt32,
    AMediaCodec_createEncoderByType, AMediaCodec_configure,
    AMediaCodec_createInputSurface, AMediaCodec_start, AMediaCodec_stop,
    AMediaCodec_delete, ANativeWindow
};

#[repr(C)]
pub struct VideoConfigFFI {
    pub width: c_int,
    pub height: c_int,
    pub frame_rate: c_int,
    pub bit_rate: c_int,
    /// Bitrate mode: 0 = CQ, 1 = VBR, 2 = CBR, 3 = CBR_FD
    pub bitrate_mode: c_int,
    /// Equivalent to FFmpeg -g flag (GOP / Key-frame distance in seconds)
    pub gop_seconds: c_int,
}

#[repr(C)]
pub struct AudioConfigFFI {
    /// Codec type: 0 = Opus, 1 = FLAC, 2 = PCM WAV
    pub codec_type: c_int,
    pub sample_rate: c_int,
    pub channels: c_int,
    pub bit_rate: c_int,
    /// Opus VBR mode: 0 = Off, 1 = On, 2 = Constrained
    pub vbr_mode: c_int,
    /// Opus compression complexity level: 0 to 10
    pub complexity: c_int,
    /// Opus frame duration: 2.5, 5.0, 10.0, 20.0, 40.0, 60.0 ms
    pub frame_duration_ms: c_float,
}

pub struct ActiveMediaEngine {
    codec: *mut AMediaCodec,
    window_surface: *mut ANativeWindow,
    is_running: bool,
}

unsafe impl Send for ActiveMediaEngine {}
unsafe impl Sync for ActiveMediaEngine {}

static ENGINE_INSTANCE: Mutex<Option<ActiveMediaEngine>> = Mutex::new(None);

/// Initializes the hardware MediaCodec video encoder and creates a zero-copy ANativeWindow.
/// Returns pointer to ANativeWindow to be wrapped by Android VirtualDisplay.
#[no_mangle]
pub extern "C" fn ct_media_initialize_video(config: VideoConfigFFI) -> *mut ANativeWindow {
    unsafe {
        let mime = CString::new("video/avc").unwrap();
        let codec = AMediaCodec_createEncoderByType(mime.as_ptr());
        if codec.is_null() {
            return null_mut();
        }

        let format = AMediaFormat_new();
        AMediaFormat_setString(format, ndk_sys::AMEDIAFORMAT_KEY_MIME, mime.as_ptr());
        AMediaFormat_setInt32(format, ndk_sys::AMEDIAFORMAT_KEY_WIDTH, config.width);
        AMediaFormat_setInt32(format, ndk_sys::AMEDIAFORMAT_KEY_HEIGHT, config.height);
        AMediaFormat_setInt32(format, ndk_sys::AMEDIAFORMAT_KEY_FRAME_RATE, config.frame_rate);
        AMediaFormat_setInt32(format, ndk_sys::AMEDIAFORMAT_KEY_BIT_RATE, config.bit_rate);
        
        let bitrate_mode_key = CString::new("bitrate-mode").unwrap();
        AMediaFormat_setInt32(format, bitrate_mode_key.as_ptr(), config.bitrate_mode);
        AMediaFormat_setInt32(format, ndk_sys::AMEDIAFORMAT_KEY_I_FRAME_INTERVAL, config.gop_seconds);
        
        // COLOR_FormatSurface indicates zero-copy intake via Surface
        AMediaFormat_setInt32(format, ndk_sys::AMEDIAFORMAT_KEY_COLOR_FORMAT, 0x7F000789);

        let configure_result = AMediaCodec_configure(
            codec,
            format,
            null_mut(),
            null_mut(),
            ndk_sys::AMEDIACODEC_CONFIGURE_FLAG_ENCODE as u32,
        );
        AMediaFormat_delete(format);

        if configure_result != 0 {
            AMediaCodec_delete(codec);
            return null_mut();
        }

        let mut window: *mut ANativeWindow = null_mut();
        let surface_result = AMediaCodec_createInputSurface(codec, &mut window);
        if surface_result != 0 || window.is_null() {
            AMediaCodec_delete(codec);
            return null_mut();
        }

        if AMediaCodec_start(codec) != 0 {
            AMediaCodec_delete(codec);
            return null_mut();
        }

        let mut lock = ENGINE_INSTANCE.lock().unwrap();
        *lock = Some(ActiveMediaEngine {
            codec,
            window_surface: window,
            is_running: true,
        });

        window
    }
}

/// Shuts down the hardware encoder pipeline and releases native resources.
#[no_mangle]
pub extern "C" fn ct_media_stop_pipeline() -> c_int {
    let mut lock = ENGINE_INSTANCE.lock().unwrap();
    if let Some(engine) = lock.take() {
        unsafe {
            if !engine.codec.is_null() {
                AMediaCodec_stop(engine.codec);
                AMediaCodec_delete(engine.codec);
            }
        }
        0
    } else {
        -1
    }
}
