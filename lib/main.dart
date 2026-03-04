import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

final themeProvider = ChangeNotifierProvider((ref) => ThemeProvider());

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
  }
}

final audioServiceProvider = Provider((ref) => AudioService());

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> play(String sound) async {
    await _audioPlayer.play(AssetSource('audio/$sound'));
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }
}

final stateServiceProvider = StateNotifierProvider<StateService, AppState>(
  (ref) => StateService(),
);

class AppState {
  final int bpm;
  final bool isPlaying;
  final String sound;

  AppState({required this.bpm, required this.isPlaying, required this.sound});

  AppState copyWith({int? bpm, bool? isPlaying, String? sound}) {
    return AppState(
      bpm: bpm ?? this.bpm,
      isPlaying: isPlaying ?? this.isPlaying,
      sound: sound ?? this.sound,
    );
  }
}

class StateService extends StateNotifier<AppState> {
  StateService()
    : super(AppState(bpm: 120, isPlaying: false, sound: 'step1.mp3')) {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      bpm: prefs.getInt('bpm') ?? 120,
      sound: prefs.getString('sound') ?? 'step1.mp3',
    );
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bpm', state.bpm);
    await prefs.setString('sound', state.sound);
  }

  void setBpm(int bpm) {
    state = state.copyWith(bpm: bpm);
    _saveState();
  }

  void togglePlay() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void setSound(String sound) {
    state = state.copyWith(sound: sound);
    _saveState();
  }
}

final bpmServiceProvider = Provider((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final appState = ref.watch(stateServiceProvider);
  return BPMService(audioService, appState);
});

class BPMService {
  final AudioService _audioService;
  final AppState _appState;
  Timer? _timer;

  BPMService(this._audioService, this._appState);

  void start() {
    _timer = Timer.periodic(Duration(milliseconds: 60000 ~/ _appState.bpm), (
      timer,
    ) {
      _audioService.play(_appState.sound);
    });
  }

  void stop() {
    _timer?.cancel();
    _audioService.stop();
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = ref.watch<ThemeProvider>(
      ChangeNotifierProvider((ref) => ThemeProvider()),
    );
    return MaterialApp(
      title: 'StepWithMe',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      themeMode: themeProvider.themeMode,
      home: const HomePage(),
    );
  }
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(stateServiceProvider);
    final stateService = ref.read(stateServiceProvider.notifier);
    final bpmService = ref.read(bpmServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('StepWithMe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => ref.read(themeProvider).toggleTheme(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${appState.bpm}',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 20),
            Slider(
              value: appState.bpm.toDouble(),
              min: 60,
              max: 200,
              onChanged: (value) => stateService.setBpm(value.toInt()),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => stateService.setSound('step1.mp3'),
                  child: const Text('Sound 1'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () => stateService.setSound('step2.mp3'),
                  child: const Text('Sound 2'),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          stateService.togglePlay();
          if (appState.isPlaying) {
            bpmService.start();
          } else {
            bpmService.stop();
          }
        },
        child: Icon(appState.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}
