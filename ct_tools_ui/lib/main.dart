import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ffi/ffi.dart';
import 'core/native_bridge.dart';

const _platformChannel = MethodChannel('com.cttools/platform');

void _forwardFlutterLog(String level, String source, String message) {
  try {
    _platformChannel.invokeMethod('appendLog', {
      'level': level,
      'source': source,
      'message': message,
    });
  } catch (_) {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _forwardFlutterLog('ERROR', 'FlutterError', details.exceptionAsString());
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _forwardFlutterLog('ERROR', 'DartUncaught', '$error\n$stack');
    return true;
  };

  runApp(const CtToolsApp());
}

enum CtThemeMode { oledCrimson, pureNoir, mpvInfinite }

class CtToolsApp extends StatefulWidget {
  const CtToolsApp({super.key});

  @override
  State<CtToolsApp> createState() => _CtToolsAppState();
}

class _CtToolsAppState extends State<CtToolsApp> {
  CtThemeMode _themeMode = CtThemeMode.oledCrimson;

  void _cycleTheme() {
    setState(() {
      _themeMode = switch (_themeMode) {
        CtThemeMode.oledCrimson => CtThemeMode.pureNoir,
        CtThemeMode.pureNoir => CtThemeMode.mpvInfinite,
        CtThemeMode.mpvInfinite => CtThemeMode.oledCrimson,
      };
      _platformChannel.invokeMethod('setBubbleTheme', {'theme': _themeMode.name});
    });
  }

  ThemeData _buildOledCrimsonTheme() {
    const pureBlack = Color(0xFF000000);
    const panelGray = Color(0xFF121212);
    const pureRed = Color(0xFFFF002B);
    const pureWhite = Color(0xFFFFFFFF);

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: pureBlack,
      colorScheme: const ColorScheme.dark(
        primary: pureRed,
        onPrimary: pureWhite,
        secondary: pureRed,
        onSecondary: pureWhite,
        surface: panelGray,
        onSurface: pureWhite,
        outline: pureRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureBlack,
        foregroundColor: pureWhite,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: pureRed, width: 1.2)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pureBlack,
        indicatorColor: pureRed.withValues(alpha: 0.25),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: pureRed);
          }
          return const IconThemeData(color: pureWhite);
        }),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: pureWhite, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: panelGray,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: pureRed, width: 1.3),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0A0A0A),
        labelStyle: const TextStyle(color: pureWhite),
        hintStyle: const TextStyle(color: Colors.white54),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: pureRed, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFFF3355), width: 2.0),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: pureRed, width: 1.2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF181818),
        labelStyle: const TextStyle(color: pureWhite, fontSize: 12),
        side: const BorderSide(color: pureRed, width: 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pureWhite,
          side: const BorderSide(color: pureRed, width: 1.3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pureRed,
          foregroundColor: pureWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: pureRed,
        thumbColor: pureWhite,
        inactiveTrackColor: Color(0xFF3A0A12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(pureWhite),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? pureRed : const Color(0xFF2A2A2A);
        }),
        trackOutlineColor: WidgetStateProperty.all(pureRed),
      ),
    );
  }

  ThemeData _buildPureNoirTheme() {
    const pureBlack = Color(0xFF000000);
    const noirPanel = Color(0xFF080808);
    const pureWhite = Color(0xFFFFFFFF);

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: pureBlack,
      colorScheme: const ColorScheme.dark(
        primary: pureWhite,
        onPrimary: pureBlack,
        secondary: pureWhite,
        onSecondary: pureBlack,
        surface: noirPanel,
        onSurface: pureWhite,
        outline: pureWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureBlack,
        foregroundColor: pureWhite,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: pureWhite, width: 1.2)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pureBlack,
        indicatorColor: pureWhite,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: pureBlack);
          }
          return const IconThemeData(color: pureWhite);
        }),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: pureWhite, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: noirPanel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: pureWhite, width: 1.3),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pureBlack,
        labelStyle: const TextStyle(color: pureWhite),
        hintStyle: const TextStyle(color: Colors.white54),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: pureWhite, width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: pureWhite, width: 2.0),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: pureWhite, width: 1.1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: pureBlack,
        labelStyle: const TextStyle(color: pureWhite, fontSize: 12),
        side: const BorderSide(color: pureWhite, width: 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pureWhite,
          side: const BorderSide(color: pureWhite, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pureWhite,
          foregroundColor: pureBlack,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: pureWhite,
        thumbColor: pureWhite,
        inactiveTrackColor: Color(0xFF262626),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? pureBlack : pureWhite;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? pureWhite : pureBlack;
        }),
        trackOutlineColor: WidgetStateProperty.all(pureWhite),
      ),
    );
  }

  ThemeData _buildMpvInfiniteTheme() {
    const pureBlack = Color(0xFF000000);
    const panelGray = Color(0xFF161618);
    const subtleBorder = Color(0xFF2C2C2E);
    const pureWhite = Color(0xFFFFFFFF);

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: pureBlack,
      colorScheme: const ColorScheme.dark(
        primary: pureWhite,
        onPrimary: pureBlack,
        secondary: Color(0xFFD4D4D8),
        onSecondary: pureBlack,
        surface: panelGray,
        onSurface: pureWhite,
        outline: subtleBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureBlack,
        foregroundColor: pureWhite,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: subtleBorder, width: 1.0)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0C0C0E),
        indicatorColor: const Color(0xFF2C2C2E),
        iconTheme: WidgetStateProperty.all(const IconThemeData(color: pureWhite)),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: pureWhite, fontSize: 12),
        ),
      ),
      cardTheme: CardThemeData(
        color: panelGray,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: subtleBorder, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF101012),
        labelStyle: const TextStyle(color: Color(0xFFE4E4E7)),
        hintStyle: const TextStyle(color: Colors.white54),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: pureWhite, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: subtleBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF202024),
        labelStyle: const TextStyle(color: pureWhite, fontSize: 12),
        side: const BorderSide(color: subtleBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pureWhite,
          side: const BorderSide(color: subtleBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF27272A),
          foregroundColor: pureWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: pureWhite,
        thumbColor: pureWhite,
        inactiveTrackColor: Color(0xFF2C2C2E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = switch (_themeMode) {
      CtThemeMode.oledCrimson => _buildOledCrimsonTheme(),
      CtThemeMode.pureNoir => _buildPureNoirTheme(),
      CtThemeMode.mpvInfinite => _buildMpvInfiniteTheme(),
    };

    return MaterialApp(
      title: 'CT-TOOLS',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: CtToolsShell(
        themeMode: _themeMode,
        onCycleTheme: _cycleTheme,
      ),
    );
  }
}

