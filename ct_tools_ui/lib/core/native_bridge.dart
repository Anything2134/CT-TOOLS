import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

final class VideoConfigFFI extends ffi.Struct {
  @ffi.Int32()
  external int width;

  @ffi.Int32()
  external int height;

  @ffi.Int32()
  external int frameRate;

  @ffi.Int32()
  external int bitRate;

  @ffi.Int32()
  external int bitrateMode;

  @ffi.Int32()
  external int gopSeconds;

  @ffi.Int32()
  external int lowLatency;
}

final class AudioConfigFFI extends ffi.Struct {
  @ffi.Int32()
  external int codecType;

  @ffi.Int32()
  external int sampleRate;

  @ffi.Int32()
  external int channels;

  @ffi.Int32()
  external int bitRate;

  @ffi.Int32()
  external int vbrMode;

  @ffi.Int32()
  external int complexity;

  @ffi.Float()
  external double frameDurationMs;
}

typedef NativeInitVideo = ffi.Pointer<ffi.Void> Function(
  VideoConfigFFI config,
  ffi.Pointer<Utf8> mimeType,
  ffi.Pointer<Utf8> outputPath,
);
typedef DartInitVideo = ffi.Pointer<ffi.Void> Function(
  VideoConfigFFI config,
  ffi.Pointer<Utf8> mimeType,
  ffi.Pointer<Utf8> outputPath,
);

typedef NativeStopPipeline = ffi.Int32 Function();
typedef DartStopPipeline = int Function();

typedef NativeInstallPackage = ffi.Int32 Function(
  ffi.Pointer<Utf8> storageDir,
  ffi.Pointer<Utf8> pubKeyHex,
  ffi.Pointer<Utf8> manifestJson,
);
typedef DartInstallPackage = int Function(
  ffi.Pointer<Utf8> storageDir,
  ffi.Pointer<Utf8> pubKeyHex,
  ffi.Pointer<Utf8> manifestJson,
);

class CtToolsNativeBridge {
  static final ffi.DynamicLibrary _mediaLib = Platform.isAndroid
      ? ffi.DynamicLibrary.open("libct_media.so")
      : throw UnsupportedError("Android platform required");

  static final ffi.DynamicLibrary _coreLib = Platform.isAndroid
      ? ffi.DynamicLibrary.open("libct_core.so")
      : throw UnsupportedError("Android platform required");

  static final DartInitVideo initializeVideo = _mediaLib
      .lookup<ffi.NativeFunction<NativeInitVideo>>("ct_media_initialize_video")
      .asFunction();

  static final DartStopPipeline stopMediaPipeline = _mediaLib
      .lookup<ffi.NativeFunction<NativeStopPipeline>>("ct_media_stop_pipeline")
      .asFunction();

  static final DartInstallPackage installOrHotUpdatePackage = _coreLib
      .lookup<ffi.NativeFunction<NativeInstallPackage>>("ct_core_install_package_json")
      .asFunction();
}
