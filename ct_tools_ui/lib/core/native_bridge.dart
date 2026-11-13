import 'dart:ffi' as ffi;
import 'dart:io';

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

                                                    typedef NativeInitializeVideo = ffi.Pointer<ffi.Void> Function(VideoConfigFFI config);
                                                    typedef DartInitializeVideo = ffi.Pointer<ffi.Void> Function(VideoConfigFFI config);

                                                    typedef NativeStopPipeline = ffi.Int32 Function();
                                                    typedef DartStopPipeline = int Function();

                                                    class NativeMediaEngine {
                                                      static final ffi.DynamicLibrary _dylib = Platform.isAndroid
                                                            ? ffi.DynamicLibrary.open("libct_media.so")
                                                                  : throw UnsupportedError("Platform not supported");

                                                                    static final DartInitializeVideo initializeVideo = _dylib
                                                                          .lookup<ffi.NativeFunction<NativeInitializeVideo>>("ct_media_initialize_video")
                                                                                .asFunction();

                                                                                  static final DartStopPipeline stopPipeline = _dylib
                                                                                        .lookup<ffi.NativeFunction<NativeStopPipeline>>("ct_media_stop_pipeline")
                                                                                              .asFunction();
                                                                                              }