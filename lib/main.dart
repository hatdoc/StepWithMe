import 'dart:async';
import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/initial_page.dart';
import 'package:myapp/user_info_page.dart';
import 'package:myapp/app_state.dart';
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
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

final audioServiceProvider = Provider((ref) => AudioService());

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, Source> _sourceCache = {};
  bool _isInitialized = false;
  Future<void>? _initFuture;

  AudioService() {
    _initFuture = _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;

    try {
      // Use low latency mode for metronome-like behavior
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      
      // Set audio context for iOS/Android
      await _audioPlayer.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.media,
          contentType: AndroidContentType.music,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
      ));

      // Pre-cache sources
      final sounds = [
        'walk_on_grass.mp3',
        'walking_in_forest.mp3',
        'walking_on_gravel_path.mp3',
        'walk_on_rocks.mp3',
        'walk_on_snow.mp3',
        'walk_on_tile.mp3',
        'walking_wood_floor.mp3',
        'walk_on_solid_metal.mp3',
        'walk_in_shallow_water.mp3',
        'walk_on_muddy_gravel.mp3',
        'water_walk_sweetener.mp3',
      ];

      for (var s in sounds) {
        _sourceCache[s] = AssetSource('audio/$s');
      }

      developer.log('AudioService initialized successfully', name: 'AudioService');
      _isInitialized = true;
    } catch (e) {
      developer.log('Failed to initialize AudioService: $e', name: 'AudioService', level: 1000);
    }
  }

  Future<void> play(String soundFile) async {
    if (!_isInitialized) await _initFuture;

    String assetName = soundFile;
    // Handle legacy mappings if any
    if (soundFile == 'heel_strike') assetName = 'walking_wood_floor.mp3';
    if (soundFile == 'soft_sneaker') assetName = 'walking_in_forest.mp3';
    if (soundFile == 'walk_on_rock.mp3') assetName = 'walk_on_rocks.mp3';

    try {
      final source = _sourceCache[assetName] ?? AssetSource('audio/$assetName');
      
      // For rhythmic precision, we stop and then play
      // This ensures the sound starts from the beginning every time
      await _audioPlayer.stop();
      await _audioPlayer.play(source);
      
      developer.log('Playing sound: $assetName', name: 'AudioService');
    } catch (e) {
      developer.log('Audio playback error for $assetName: $e',
          name: 'AudioService', level: 1000);
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      developer.log('Error stopping audio: $e', name: 'AudioService');
    }
  }
}

final bpmServiceProvider = Provider((ref) {
  final audioService = ref.read(audioServiceProvider);
  final service = BPMService(audioService, ref);

  // Listen for play/pause toggles
  ref.listen<bool>(stateServiceProvider.select((s) => s.isPlaying),
      (prev, next) {
    if (next) {
      service.start();
    } else {
      service.stop();
    }
  });

  // Listen for BPM changes while playing
  ref.listen<int>(stateServiceProvider.select((s) => s.bpm), (prev, next) {
    final state = ref.read(stateServiceProvider);
    if (state.isPlaying) {
      service.restart();
    }
  });

  // Listen for sound changes while playing
  ref.listen<String>(stateServiceProvider.select((s) => s.sound), (prev, next) {
    final state = ref.read(stateServiceProvider);
    if (state.isPlaying) {
      service.restart(immediate: true); // Immediate feedback on sound change
    }
  });

  ref.onDispose(() => service.stop());
  return service;
});

class BPMService {
  final AudioService _audioService;
  final Ref _ref;
  Timer? _timer;

  BPMService(this._audioService, this._ref);

  void start() {
    _timer?.cancel();
    final state = _ref.read(stateServiceProvider);
    if (state.bpm <= 0) return;

    // Play the first step immediately
    _audioService.play(state.sound);

    _scheduleNextTick();
  }

