import 'dart:async';
import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/initial_page.dart';
import 'package:myapp/user_info_page.dart';
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
  bool _isInitialized = false;

  AudioService() {
    _init();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    }
    _isInitialized = true;
  }

  Future<void> play(String soundKey) async {
    if (!_isInitialized) await _init();

    String soundFile;
    switch (soundKey) {
      case 'heel_strike':
        soundFile = 'walking_wood_floor.mp3';
        break;
      case 'soft_sneaker':
        soundFile = 'walking_in_forest.mp3';
        break;
      default:
        soundFile = soundKey;
    }

    try {
      await _audioPlayer.stop();
      // On web, AssetSource should be just the filename inside assets/audio/ registered in pubspec
      await _audioPlayer.play(AssetSource('audio/$soundFile'), volume: 1.0);
    } catch (e) {
      developer.log('Playback error for $soundFile: $e', name: 'AudioService', level: 1000);
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

  // --- REFINED DYNAMIC CADENCE LOGIC (Based on CADENCE-Adults Study) ---
  
  // Baseline: 100 steps/min is the floor for moderate intensity (3 METs).
  // Vigorous intensity (6 METs) starts at ~130 steps/min.
  
  // 1. Age Factor: Max heart rate drops with age. 
  // Older people reach target zones at slightly lower cadences.
  // Base moderate cadence drops by ~0.3 per year past 20.
  double get _ageImpact => ((age ?? 30) - 20).clamp(0, 80) * 0.3;

  // 2. Height (Stride) Factor: Taller people have longer strides.
  // To maintain the same SPEED (m/min) as a 170cm person, 
  // they need fewer steps/min.
  // Formula: Cadence2 = Cadence1 * (Height1 / Height2)
  // We use 170cm as baseline.
  double get _heightImpact {
    if (height == null || height == 0) return 1.0;
    return 170 / height!;
  }

  // 3. BMI (Mass) Factor: Heavier people burn more calories at lower cadences.
  // To stay in the "Fat Burn" (Moderate) zone, they need slightly lower cadence
  // than lean people to avoid crossing into vigorous heart rate zones.
  // Every BMI point above 22 reduces target cadence by ~0.8 spm.
  double get _bmiImpact => ((bmi ?? 22) - 22) * 0.8;

  // Base for Fat Burn (Moderate Intensity) is 105 for a 20yo at 170cm.
  double get _baseCadence => 105 - _ageImpact - _bmiImpact;

  int get recommendedLight {
    return (_baseCadence * 0.85 * _heightImpact).round().clamp(60, 200);
  }

  int get recommendedFatBurn {
    return (_baseCadence * _heightImpact).round().clamp(60, 200);
  }

  int get recommendedJogging {
    // Jogging is the transition to vigorous (~125-135 spm)
    return ((_baseCadence + 25) * _heightImpact).round().clamp(60, 200);
  }

  int get recommendedRunning {
    // Running is vigorous intensity (6+ METs)
    return ((_baseCadence + 50) * _heightImpact).round().clamp(60, 200);
  }

  double get estimatedMETs {
    // Refined MET estimation based on cadence
    // METs ≈ 0.04 * cadence - 1.0 (Approximate linear fit from CADENCE-Adults)
    double val = 0.04 * bpm - 1.0;
    return val.clamp(1.0, 15.0);
  }

  double get caloriesPerMinute {
    if (weight == null) return 0;
    // Standard Metabolic Equation
    return (estimatedMETs * 3.5 * weight!) / 200;
  }
}

class StateService extends StateNotifier<AppState> {
  bool _isLoading = true;

  StateService() : super(AppState(bpm: 120, isPlaying: false, sound: 'heel_strike')) {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final hStr = prefs.getString('height');
    final wStr = prefs.getString('weight');
    final aStr = prefs.getString('age');

    final newState = state.copyWith(
      bpm: prefs.getInt('bpm') ?? 120,
      sound: prefs.getString('sound') ?? 'heel_strike',
      height: hStr != null ? double.tryParse(hStr.replaceAll(',', '')) : null,
      weight: wStr != null ? double.tryParse(wStr.replaceAll(',', '')) : null,
      age: aStr != null ? int.tryParse(aStr.replaceAll(',', '')) : null,
    );
    
    // Only apply if we are still in the loading phase to avoid overwriting 
    // updates that happened during the async load.
    if (_isLoading) {
      state = newState;
      _isLoading = false;
    }
  }

  Future<void> updateUserInfo({required String height, required String weight, required String age}) async {
    _isLoading = false; // Stop any pending load from overwriting this
    final prefs = await SharedPreferences.getInstance();
    
    // Clean inputs
    final cleanHeight = height.replaceAll(',', '').trim();
    final cleanWeight = weight.replaceAll(',', '').trim();
    final cleanAge = age.replaceAll(',', '').trim();

    await prefs.setString('height', cleanHeight);
    await prefs.setString('weight', cleanWeight);
    await prefs.setString('age', cleanAge);
    
    state = state.copyWith(
      height: double.tryParse(cleanHeight),
      weight: double.tryParse(cleanWeight),
      age: int.tryParse(cleanAge),
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
    _timer?.cancel();
    if (_appState.isPlaying) {
      _audioService.play(_appState.sound);
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
    final bpmService = ref.read(bpmServiceProvider);
    final audioService = ref.read(audioServiceProvider);

    ref.listen<bool>(stateServiceProvider.select((s) => s.isPlaying), (prev, next) {
      if (next) {
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
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('BMI', appState.bmi?.toStringAsFixed(1) ?? '--', theme),
                          _buildStatItem('Category', appState.bmiCategory, theme),
                          _buildStatItem('Burn/Hr', '${(appState.caloriesPerMinute * 60).toInt()} kcal', theme),
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
                          _buildModeButton('Light', appState.recommendedLight, stateService, theme, appState.bpm),
                          _buildModeButton('Fat Burn', appState.recommendedFatBurn, stateService, theme, appState.bpm),
                          _buildModeButton('Jogging', appState.recommendedJogging, stateService, theme, appState.bpm),
                          _buildModeButton('Running', appState.recommendedRunning, stateService, theme, appState.bpm),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (!appState.isPlaying) {
            await audioService.play(appState.sound);
          }
          stateService.togglePlay();
        },
        label: Text(
          appState.isPlaying ? 'PAUSE' : 'PLAY STEPS',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2),
        ),
        icon: Icon(appState.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 12,
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
        backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
        elevation: isSelected ? 6 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
      {'label': 'Heel Strike (Default)', 'value': 'heel_strike'},
      {'label': 'Soft Sneaker', 'value': 'soft_sneaker'},
      {'label': 'Shallow Water', 'value': 'walk_in_shallow_water.mp3'},
      {'label': 'Grass', 'value': 'walk_on_grass.mp3'},
      {'label': 'Muddy Gravel', 'value': 'walk_on_muddy_gravel.mp3'},
      {'label': 'Rocks', 'value': 'walk_on_rocks.mp3'},
      {'label': 'Snow', 'value': 'walk_on_snow.mp3'},
      {'label': 'Solid Metal', 'value': 'walk_on_solid_metal.mp3'},
      {'label': 'Tile', 'value': 'walk_on_tile.mp3'},
      {'label': 'Forest Walk', 'value': 'walking_in_forest.mp3'},
      {'label': 'Gravel Path', 'value': 'walking_on_gravel_path.mp3'},
      {'label': 'Wood Floor', 'value': 'walking_wood_floor.mp3'},
      {'label': 'Water Walk (Sweetener)', 'value': 'water_walk_sweetener.mp3'},
    ];

    final currentSound = soundOptions.any((opt) => opt['value'] == appState.sound)
        ? appState.sound
        : 'heel_strike';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Environment Sound',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 4),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentSound,
                isExpanded: true,
                icon: Icon(Icons.tune, color: theme.colorScheme.primary),
                items: soundOptions.map((opt) {
                  return _buildDropdownItem(opt['label']!, opt['value']!);
                }).toList(),
                onChanged: (value) async {
                  if (value != null) {
                    stateService.setSound(value);
                    await audioService.play(value);
                  }
                },
                style: GoogleFonts.poppins(fontSize: 16, color: theme.colorScheme.onSurface),
                dropdownColor: theme.colorScheme.surface,
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
