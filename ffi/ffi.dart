import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef NativeInitializeEngine = ffi.Int32 Function();
typedef InitializeEngine = int Function();

typedef NativeStartRecording = ffi.Int32 Function(
  ffi.Pointer<Utf8> outputPath,
    ffi.Int32 width,
      ffi.Int32 height,
        ffi.Int32 bitRate,
        );
        typedef StartRecording = int Function(
          ffi.Pointer<Utf8> outputPath,
            int width,
              int height,
                int bitRate,
                );

                class NativeEngineBridge {
                  static final ffi.DynamicLibrary _dylib = Platform.isAndroid
                        ? ffi.DynamicLibrary.open("libcore_engine.so")
                              : throw UnsupportedError("Platform not supported");

                                static final InitializeEngine initializeEngine = _dylib
                                      .lookup<ffi.NativeFunction<NativeInitializeEngine>>("engine_initialize")
                                            .asFunction();

                                              static final StartRecording startRecording = _dylib
                                                    .lookup<ffi.NativeFunction<NativeStartRecording>>("engine_start_recording")
                                                          .asFunction();
                                                          }