  void restart({bool immediate = false}) {
    _timer?.cancel();
    final state = _ref.read(stateServiceProvider);
    if (!state.isPlaying) return;

    if (immediate) {
      _audioService.play(state.sound);
    }
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    final state = _ref.read(stateServiceProvider);
    if (state.bpm <= 0 || !state.isPlaying) return;

    final interval = Duration(milliseconds: 60000 ~/ state.bpm);
    _timer = Timer.periodic(interval, (_) {
      final currentState = _ref.read(stateServiceProvider);
      if (currentState.isPlaying) {
        _audioService.play(currentState.sound);
      } else {
        _timer?.cancel();
      }
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
    final themeProviderState = ref.watch(themeProvider);
    return MaterialApp(
      title: 'StepWithMe',
      debugShowCheckedModeBanner: false,
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
    final audioService = ref.read(audioServiceProvider);

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
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('BMI',
                              appState.bmi?.toStringAsFixed(1) ?? '--', theme),
                          _buildStatItem(
                              'Category', appState.bmiCategory, theme),
                          _buildStatItem(
                              'Burn/Hr',
                              '${(appState.caloriesPerMinute * 60).toInt()} kcal',
                              theme),
                        ],
                      ),
                      const Divider(height: 32),
                      Text(
                        'Target Fat Loss HR: $fatBurnMin-$fatBurnMax BPM',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
                        'Target Stride Cadence',
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
                            trackColor: theme.colorScheme.secondary
                                .withValues(alpha: 0.2),
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
                      Text(
                        'Scientific Targets for Your Profile:',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildModeButton('Light', appState.recommendedLight,
                              stateService, theme, appState.bpm),
                          _buildModeButton(
                              'Fat Burn',
                              appState.recommendedFatBurn,
                              stateService,
                              theme,
                              appState.bpm),
                          _buildModeButton(
                              'Jogging',
                              appState.recommendedJogging,
                              stateService,
                              theme,
                              appState.bpm),
                          _buildModeButton(
                              'Running',
                              appState.recommendedRunning,
                              stateService,
                              theme,
                              appState.bpm),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSoundSelector(context, ref),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: () {
              stateService.togglePlay();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: Icon(
              appState.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              size: 28,
            ),
            label: Text(
              appState.isPlaying ? 'PAUSE STEPS' : 'PLAY STEPS',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.secondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurfaceVariant,
        elevation: isSelected ? 6 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text('$value spm', style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSoundSelector(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appState = ref.watch(stateServiceProvider);
    final stateService = ref.read(stateServiceProvider.notifier);
    final audioService = ref.read(audioServiceProvider);

    final soundOptions = [
      {'label': 'Grass 🌿', 'value': 'walk_on_grass.mp3'},
      {'label': 'Forest 🌲', 'value': 'walking_in_forest.mp3'},
      {'label': 'Gravel Path 🪨', 'value': 'walking_on_gravel_path.mp3'},
      {'label': 'Rock 🪨', 'value': 'walk_on_rocks.mp3'},
      {'label': 'Snow ❄️', 'value': 'walk_on_snow.mp3'},
      {'label': 'Tile 🧱', 'value': 'walk_on_tile.mp3'},
      {'label': 'Wood Floor 🪵', 'value': 'walking_wood_floor.mp3'},
      {'label': 'Solid Metal ⚙️', 'value': 'walk_on_solid_metal.mp3'},
      {'label': 'Shallow Water 💧', 'value': 'walk_in_shallow_water.mp3'},
      {'label': 'Muddy Gravel 🪨', 'value': 'walk_on_muddy_gravel.mp3'},
      {'label': 'Water Sweetener 🌊', 'value': 'water_walk_sweetener.mp3'},
    ];

    // Ensure current sound is valid or default to grass
    final currentSound =
        soundOptions.any((opt) => opt['value'] == appState.sound)
            ? appState.sound
            : 'walk_on_grass.mp3';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.terrain, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Choose Footstep Sound',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currentSound,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down,
                      color: theme.colorScheme.primary),
                  items: soundOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt['value'],
                      child: Text(
                        opt['label']!,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      stateService.setSound(value);
                    }
                  },
                  dropdownColor: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
