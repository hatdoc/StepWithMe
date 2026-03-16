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
    _audioPlayer.onLog.listen((msg) => print('AudioService [PlayerLog]: $msg'));
    _audioPlayer.onPlayerStateChanged.listen((state) => print('AudioService [State]: $state'));
  }

  Future<void> _init() async {
    if (_isInitialized) return;

    try {
      print('AudioService: Starting initialization...');
      
      // Global configuration for all players
      await AudioPlayer.global.setAudioContext(AudioContext(
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

      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);

      // Mapping of shorthand keys to high-quality audio filenames
      final Map<String, String> terrainMap = {
        'grass': 'walk_on_grass.mp3',
        'forest': 'walk_on_forest.mp3',
        'gravel': 'walk_on_gravel.mp3',
        'rocks': 'walk_on_rocks.mp3',
        'snow': 'walk_on_snow.mp3',
        'tile': 'walk_on_tile.mp3',
        'wood': 'walking_wood_floor.mp3',
        'metal': 'walk_on_solid_metal.mp3',
        'water': 'walk_in_shallow_water.mp3',
        'muddy_gravel': 'walk_on_muddy_gravel.mp3',
        'water_sweetener': 'water_walk_sweetener.mp3',
      };

      for (var entry in terrainMap.entries) {
        final source = AssetSource('audio/${entry.value}');
        _sourceCache[entry.key] = source;
        _sourceCache[entry.value] = source; // Cache by filename too for backward compatibility
      }

      print('AudioService: Initialization complete. Terrain keys: ${_sourceCache.keys.join(', ')}');
      _isInitialized = true;
    } catch (e) {
      print('AudioService ERROR: Failed to initialize: $e');
    }
  }

  Future<void> play(String soundId) async {
    if (!_isInitialized) {
      print('AudioService: Play called before init, waiting...');
      await _initFuture;
    }

    String finalKey = soundId;
    // Map any legacy names/keys to standardized ones
    if (soundId == 'heel_strike') finalKey = 'wood';
    if (soundId == 'soft_sneaker') finalKey = 'forest';
    if (soundId == 'walk_on_rock.mp3') finalKey = 'rocks';

    try {
      final source = _sourceCache[finalKey] ?? AssetSource('audio/$finalKey');
      print('AudioService: Playing sound key -> $finalKey');
      
      // Immediate stop/play for rhythm
      await _audioPlayer.stop();
      await _audioPlayer.play(source, volume: 1.0);
    } catch (e) {
      print('AudioService ERROR: Playback failed for $finalKey: $e');
    }
  }

  Future<void> stop() async {
    try {
      developer.log('Stopping playback', name: 'AudioService');
      await _audioPlayer.stop();
    } catch (e) {
      developer.log('Error stopping audio: $e', name: 'AudioService');
    }
  }
}

final bpmServiceProvider = Provider((ref) {
  developer.log('Initializing BPMServiceProvider', name: 'BPMService');
  final audioService = ref.read(audioServiceProvider);
  final service = BPMService(audioService, ref);

  // Listen for play/pause toggles
  ref.listen<bool>(stateServiceProvider.select((s) => s.isPlaying),
      (prev, next) {
    developer.log('isPlaying changed: $prev -> $next', name: 'BPMService');
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
      developer.log('BPM changed while playing: $next', name: 'BPMService');
      service.restart();
    }
  });

  // Listen for sound changes while playing
  ref.listen<String>(stateServiceProvider.select((s) => s.sound), (prev, next) {
    final state = ref.read(stateServiceProvider);
    if (state.isPlaying) {
      developer.log('Sound changed while playing: $next', name: 'BPMService');
      service.restart(immediate: true);
    }
  });

  ref.onDispose(() {
    developer.log('BPMServiceProvider disposed', name: 'BPMService');
    service.stop();
  });
  return service;
});