class CtToolsShell extends StatefulWidget {
  final CtThemeMode themeMode;
  final VoidCallback onCycleTheme;

  const CtToolsShell({
    super.key,
    required this.themeMode,
    required this.onCycleTheme,
  });

  @override
  State<CtToolsShell> createState() => _CtToolsShellState();
}

class _CtToolsShellState extends State<CtToolsShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bottomBorderColor = switch (widget.themeMode) {
      CtThemeMode.oledCrimson => const Color(0xFFFF002B),
      CtThemeMode.pureNoir => const Color(0xFFFFFFFF),
      CtThemeMode.mpvInfinite => const Color(0xFF2C2C2E),
    };

    final (themeIcon, themeColor, themeTooltip) = switch (widget.themeMode) {
      CtThemeMode.oledCrimson => (Icons.local_fire_department, const Color(0xFFFF002B), 'Theme: OLED Crimson'),
      CtThemeMode.pureNoir => (Icons.contrast, const Color(0xFFFFFFFF), 'Theme: Pure Noir B&W'),
      CtThemeMode.mpvInfinite => (Icons.dark_mode_outlined, const Color(0xFFD4D4D8), 'Theme: Mpv∞ Minimal'),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('CT-TOOLS // Engine Host'),
        actions: [
          IconButton(
            tooltip: themeTooltip,
            onPressed: widget.onCycleTheme,
            icon: Icon(themeIcon, color: themeColor),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          RecorderModuleView(themeMode: widget.themeMode),
          const EcosystemManagerView(),
          LogViewerTab(borderColor: bottomBorderColor),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: bottomBorderColor,
              width: widget.themeMode == CtThemeMode.mpvInfinite ? 1.0 : 1.2,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.videocam_outlined),
              selectedIcon: Icon(Icons.videocam),
              label: 'Recorder',
            ),
            NavigationDestination(
              icon: Icon(Icons.hub_outlined),
              selectedIcon: Icon(Icons.hub),
              label: 'P2P & Modules',
            ),
            NavigationDestination(
              icon: Icon(Icons.terminal_outlined),
              selectedIcon: Icon(Icons.terminal),
              label: 'Logs',
            ),
          ],
        ),
      ),
    );
  }
}

class RecorderModuleView extends StatefulWidget {
  final CtThemeMode themeMode;
  const RecorderModuleView({super.key, required this.themeMode});

  @override
  State<RecorderModuleView> createState() => _RecorderModuleViewState();
}

class _RecorderModuleViewState extends State<RecorderModuleView> with WidgetsBindingObserver {
  bool _isRecording = false;
  bool _hasStorageAccess = false;
  bool _ignoringBatteryOpt = true;
  bool _hasOverlayPerm = false;
  bool _bubbleActive = false;

  bool _autoAspectFit = true;
  int _orientationMode = 0; // 0=Auto, 1=Portrait, 2=Landscape

  int _panelLongSide = 2712;
  int _panelShortSide = 1220;
  bool _deviceIsCurrentlyLandscape = false;
  int _panelRefresh = 120;

  List<Map<String, dynamic>> _encoders = [];
  Map<String, dynamic>? _selectedEncoder;

