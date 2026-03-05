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
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

final audioServiceProvider = Provider((ref) => AudioService());

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> play(String soundKey) async {
    String soundFile;
    // Map the selection keys to the available audio files
    switch (soundKey) {
      case 'heel_strike':
        soundFile = 'step1.mp3';
        break;
      case 'soft_sneaker':
        soundFile = 'step2.mp3';
        break;
      case 'wood_block':
        soundFile = 'step1.mp3';
        break;
      case 'mechanical_click':
        soundFile = 'step2.mp3';
        break;
      case 'electronic_pulse':
        soundFile = 'step1.mp3';
        break;
      default:
        // For new files, the key is the filename itself
        soundFile = soundKey;
    }

    try {
      await _audioPlayer.play(AssetSource('audio/$soundFile'));
    } on PlatformException catch (e) {
      developer.log(
        'Error playing audio: $soundFile ($soundKey)',
        name: 'AudioService',
        level: 900,
        error: e,
      );
    } catch (e, s) {
      developer.log(
        'An unexpected error occurred while playing audio: $soundFile ($soundKey)',
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
  final String sound; // This now stores the unique sound key
  final double? height;
  final double? weight;
  final int? age;

  AppState({
    required this.bpm,
    required this.isPlaying,
    required this.sound,
    this.height,
    this.weight,
    this.age,
  });

  AppState copyWith({
    int? bpm,
    bool? isPlaying,
    String? sound,
    double? height,
    double? weight,
    int? age,
  }) {
    return AppState(
      bpm: bpm ?? this.bpm,
      isPlaying: isPlaying ?? this.isPlaying,
      sound: sound ?? this.sound,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      age: age ?? this.age,
    );
  }

  double? get bmi {
    if (height == null || weight == null || height == 0) return null;
    return weight! / ((height! / 100) * (height! / 100));
  }

  String get bmiCategory {
    final val = bmi;
    if (val == null) return 'Unknown';
    if (val < 18.5) return 'Underweight';
    if (val < 25) return 'Healthy';
    if (val < 30) return 'Overweight';
    return 'Obese';
  }
}

class StateService extends StateNotifier<AppState> {
  StateService() : super(AppState(bpm: 120, isPlaying: false, sound: 'heel_strike')) {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final hStr = prefs.getString('height');
    final wStr = prefs.getString('weight');
    final aStr = prefs.getString('age');

    state = state.copyWith(
      bpm: prefs.getInt('bpm') ?? 120,
      sound: prefs.getString('sound') ?? 'heel_strike',
      height: hStr != null ? double.tryParse(hStr) : null,
      weight: wStr != null ? double.tryParse(wStr) : null,
      age: aStr != null ? int.tryParse(aStr) : null,
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

  void setSound(String soundKey) {
    state = state.copyWith(sound: soundKey);
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

    ref.listen<AppState>(stateServiceProvider, (previous, next) {
      if (next.isPlaying) {
        bpmService.start();
      } else {
        bpmService.stop();
      }
    });

    final maxHR = appState.age != null ? 220 - appState.age! : 0;
    final fatBurnMin = (maxHR * 0.60).toInt();
    final fatBurnMax = (maxHR * 0.70).toInt();

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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            'BMI',
                            appState.bmi?.toStringAsFixed(1) ?? '--',
                            theme,
                          ),
                          _buildStatItem(
                            'Category',
                            appState.bmiCategory,
                            theme,
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Text(
                        'Target Fat Loss Heart Rate: $fatBurnMin - $fatBurnMax BPM',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                        'Steps Per Minute (Cadence)',
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${value.toInt()}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  'Steps/Min',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        appearance: CircularSliderAppearance(
                          customColors: CustomSliderColors(
                            trackColor: theme.colorScheme.secondary.withOpacity(0.2),
                            progressBarColor: theme.colorScheme.primary,
                            dotColor: theme.colorScheme.primary,
                          ),
                          customWidths: CustomSliderWidths(
                            trackWidth: 12,
                            progressBarWidth: 12,
                            handlerSize: 8,
                          ),
                          size: 200,
                          startAngle: 180,
                          angleRange: 360,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildModeButton(
                            'Light',
                            100,
                            stateService,
                            theme,
                            appState.bpm,
                          ),
                          _buildModeButton(
                            'Fat Burn',
                            120,
                            stateService,
                            theme,
                            appState.bpm,
                          ),
                          _buildModeButton(
                            'Jogging',
                            150,
                            stateService,
                            theme,
                            appState.bpm,
                          ),
                          _buildModeButton(
                            'Running',
                            170,
                            stateService,
                            theme,
                            appState.bpm,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSoundSelector(context, ref),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          stateService.togglePlay();
        },
        label: Text(
          appState.isPlaying ? 'Pause' : 'Play Steps',
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

  Widget _buildStatItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: theme.colorScheme.secondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton(
    String label,
    int value,
    StateService service,
    ThemeData theme,
    int currentBpm,
  ) {
    final isSelected = currentBpm == value;
    return ElevatedButton(
      onPressed: () => service.setBpm(value),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
        foregroundColor: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label),
    );
  }

  Widget _buildSoundSelector(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appState = ref.watch(stateServiceProvider);
    final stateService = ref.read(stateServiceProvider.notifier);
    final audioService = ref.read(audioServiceProvider);

    final soundOptions = [
      {'label': 'Heel Strike (Default)', 'value': 'heel_strike'},
      {'label': 'Soft Sneaker', 'value': 'soft_sneaker'},
      {'label': 'Shallow Water', 'value': 'Walk in Shallow Water Series.mp3'},
      {'label': 'Grass', 'value': 'Walk on Grass Series.mp3'},
      {'label': 'Muddy Gravel', 'value': 'Walk on Muddy Gravel Series.mp3'},
      {'label': 'Rocks', 'value': 'Walk on Rocks.mp3'},
      {'label': 'Snow', 'value': 'Walk on Snow Series.mp3'},
      {'label': 'Solid Metal', 'value': 'Walk on Solid Metal Series.mp3'},
      {'label': 'Tile', 'value': 'Walk on Tile Series.mp3'},
      {'label': 'Forest Walk', 'value': 'Walking In Forest.mp3'},
      {'label': 'Gravel Path', 'value': 'Walking On Gravel Path.mp3'},
      {'label': 'Wood Floor', 'value': 'Walking Wood Floor House.mp3'},
      {
        'label': 'Water Walk (Sweetener)',
        'value': 'Water Walk Series Sweetener .mp3',
      },
    ];

    final currentSound = soundOptions.any((opt) => opt['value'] == appState.sound)
        ? appState.sound
        : 'heel_strike';

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
                value: currentSound,
                isExpanded: true,
                icon: Icon(
                  Icons.arrow_drop_down_circle,
                  color: theme.colorScheme.primary,
                ),
                items: soundOptions.map((opt) {
                  return _buildDropdownItem(opt['label']!, opt['value']!);
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    stateService.setSound(value);
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