class BPMService {
  final AudioService _audioService;
  final Ref _ref;
  Timer? _timer;

  BPMService(this._audioService, this._ref);

  void start() {
    developer.log('Starting BPMService...', name: 'BPMService');
    _timer?.cancel();
    final state = _ref.read(stateServiceProvider);
    developer.log('Current State - BPM: ${state.bpm}, Sound: ${state.sound}', name: 'BPMService');
    
    if (state.bpm <= 0) {
      developer.log('BPM is 0 or less, aborting start', name: 'BPMService');
      return;
    }

    // Play the first step immediately
    _audioService.play(state.sound);
    _scheduleNextTick();
  }

  void restart({bool immediate = false}) {
    developer.log('Restarting BPMService (immediate: $immediate)', name: 'BPMService');
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

    final intervalMs = 60000 ~/ state.bpm;
    developer.log('Scheduling ticks every ${intervalMs}ms', name: 'BPMService');
    
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      final currentState = _ref.read(stateServiceProvider);
      if (currentState.isPlaying) {
        _audioService.play(currentState.sound);
      } else {
        developer.log('Timer ticked but isPlaying is false, canceling', name: 'BPMService');
        _timer?.cancel();
      }
    });
  }

  void stop() {
    developer.log('Stopping BPMService', name: 'BPMService');
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
    // Watch the BPM service to ensure it's initialized and listening
    ref.watch(bpmServiceProvider);
    
    final theme = Theme.of(context);
    final appState = ref.watch(stateServiceProvider);
    final stateService = ref.read(stateServiceProvider.notifier);

    developer.log('HomePage Build - isPlaying: ${appState.isPlaying}', name: 'UI');

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

    final soundOptions = [
      {'label': 'Grass 🌿', 'value': 'grass'},
      {'label': 'Forest 🌲', 'value': 'forest'},
      {'label': 'Gravel Path 🪨', 'value': 'gravel'},
      {'label': 'Rock 🪨', 'value': 'rocks'},
      {'label': 'Snow ❄️', 'value': 'snow'},
      {'label': 'Tile 🧱', 'value': 'tile'},
      {'label': 'Wood Floor 🪵', 'value': 'wood'},
      {'label': 'Solid Metal ⚙️', 'value': 'metal'},
      {'label': 'Shallow Water 💧', 'value': 'water'},
      {'label': 'Muddy Gravel 🪨', 'value': 'muddy_gravel'},
      {'label': 'Water Sweetener 🌊', 'value': 'water_sweetener'},
    ];

    // Map any old filename-based state to the new keys
    String currentSound = appState.sound;
    if (currentSound.endsWith('.mp3')) {
      if (currentSound == 'walk_on_grass.mp3') {
        currentSound = 'grass';
      } else if (currentSound == 'walk_on_forest.mp3') {
        currentSound = 'forest';
      } else if (currentSound == 'walk_on_gravel.mp3') {
        currentSound = 'gravel';
      } else if (currentSound == 'walk_on_rocks.mp3') {
        currentSound = 'rocks';
      } else if (currentSound == 'walk_on_snow.mp3') {
        currentSound = 'snow';
      } else if (currentSound == 'walk_on_tile.mp3') {
        currentSound = 'tile';
      } else if (currentSound == 'walking_wood_floor.mp3') {
        currentSound = 'wood';
      } else if (currentSound == 'walk_on_solid_metal.mp3') {
        currentSound = 'metal';
      } else if (currentSound == 'walk_in_shallow_water.mp3') {
        currentSound = 'water';
      } else if (currentSound == 'walk_on_muddy_gravel.mp3') {
        currentSound = 'muddy_gravel';
      } else if (currentSound == 'water_walk_sweetener.mp3') {
        currentSound = 'water_sweetener';
      }
    }

    // Final safety check
    if (!soundOptions.any((opt) => opt['value'] == currentSound)) {
      currentSound = 'grass';
    }

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
