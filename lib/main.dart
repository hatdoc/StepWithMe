import 'dart:async';
import 'dart:developer' as developer; // Add this import

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/initial_page.dart';
import 'package:myapp/user_info_page.dart';
import 'package:riverpod/riverpod.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

final themeProvider = ChangeNotifierProvider<ThemeProvider>(
  (ref) => ThemeProvider(),
);

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
    try {
      await _audioPlayer.play(AssetSource('audio/$sound'));
    } on PlatformException catch (e) {
      developer.log(
        'Error playing audio: $sound',
        name: 'AudioService',
        level: 900,
        error: e,
      );
      // Optionally, show a user-friendly message
    } catch (e, s) {
      developer.log(
        'An unexpected error occurred while playing audio: $sound',
        name: 'AudioService',
        level: 1000,
        error: e,
        stackTrace: s,
      );
    }
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
  final service = BPMService(audioService, appState);
  ref.onDispose(() => service.stop());
  return service;
});

class BPMService {
  final AudioService _audioService;
  final AppState _appState;
  Timer? _timer;

  BPMService(this._audioService, this._appState);

  void start() {
    _timer?.cancel(); // Cancel any existing timer
    if (_appState.isPlaying) {
      _timer = Timer.periodic(Duration(milliseconds: 60000 ~/ _appState.bpm), (
        _,
      ) {
        _audioService.play(_appState.sound);
      });
    }
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
    final themeProviderState = ref.watch(themeProvider);
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
      themeMode: themeProviderState.themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const InitialPage(),
        '/home': (context) => const HomePage(),
        '/user-info': (context) => const UserInfoPage(),
      },
    );
  }
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final appState = ref.watch(stateServiceProvider);

    final stateService = ref.read(stateServiceProvider.notifier);

    final bpmService = ref.read(bpmServiceProvider);

    // Start/stop BPM service based on appState.isPlaying
    // Use ref.listen to handle side effects like starting/stopping the BPM service
    ref.listen<AppState>(stateServiceProvider, (previous, next) {
      if (next.isPlaying) {
        bpmService.start();
      } else {
        bpmService.stop();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'StepWithMe',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed('/user-info');
            },
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
        ],
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        'Beats Per Minute',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SleekCircularSlider(
                        min: 60,
                        max: 200,
                        initialValue: appState.bpm.toDouble(),
                        onChange: (value) {
                          stateService.setBpm(value.toInt());
                        },
                        innerWidget: (double value) {
                          return Center(
                            child: Text(
                              '${value.toInt()}',
                              style: GoogleFonts.poppins(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          );
                        },
                        appearance: CircularSliderAppearance(
                          customColors: CustomSliderColors(
                            trackColor: theme.colorScheme.secondary.withOpacity(
                              0.2,
                            ),
                            progressBarColor: theme.colorScheme.primary,
                            dotColor: theme.colorScheme.primary,
                          ),
                          customWidths: CustomSliderWidths(
                            trackWidth: 12,
                            progressBarWidth: 12,
                            handlerSize: 8,
                          ),
                          size: 250,
                          startAngle: 180,
                          angleRange: 360,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          stateService.setBpm(120);
                        },
                        child: const Text('Recommend Speed'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildSoundSelector(context, ref),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          stateService.togglePlay();
        },

        label: Text(
          appState.isPlaying ? 'Pause' : 'Play',

          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),

        icon: Icon(appState.isPlaying ? Icons.pause : Icons.play_arrow),

        backgroundColor: theme.colorScheme.primary,

        foregroundColor: theme.colorScheme.onPrimary,

        elevation: 8,
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSoundSelector(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final appState = ref.watch(stateServiceProvider);

    final stateService = ref.read(stateServiceProvider.notifier);

    final audioService = ref.read(audioServiceProvider);

    return Card(
      elevation: 8,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step Sound Effect',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: appState.sound,

                isExpanded: true,

                icon: Icon(
                  Icons.arrow_drop_down_circle,
                  color: theme.colorScheme.primary,
                ),

                items: [
                  _buildDropdownItem('Heel Strike (Default)', 'step1.mp3'),
                  _buildDropdownItem('Soft Sneaker', 'step2.mp3'),
                  _buildDropdownItem('Wood Block', 'step1.mp3'),
                  _buildDropdownItem('Mechanical Click', 'step2.mp3'),
                  _buildDropdownItem('Electronic Pulse', 'step1.mp3'),
                ],

                onChanged: (value) {
                  if (value != null) {
                    stateService.setSound(value);
                    // Preview the sound when selected
                    audioService.play(value);
                  }
                },

                style: GoogleFonts.poppins(
                  fontSize: 18,

                  color: theme.colorScheme.onSurface,
                ),

                dropdownColor: theme.cardColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(String text, String value) {
    return DropdownMenuItem(value: value, child: Text(text));
  }
}
