import 'dart:async';

import 'package:flutter/material.dart';

void main() => runApp(const TorchToolApp());

class TorchToolApp extends StatelessWidget {
  const TorchToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Torch Tool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const TorchHome(),
    );
  }
}

/// In-memory torch state: power, brightness preset, and the SOS strobe
/// pattern timer. No platform channels — the beam is simulated on screen.
class TorchController extends ChangeNotifier {
  static const List<double> _levels = <double>[0.25, 0.5, 0.75, 1.0];
  static const List<String> _levelNames = <String>['Low', 'Med', 'High', 'Max'];

  /// Morse S-O-S; positive = lit milliseconds, negative = dark milliseconds.
  static const List<int> _sosPatternMs = <int>[
    200, -200, 200, -200, 200, -600, // S
    600, -200, 600, -200, 600, -600, // O
    200, -200, 200, -200, 200, -1000, // S + repeat gap
  ];

  Timer? _timer;
  int _presetIndex = 2;
  int _sosStep = 0;
  bool _isOn = false;
  bool _sosEnabled = false;
  bool _strobeLit = false;

  int get presetIndex => _presetIndex;
  String get presetName => _levelNames[_presetIndex];
  double get brightness => _levels[_presetIndex];
  bool get isOn => _isOn;
  bool get sosEnabled => _sosEnabled;
  bool get isLit => _isOn && (!_sosEnabled || _strobeLit);

  void setPreset(int index) {
    _presetIndex = index.clamp(0, _levels.length - 1);
    notifyListeners();
  }

  void togglePower() {
    _isOn = !_isOn;
    if (!_isOn) _stopSos();
    notifyListeners();
  }

  void toggleSos() {
    if (_sosEnabled) {
      _stopSos();
      notifyListeners();
      return;
    }
    _isOn = true;
    _sosEnabled = true;
    _sosStep = 0;
    _runSosStep();
  }

  void _stopSos() {
    _timer?.cancel();
    _timer = null;
    _sosEnabled = false;
    _strobeLit = false;
  }

  void _runSosStep() {
    final int ms = _sosPatternMs[_sosStep % _sosPatternMs.length];
    _strobeLit = ms > 0;
    notifyListeners();
    _timer = Timer(Duration(milliseconds: ms.abs()), () {
      _sosStep += 1;
      _runSosStep();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class TorchHome extends StatefulWidget {
  const TorchHome({super.key});

  @override
  State<TorchHome> createState() => _TorchHomeState();
}

class _TorchHomeState extends State<TorchHome> {
  final TorchController _controller = TorchController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Torch Tool')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _TorchLens(controller: _controller),
                  const SizedBox(height: 24),
                  _StatusLine(controller: _controller),
                  const SizedBox(height: 24),
                  _PresetPicker(controller: _controller),
                  const SizedBox(height: 24),
                  _Controls(controller: _controller),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TorchLens extends StatelessWidget {
  final TorchController controller;

  const _TorchLens({required this.controller});

  @override
  Widget build(BuildContext context) {
    final bool lit = controller.isLit;
    final double level = controller.brightness;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color beam = lit
        ? Color.lerp(Colors.amber, Colors.amber.shade200, 1 - level)!
        : scheme.surfaceContainerHighest;
    return Container(
      key: const Key('torch-lens'),
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: beam,
        boxShadow: lit
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.35 + 0.4 * level),
                  blurRadius: 60 + 60 * level,
                  spreadRadius: 8 * level,
                ),
              ]
            : null,
      ),
      child: Icon(
        lit ? Icons.flashlight_on : Icons.flashlight_off,
        size: 84,
        color: lit ? Colors.black87 : scheme.outline,
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final TorchController controller;

  const _StatusLine({required this.controller});

  @override
  Widget build(BuildContext context) {
    final String status;
    if (controller.sosEnabled) {
      status = 'SOS strobe · · · – – – · · ·';
    } else if (controller.isOn) {
      final int percent = (controller.brightness * 100).round();
      status = 'Steady beam — ${controller.presetName} ($percent%)';
    } else {
      status = 'Torch is off';
    }
    return Text(status, key: const Key('status-line'),
        style: Theme.of(context).textTheme.titleMedium);
  }
}

class _PresetPicker extends StatelessWidget {
  final TorchController controller;

  const _PresetPicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: <ButtonSegment<int>>[
        for (int i = 0; i < TorchController._levels.length; i++)
          ButtonSegment<int>(
            value: i,
            label: Text(TorchController._levelNames[i]),
          ),
      ],
      selected: <int>{controller.presetIndex},
      onSelectionChanged: (Set<int> selection) =>
          controller.setPreset(selection.first),
    );
  }
}

class _Controls extends StatelessWidget {
  final TorchController controller;

  const _Controls({required this.controller});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        FilledButton.icon(
          key: const Key('power-button'),
          onPressed: controller.togglePower,
          icon: Icon(
            controller.isOn ? Icons.flashlight_on : Icons.power_settings_new,
          ),
          label: Text(controller.isOn ? 'Turn off' : 'Turn on'),
        ),
        const SizedBox(width: 16),
        FilledButton.tonal(
          key: const Key('sos-button'),
          onPressed: controller.toggleSos,
          style: FilledButton.styleFrom(
            backgroundColor:
                controller.sosEnabled ? scheme.errorContainer : null,
            foregroundColor:
                controller.sosEnabled ? scheme.onErrorContainer : null,
          ),
          child: Text(controller.sosEnabled ? 'Stop SOS' : 'SOS strobe'),
        ),
      ],
    );
  }
}
