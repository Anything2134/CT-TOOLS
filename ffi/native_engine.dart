import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';
import '../ffi/native_engine.dart';

class RecorderDashboard extends StatefulWidget {
  const RecorderDashboard({super.key});

    @override
      State<RecorderDashboard> createState() => _RecorderDashboardState();
      }

      class _RecorderDashboardState extends State<RecorderDashboard> {
        bool _isRecording = false;

          void _toggleRecording() {
              if (!_isRecording) {
                    final pathPointer = "/sdcard/Movies/output.mp4".toNativeUtf8();
                          // 1080p at 8Mbps
                                final result = NativeEngineBridge.startRecording(pathPointer, 1920, 1080, 8000000);
                                      calloc.free(pathPointer);

                                            if (result == 0) {
                                                    setState(() => _isRecording = true);
                                                          }
                                                              } else {
                                                                    // Logic to trigger engine_stop_recording
                                                                          setState(() => _isRecording = false);
                                                                              }
                                                                                }

                                                                                  @override
                                                                                    Widget build(BuildContext context) {
                                                                                        return Scaffold(
                                                                                              backgroundColor: const Color(0xFF0F172A),
                                                                                                    appBar: AppBar(
                                                                                                            title: const Text('Modular OS Host - Capture Subsystem'),
                                                                                                                    backgroundColor: const Color(0xFF1E293B),
                                                                                                                          ),
                                                                                                                                body: Center(
                                                                                                                                        child: Column(
                                                                                                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                                                                                                            children: [
                                                                                                                                                                        Icon(
                                                                                                                                                                                      _isRecording ? Icons.fiber_manual_record : Icons.stop_circle_outlined,
                                                                                                                                                                                                    size: 80,
                                                                                                                                                                                                                  color: _isRecording ? Colors.redAccent : Colors.grey,
                                                                                                                                                                                                                              ),
                                                                                                                                                                                                                                          const SizedBox(height: 24),
                                                                                                                                                                                                                                                      ElevatedButton.styleFrom(
                                                                                                                                                                                                                                                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                                                                                                                                                                                                                                                                  backgroundColor: _isRecording ? Colors.red : Colors.blueAccent,
                                                                                                                                                                                                                                                                                              ).call(
                                                                                                                                                                                                                                                                                                            ElevatedButton(
                                                                                                                                                                                                                                                                                                                            onPressed: _toggleRecording,
                                                                                                                                                                                                                                                                                                                                            child: Text(_isRecording ? 'Terminate Hardware Pipeline' : 'Initialize GPU Encoder'),
                                                                                                                                                                                                                                                                                                                                                          ),
                                                                                                                                                                                                                                                                                                                                                                      ),
                                                                                                                                                                                                                                                                                                                                                                                ],
                                                                                                                                                                                                                                                                                                                                                                                        ),
                                                                                                                                                                                                                                                                                                                                                                                              ),
                                                                                                                                                                                                                                                                                                                                                                                                  );
                                                                                                                                                                                                                                                                                                                                                                                                    }
                                                                                                                                                                                                                                                                                                                                                                                                    }