  final TextEditingController _outputDirCtrl =
      TextEditingController(text: '/sdcard/Movies/CT-TOOLS');
  final TextEditingController _widthCtrl = TextEditingController(text: '1080');
  final TextEditingController _heightCtrl = TextEditingController(text: '2400');
  final TextEditingController _fpsCtrl = TextEditingController(text: '60');
  final TextEditingController _bitrateKbpsCtrl = TextEditingController(text: '16000');
  final TextEditingController _gopFramesCtrl = TextEditingController(text: '120');
  final TextEditingController _cqQualityCtrl = TextEditingController(text: '80');

  String _containerFormat = 'auto';
  int _bitrateMode = 1;
  bool _lowLatency = false;

  final TextEditingController _qpMinCtrl = TextEditingController();
  final TextEditingController _qpMaxCtrl = TextEditingController();
  final TextEditingController _qpIMinCtrl = TextEditingController();
  final TextEditingController _qpIMaxCtrl = TextEditingController();
  final TextEditingController _qpPMinCtrl = TextEditingController();
  final TextEditingController _qpPMaxCtrl = TextEditingController();
  final TextEditingController _qpBMinCtrl = TextEditingController();
  final TextEditingController _qpBMaxCtrl = TextEditingController();

  int _audioSource = 1;
  int _audioCodec = 0;
  int _audioSampleRate = 48000;
  int _audioChannels = 2;

  final TextEditingController _opusBitrateKbpsCtrl = TextEditingController(text: '128');
  int _opusVbrMode = 1;
  int _opusComplexity = 10;
  double _opusFrameDuration = 20.0;

  int _flacCompression = 8;
  int _flacBitDepth = 24;
  String _wavSampleFormat = 'pcm_s16le';

  final TextEditingController _customAudioArgsCtrl = TextEditingController();
  String _statusMessage = 'Probing display & ASIC hardware encoders...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initHardwareMetadata();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSystemStates();
    }
  }

  Future<void> _refreshSystemStates() async {
    final hasPerm = await _platformChannel.invokeMethod<bool>('hasAllFilesPermission') ?? false;
    final batt = await _platformChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
    final overlay = await _platformChannel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    final bubble = await _platformChannel.invokeMethod<bool>('isFloatingBubbleActive') ?? false;
    final rec = await _platformChannel.invokeMethod<bool>('isRecordingActive') ?? false;
    if (mounted) {
      setState(() {
        _hasStorageAccess = hasPerm;
        _ignoringBatteryOpt = batt;
        _hasOverlayPerm = overlay;
        _bubbleActive = bubble;
        _isRecording = rec;
      });
    }
  }

  Future<void> _initHardwareMetadata() async {
    try {
      await _refreshSystemStates();
      final spec = await _platformChannel.invokeMapMethod<String, dynamic>('getMaxDisplaySpec');
      final rawEncoders = await _platformChannel.invokeListMethod<dynamic>('getVideoEncoders');

      if (!mounted) return;
      setState(() {
        if (spec != null) {
          final w = (spec['width'] as num).toInt();
          final h = (spec['height'] as num).toInt();
          _panelLongSide = w > h ? w : h;
          _panelShortSide = w > h ? h : w;
          _deviceIsCurrentlyLandscape = (spec['isLandscape'] as bool?) ?? (w > h);
          _panelRefresh = (spec['refreshRate'] as num).round();
          _fpsCtrl.text = _panelRefresh.toString();
        }
        if (rawEncoders != null && rawEncoders.isNotEmpty) {
          _encoders = rawEncoders.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _selectedEncoder = _encoders.first;
          _syncEncoderBounds();
        } else {
          _applyMaxSupportedResolution();
        }
        final (pw, ph) = _effectivePanelSize();
        _statusMessage = 'Panel: ${pw}x$ph @ ${_panelRefresh}Hz | Encoders: ${_encoders.length}';
      });
    } catch (e) {
      _forwardFlutterLog('ERROR', 'RecorderUI', 'Hardware probe failed: $e');
      setState(() => _statusMessage = 'Probe failed: $e');
    }
  }

  bool _isEffectiveLandscape() {
    return switch (_orientationMode) {
      1 => false,
      2 => true,
      _ => _deviceIsCurrentlyLandscape,
    };
  }

  (int, int) _effectivePanelSize() {
    if (_isEffectiveLandscape()) {
      return (_panelLongSide, _panelShortSide);
    }
    return (_panelShortSide, _panelLongSide);
  }

  void _syncEncoderBounds() {
    final enc = _selectedEncoder;
    if (enc == null) return;

    final modes = (enc['supportedBitrateModes'] as List?)?.cast<int>() ?? [1];
    if (!modes.contains(_bitrateMode) && modes.isNotEmpty) {
      _bitrateMode = modes.first;
    }

    final qMin = (enc['qualityMin'] as num?)?.toInt() ?? 0;
    final qMax = (enc['qualityMax'] as num?)?.toInt() ?? 100;
    final currentQ = int.tryParse(_cqQualityCtrl.text) ?? 80;
    _cqQualityCtrl.text = currentQ.clamp(qMin, qMax).toString();

    _applyMaxSupportedResolution();
  }

  (int, int) _computeAspectFitSize(int desiredW, int desiredH) {
    final enc = _selectedEncoder;
    final alignW = ((enc?['widthAlignment'] as num?)?.toInt() ?? 2).clamp(1, 64);
    final alignH = ((enc?['heightAlignment'] as num?)?.toInt() ?? 2).clamp(1, 64);

    if (enc == null) {
      return ((desiredW ~/ alignW) * alignW, (desiredH ~/ alignH) * alignH);
    }

    final asicMinW = (enc['minWidth'] as num?)?.toInt() ?? 16;
    final asicMaxW = (enc['maxWidth'] as num?)?.toInt() ?? desiredW;
    final asicMinH = (enc['minHeight'] as num?)?.toInt() ?? 16;
    final asicMaxH = (enc['maxHeight'] as num?)?.toInt() ?? desiredH;

    final (pw, ph) = _effectivePanelSize();
    final supportsFull = enc['supportsPanelPortrait'] == true;
    if (supportsFull && desiredW == pw && desiredH == ph) {
      return ((desiredW ~/ alignW) * alignW, (desiredH ~/ alignH) * alignH);
    }

    double scale = 1.0;
    if (desiredW > asicMaxW) {
      scale = asicMaxW / desiredW;
    }
    if (desiredH * scale > asicMaxH) {
      scale = asicMaxH / desiredH;
    }

    int w = ((desiredW * scale).floor() ~/ alignW) * alignW;
    int h = ((desiredH * scale).floor() ~/ alignH) * alignH;
    w = w.clamp(asicMinW, asicMaxW);
    h = h.clamp(asicMinH, asicMaxH);
    return (w, h);
  }

  void _applyMaxSupportedResolution() {
    final (pw, ph) = _effectivePanelSize();
    final (w, h) = _autoAspectFit
        ? _computeAspectFitSize(pw, ph)
        : (
            pw.clamp(16, (_selectedEncoder?['maxWidth'] as num?)?.toInt() ?? pw),
            ph.clamp(16, (_selectedEncoder?['maxHeight'] as num?)?.toInt() ?? ph),
          );
    _widthCtrl.text = w.toString();
    _heightCtrl.text = h.toString();
  }

  void _applyScaledPreset(int shortSideTarget) {
    final isLand = _isEffectiveLandscape();
    final ratio = _panelLongSide / _panelShortSide;
    final desiredW = isLand ? (shortSideTarget * ratio).round() : shortSideTarget;
    final desiredH = isLand ? shortSideTarget : (shortSideTarget * ratio).round();
    final (w, h) = _computeAspectFitSize(desiredW, desiredH);
    setState(() {
      _widthCtrl.text = w.toString();
      _heightCtrl.text = h.toString();
    });
  }

  int _parseOptionalQp(TextEditingController ctrl) {
    final val = int.tryParse(ctrl.text.trim());
    return (val != null && val >= 0) ? val : -1;
  }

  Map<String, dynamic> _collectRecorderConfig({required String outputPath}) {
    final enc = _selectedEncoder;
    final mime = (enc?['mime'] as String?) ?? 'video/avc';
    final codecName = (enc?['name'] as String?) ?? '';
    final alignW = ((enc?['widthAlignment'] as num?)?.toInt() ?? 2).clamp(1, 64);
    final alignH = ((enc?['heightAlignment'] as num?)?.toInt() ?? 2).clamp(1, 64);
    final (pw, ph) = _effectivePanelSize();

    final rawW = int.tryParse(_widthCtrl.text.trim()) ?? pw;
    final rawH = int.tryParse(_heightCtrl.text.trim()) ?? ph;
    final (w, h) = _autoAspectFit
        ? _computeAspectFitSize(rawW, rawH)
        : (((rawW ~/ alignW) * alignW).clamp(16, 8192), ((rawH ~/ alignH) * alignH).clamp(16, 8192));

    _widthCtrl.text = w.toString();
    _heightCtrl.text = h.toString();

    final fps = (int.tryParse(_fpsCtrl.text.trim()) ?? _panelRefresh).clamp(1, 240);
    final bitRateBps =
        ((int.tryParse(_bitrateKbpsCtrl.text.trim()) ?? 16000) * 1000).clamp(100000, 200000000);
    final gopFrames = (int.tryParse(_gopFramesCtrl.text.trim()) ?? (fps * 2)).clamp(1, 36000);
    final cqQuality = int.tryParse(_cqQualityCtrl.text.trim()) ?? -1;

    return {
      'orientationMode': _orientationMode,
      'autoAspectFit': _autoAspectFit,
      'width': w,
      'height': h,
      'fps': fps,
      'bitRate': bitRateBps,
      'bitrateMode': _bitrateMode,
      'cqQuality': _bitrateMode == 0 ? cqQuality : -1,
      'gopFrames': gopFrames,
      'lowLatency': _lowLatency ? 1 : 0,
      'qpMin': _parseOptionalQp(_qpMinCtrl),
      'qpMax': _parseOptionalQp(_qpMaxCtrl),
      'qpIMin': _parseOptionalQp(_qpIMinCtrl),
      'qpIMax': _parseOptionalQp(_qpIMaxCtrl),
      'qpPMin': _parseOptionalQp(_qpPMinCtrl),
      'qpPMax': _parseOptionalQp(_qpPMaxCtrl),
      'qpBMin': _parseOptionalQp(_qpBMinCtrl),
      'qpBMax': _parseOptionalQp(_qpBMaxCtrl),
      'audioSource': _audioSource,
      'audioCodecType': _audioCodec,
      'audioSampleRate': _audioSampleRate,
      'audioChannels': _audioChannels,
      'audioBitrate':
          ((int.tryParse(_opusBitrateKbpsCtrl.text.trim()) ?? 128) * 1000).clamp(6000, 510000),
      'opusVbrMode': _opusVbrMode,
      'audioComplexity': _audioCodec == 1 ? _flacCompression : _opusComplexity,
      'opusFrameMs': _opusFrameDuration,
      'flacBitDepth': _flacBitDepth,
      'wavFmt': _wavSampleFormat,
      'customAudioArgs': _customAudioArgsCtrl.text.trim(),
      'codecName': codecName,
      'mimeType': mime,
      'outputDir': _outputDirCtrl.text.trim(),
      'containerFormat': _containerFormat,
      'outputPath': outputPath,
    };
  }

  Future<void> _toggleBubble() async {
    if (!_hasOverlayPerm) {
      await _platformChannel.invokeMethod('requestOverlayPermission');
      return;
    }
    final cfg = _collectRecorderConfig(outputPath: '');
    final active = await _platformChannel.invokeMethod<bool>('toggleFloatingBubble', cfg) ?? false;
    setState(() => _bubbleActive = active);
  }

  Future<void> _requestStorageAccess() async {
    await _platformChannel.invokeMethod('requestAllFilesPermission');
    await Future.delayed(const Duration(seconds: 1));
    await _refreshSystemStates();
  }

  Future<void> _toggleCapture() async {
    try {
      if (!_isRecording) {
        final hasPerm = await _platformChannel.invokeMethod<bool>('hasAllFilesPermission') ?? false;
        final dir = _outputDirCtrl.text.trim();
        if (dir.startsWith('/sdcard') && !hasPerm) {
          setState(() => _statusMessage = 'Please grant All Files Access first to write to $dir');
          await _requestStorageAccess();
          return;
        }

        final mime = (_selectedEncoder?['mime'] as String?) ?? 'video/avc';
        final ext = _containerFormat == 'mp4'
            ? 'mp4'
            : (_containerFormat == 'mkv'
                ? 'mkv'
                : ((_audioCodec == 2 && _audioSource > 0) || mime == 'video/avc' ? 'mkv' : 'mp4'));
        final cleanDir = dir.endsWith('/') ? dir.substring(0, dir.length - 1) : dir;
        final outPath = '$cleanDir/ct_capture_${DateTime.now().millisecondsSinceEpoch}.$ext';

        final payload = _collectRecorderConfig(outputPath: outPath);
        final started = await _platformChannel.invokeMethod<bool>('startScreenCapture', payload);

        if (started == true) {
          await Future.delayed(const Duration(milliseconds: 600));
          final err = await _platformChannel.invokeMethod<String>('getLastCaptureError') ?? '';
          if (err.isNotEmpty) {
            setState(() => _statusMessage = 'Encoder error: $err');
          } else {
            setState(() {
              _isRecording = true;
              _statusMessage =
                  'Recording ${payload['width']}x${payload['height']} @ ${payload['fps']}fps ($mime) -> $outPath';
            });
          }
        }
      } else {
        await _platformChannel.invokeMethod<bool>('stopScreenCapture');
        setState(() {
          _isRecording = false;
          _statusMessage = 'Hardware capture finalized and flushed.';
        });
      }
    } catch (e) {
      _forwardFlutterLog('ERROR', 'RecorderUI', 'Capture exception: $e');
      setState(() => _statusMessage = 'Capture error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final enc = _selectedEncoder;
    final asicMaxW = enc?['maxWidth'] ?? _panelLongSide;
    final asicMaxH = enc?['maxHeight'] ?? _panelShortSide;
    final asicMaxFps = (enc?['maxFps'] as num?)?.round() ?? 120;
    final qMin = (enc?['qualityMin'] as num?)?.toInt() ?? 0;
    final qMax = (enc?['qualityMax'] as num?)?.toInt() ?? 100;
    final supportedModes = (enc?['supportedBitrateModes'] as List?)?.cast<int>() ?? [0, 1, 2];
    final (effW, effH) = _effectivePanelSize();

    final statusColor = switch (widget.themeMode) {
      CtThemeMode.oledCrimson => const Color(0xFFFF4D6D),
      CtThemeMode.pureNoir => const Color(0xFFFFFFFF),
      CtThemeMode.mpvInfinite => Colors.white70,
    };

    final (btnBg, btnFg) = _isRecording
        ? (const Color(0xFFB91C1C), Colors.white)
        : switch (widget.themeMode) {
            CtThemeMode.oledCrimson => (const Color(0xFFFF002B), Colors.white),
            CtThemeMode.pureNoir => (Colors.white, Colors.black),
            CtThemeMode.mpvInfinite => (const Color(0xFF27272A), Colors.white),
          };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // System Guard, WakeLock, Battery & Floating Bubble Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('System Guard & Floating Overlay', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  _ignoringBatteryOpt
                      ? 'Battery Policy: Unrestricted (Protected against OS kill, WakeLock active during capture).'
                      : 'Recommendation: Disable background battery restrictions (set to Unrestricted) so Android does not terminate recordings.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _ignoringBatteryOpt ? Colors.greenAccent : Colors.amberAccent,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleBubble,
                      icon: Icon(_bubbleActive ? Icons.layers_clear : Icons.bubble_chart),
                      label: Text(
                        !_hasOverlayPerm
                            ? 'Grant Overlay Permission'
                            : (_bubbleActive ? 'Hide Floating Bubble' : 'Show Floating Bubble'),
                      ),
                    ),
                    if (!_ignoringBatteryOpt)
                      OutlinedButton.icon(
                        onPressed: () => _platformChannel.invokeMethod('requestIgnoreBatteryOptimizations'),
                        icon: const Icon(Icons.battery_saver),
                        label: const Text('Set Battery Unrestricted'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Output Destination Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Output Destination', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _outputDirCtrl,
                  enabled: !_isRecording,
                  decoration: const InputDecoration(labelText: 'Output Directory Path'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('/sdcard/Movies/CT-TOOLS'),
                      onPressed: _isRecording
                          ? null
                          : () => setState(() => _outputDirCtrl.text = '/sdcard/Movies/CT-TOOLS'),
                    ),
                    ActionChip(
                      label: const Text('/sdcard/Download'),
                      onPressed: _isRecording
                          ? null
                          : () => setState(() => _outputDirCtrl.text = '/sdcard/Download'),
                    ),
                    ActionChip(
                      label: const Text('App Private'),
                      onPressed: _isRecording
                          ? null
                          : () async {
                              final p = await _platformChannel.invokeMethod<String>('getStorageDir');
                              if (p != null) setState(() => _outputDirCtrl.text = p);
                            },
                    ),
                  ],
                ),
                if (!_hasStorageAccess) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _requestStorageAccess,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Grant All Files Access (/sdcard write permission)'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Video Display & MediaCodec Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hardware Display & MediaCodec', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(_statusMessage, style: TextStyle(color: statusColor, fontSize: 12)),
                const SizedBox(height: 12),
                if (_encoders.isNotEmpty)
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedEncoder,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Device Video Encoder (ASIC / SW)'),
                    items: _encoders.map((e) {
                      final hwTag = (e['isHardware'] == true) ? 'HW' : 'SW';
                      return DropdownMenuItem(
                        value: e,
                        child: Text(
                          '${e['mime']} | ${e['name']} ($hwTag)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _isRecording
                        ? null
                        : (val) => setState(() {
                              _selectedEncoder = val;
                              _syncEncoderBounds();
                            }),
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _orientationMode,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Capture Orientation (Games & Apps)'),
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text('Auto (Detect Active Screen Orientation)', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text('Force Portrait (Vertical)', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text('Force Landscape (Horizontal Games - Full Res)', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: _isRecording
                      ? null
                      : (v) => setState(() {
                            _orientationMode = v ?? 0;
                            _applyMaxSupportedResolution();
                          }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _containerFormat,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Container Format'),
                  items: const [
                    DropdownMenuItem(
                      value: 'auto',
                      child: Text('Auto (H.264/PCM -> MKV, Else MP4)', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'mkv',
                      child: Text('Matroska (.mkv - All Codecs)', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'mp4',
                      child: Text('MPEG-4 (.mp4 - H.264 / HEVC / AV1)', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: _isRecording ? null : (v) => setState(() => _containerFormat = v ?? 'auto'),
                ),
                const SizedBox(height: 10),
                Text(
                  'ASIC Limits: Max ${asicMaxW}x$asicMaxH | Max ${asicMaxFps}fps | Target Panel: ${effW}x$effH',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  softWrap: true,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-Fit Aspect Ratio to ASIC'),
                  subtitle: const Text(
                    'Preserves exact 20:9 / 9:20 ratio within codec ASIC limits',
                    style: TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                  value: _autoAspectFit,
                  onChanged: _isRecording
                      ? null
                      : (v) => setState(() {
                            _autoAspectFit = v;
                            _applyMaxSupportedResolution();
                          }),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _widthCtrl,
                        enabled: !_isRecording,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Width'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _heightCtrl,
                        enabled: !_isRecording,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Height'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _fpsCtrl,
                        enabled: !_isRecording,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'FPS (-r)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Aspect-Fit Max'),
                      onPressed: _isRecording ? null : () => setState(_applyMaxSupportedResolution),
                    ),
                    ActionChip(
                      label: const Text('1080p Aspect'),
                      onPressed: _isRecording ? null : () => _applyScaledPreset(1080),
                    ),
                    ActionChip(
                      label: const Text('720p Aspect'),
                      onPressed: _isRecording ? null : () => _applyScaledPreset(720),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _bitrateMode,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Rate Control (-bitrate_mode)'),
                  items: [
                    if (supportedModes.contains(0))
                      const DropdownMenuItem(value: 0, child: Text('CQ (Constant Quality)', overflow: TextOverflow.ellipsis)),
                    if (supportedModes.contains(1))
                      const DropdownMenuItem(value: 1, child: Text('VBR (Variable Bitrate)', overflow: TextOverflow.ellipsis)),
                    if (supportedModes.contains(2))
                      const DropdownMenuItem(value: 2, child: Text('CBR (Constant Bitrate)', overflow: TextOverflow.ellipsis)),
                    if (supportedModes.contains(3))
                      const DropdownMenuItem(value: 3, child: Text('CBR_FD (CBR Frame Drop)', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: _isRecording ? null : (v) => setState(() => _bitrateMode = v ?? 1),
                ),
                const SizedBox(height: 12),
                if (_bitrateMode == 0) ...[
                  TextField(
                    controller: _cqQualityCtrl,
                    enabled: !_isRecording,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'CQ Quality (KEY_QUALITY: $qMin - $qMax)',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bitrateKbpsCtrl,
                        enabled: !_isRecording,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Bitrate (-b:v kbps)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _gopFramesCtrl,
                        enabled: !_isRecording,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'GOP Size (frames)'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Low-Latency Hardware Flag'),
                  value: _lowLatency,
                  onChanged: _isRecording ? null : (v) => setState(() => _lowLatency = v),
                ),
                ExpansionTile(
                  title: const Text('MediaCodec Quantization (QP Bounds - API 31+)'),
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qpMinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Global QP Min'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _qpMaxCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Global QP Max'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qpIMinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'I-Frame QP Min'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _qpIMaxCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'I-Frame QP Max'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qpPMinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'P-Frame QP Min'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _qpPMaxCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'P-Frame QP Max'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qpBMinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'B-Frame QP Min'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _qpBMaxCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'B-Frame QP Max'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Audio Pipeline Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Audio Pipeline Configuration', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _audioSource,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Audio Source'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('None (Video Only)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 1, child: Text('Internal System Audio', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 2, child: Text('Microphone', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 3, child: Text('Internal + Microphone', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: _isRecording ? null : (v) => setState(() => _audioSource = v ?? 1),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _audioCodec,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Audio Format'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Opus (Xiph High Efficiency)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 1, child: Text('FLAC (Lossless)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 2, child: Text('PCM (Uncompressed)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 3, child: Text('Custom FFmpeg Arguments', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _audioCodec = v ?? 0),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _audioSampleRate,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Sample Rate'),
                        items: const [
                          DropdownMenuItem(value: 44100, child: Text('44100 Hz', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 48000, child: Text('48000 Hz', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 96000, child: Text('96000 Hz', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 192000, child: Text('192000 Hz', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => _audioSampleRate = v ?? 48000),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _audioChannels,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Channels'),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Mono (1ch)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 2, child: Text('Stereo (2ch)', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => _audioChannels = v ?? 2),
                      ),
                    ),
                  ],
                ),
                if (_audioCodec == 0) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _opusBitrateKbpsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Opus Bitrate (6 - 510 kbps unrestricted)',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  Slider(
                    value: (double.tryParse(_opusBitrateKbpsCtrl.text) ?? 128).clamp(6.0, 510.0),
                    min: 6,
                    max: 510,
                    onChanged: (v) => setState(() => _opusBitrateKbpsCtrl.text = v.round().toString()),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _opusVbrMode,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Opus VBR Mode'),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Off (Hard CBR)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 1, child: Text('On (Unconstrained VBR)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 2, child: Text('Constrained VBR', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _opusVbrMode = v ?? 1),
                  ),
                  const SizedBox(height: 8),
                  Text('Compression Complexity (0-10): $_opusComplexity'),
                  Slider(
                    value: _opusComplexity.toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    onChanged: (v) => setState(() => _opusComplexity = v.round()),
                  ),
                  DropdownButtonFormField<double>(
                    initialValue: _opusFrameDuration,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Opus Frame Duration (ms)'),
                    items: const [
                      DropdownMenuItem(value: 2.5, child: Text('2.5 ms')),
                      DropdownMenuItem(value: 5.0, child: Text('5.0 ms')),
                      DropdownMenuItem(value: 10.0, child: Text('10.0 ms')),
                      DropdownMenuItem(value: 20.0, child: Text('20.0 ms')),
                      DropdownMenuItem(value: 40.0, child: Text('40.0 ms')),
                      DropdownMenuItem(value: 60.0, child: Text('60.0 ms')),
                    ],
                    onChanged: (v) => setState(() => _opusFrameDuration = v ?? 20.0),
                  ),
                ],
                if (_audioCodec == 1) ...[
                  const SizedBox(height: 12),
                  Text('FLAC Compression Level (0-12): $_flacCompression'),
                  Slider(
                    value: _flacCompression.toDouble(),
                    min: 0,
                    max: 12,
                    divisions: 12,
                    onChanged: (v) => setState(() => _flacCompression = v.round()),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _flacBitDepth,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'FLAC Bit Depth'),
                    items: const [
                      DropdownMenuItem(value: 16, child: Text('16-bit PCM')),
                      DropdownMenuItem(value: 24, child: Text('24-bit PCM')),
                    ],
                    onChanged: (v) => setState(() => _flacBitDepth = v ?? 24),
                  ),
                ],
                if (_audioCodec == 2) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _wavSampleFormat,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'PCM Sample Format'),
                    items: const [
                      DropdownMenuItem(value: 'pcm_s16le', child: Text('16-bit Signed LE (pcm_s16le)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'pcm_s24le', child: Text('24-bit Signed LE (pcm_s24le)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'pcm_s32le', child: Text('32-bit Signed LE (pcm_s32le)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'pcm_f32le', child: Text('32-bit Float LE (pcm_f32le)', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _wavSampleFormat = v ?? 'pcm_s16le'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _customAudioArgsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Extra FFmpeg Audio Flags (optional)',
                    hintText: '-af volume=1.2 -c:a flac',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: btnBg,
            foregroundColor: btnFg,
          ),
          onPressed: _toggleCapture,
          icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
          label: Text(_isRecording ? 'STOP HARDWARE CAPTURE' : 'START HARDWARE CAPTURE'),
        ),
      ],
    );
  }
}

class EcosystemManagerView extends StatefulWidget {
  const EcosystemManagerView({super.key});

  @override
  State<EcosystemManagerView> createState() => _EcosystemManagerViewState();
}

class _EcosystemManagerViewState extends State<EcosystemManagerView> {
  final TextEditingController _pubKeyCtrl = TextEditingController(
    text: '0000000000000000000000000000000000000000000000000000000000000000',
  );
  final TextEditingController _manifestCtrl = TextEditingController(
    text: '''{
  "id": "demo-preset-module",
  "version": "1.0.0",
  "min_host_api": 1,
  "kind": "MediaPreset",
  "sha256_hex": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "signature_hex": "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "origin": {
    "Hybrid": {
      "info_hash": "a1b2c3d4",
      "bootstrap_peers": ["127.0.0.1:7070"],
      "fallback_url": "https://example.com/modules/demo-preset.bin"
    }
  },
  "dependencies": []
}''',
  );

  String _installStatus = 'Core Host Idle. Ready for P2P or HTTP package manifest.';

  Future<void> _executeHotUpdate() async {
    final storageDir = await _platformChannel.invokeMethod<String>('getStorageDir') ?? '/data/local/tmp';

    final storagePtr = storageDir.toNativeUtf8();
    final keyPtr = _pubKeyCtrl.text.trim().toNativeUtf8();
    final manifestPtr = _manifestCtrl.text.trim().toNativeUtf8();

    final code = CtToolsNativeBridge.installOrHotUpdatePackage(storagePtr, keyPtr, manifestPtr);

    calloc.free(storagePtr);
    calloc.free(keyPtr);
    calloc.free(manifestPtr);

    setState(() {
      if (code == 0) {
        _installStatus = 'Success (0): Artifact verified via Ed25519/SHA-256 and swapped into A/B slot.';
      } else {
        _installStatus = 'Verification or transport returned code $code (expected for unsigned/offline demo).';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'P2P & HTTP Hot-Update Installer',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(_installStatus, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                TextField(
                  controller: _pubKeyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Trusted Repository Ed25519 Public Key (Hex)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _manifestCtrl,
                  maxLines: 12,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Package / Hot-Update JSON Manifest',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _executeHotUpdate,
                  icon: const Icon(Icons.system_update_alt),
                  label: const Text('FETCH, VERIFY & HOT-SWAP A/B SLOT'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LogViewerTab extends StatefulWidget {
  final Color borderColor;
  const LogViewerTab({super.key, required this.borderColor});

  @override
  State<LogViewerTab> createState() => _LogViewerTabState();
}

class _LogViewerTabState extends State<LogViewerTab> {
  String _logText = 'Loading logs...';
  bool _loggingEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await _platformChannel.invokeMethod<bool>('isLoggingEnabled') ?? false;
    final text = await _platformChannel.invokeMethod<String>('readLogs') ?? 'No logs.';
    if (mounted) {
      setState(() {
        _loggingEnabled = enabled;
        _logText = text;
      });
    }
  }

  Future<void> _toggleLogging(bool value) async {
    await _platformChannel.invokeMethod('setLoggingEnabled', {'enabled': value});
    await _loadState();
  }

  Future<void> _clearLogs() async {
    await _platformChannel.invokeMethod('clearLogs');
    await _loadState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable File Logging (ct_tools.log)'),
            subtitle: const Text(
              'Disabled by default to prevent unnecessary disk writes',
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
            value: _loggingEnabled,
            onChanged: _toggleLogging,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _loadState,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _logText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logs copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _clearLogs,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF050505),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.borderColor, width: 1.2),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _logText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
