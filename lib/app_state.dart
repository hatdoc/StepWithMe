import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    bool setHeight = false,
    bool setWeight = false,
    bool setAge = false,
  }) {
    return AppState(
      bpm: bpm ?? this.bpm,
      isPlaying: isPlaying ?? this.isPlaying,
      sound: sound ?? this.sound,
      height: setHeight ? height : (height ?? this.height),
      weight: setWeight ? weight : (weight ?? this.weight),
      age: setAge ? age : (age ?? this.age),
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
  
  double get _ageImpact => ((age ?? 30) - 20).clamp(0, 80) * 0.3;

  double get _heightImpact {
    if (height == null || height == 0) return 1.0;
    return 170 / height!;
  }

  double get _bmiImpact => ((bmi ?? 22) - 22) * 0.8;

  double get _baseCadence => 105 - _ageImpact - _bmiImpact;

  int get recommendedLight {
    return (_baseCadence * 0.85 * _heightImpact).round().clamp(60, 200);
  }

  int get recommendedFatBurn {
    return (_baseCadence * _heightImpact).round().clamp(60, 200);
  }

  int get recommendedJogging {
    return ((_baseCadence + 25) * _heightImpact).round().clamp(60, 200);
  }

  int get recommendedRunning {
    return ((_baseCadence + 50) * _heightImpact).round().clamp(60, 200);
  }

  double get estimatedMETs {
    double val = 0.04 * bpm - 1.0;
    return val.clamp(1.0, 15.0);
  }

  double get caloriesPerMinute {
    if (weight == null) return 0;
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

    final newState = AppState(
      bpm: prefs.getInt('bpm') ?? 120,
      sound: prefs.getString('sound') ?? 'heel_strike',
      height: hStr != null ? double.tryParse(hStr.replaceAll(',', '.')) : null,
      weight: wStr != null ? double.tryParse(wStr.replaceAll(',', '.')) : null,
      age: aStr != null ? int.tryParse(aStr) : null,
      isPlaying: state.isPlaying,
    );
    
    if (_isLoading) {
      state = newState;
      _isLoading = false;
    }
  }

  Future<bool> updateUserInfo({required String height, required String weight, required String age}) async {
    _isLoading = false;
    final prefs = await SharedPreferences.getInstance();
    
    // Aggressive cleaning: keep only digits and one decimal point
    String cleanH = height.replaceAll(',', '.').trim();
    String cleanW = weight.replaceAll(',', '.').trim();
    String cleanA = age.trim();

    final h = double.tryParse(cleanH);
    final w = double.tryParse(cleanW);
    final a = int.tryParse(cleanA);

    if (h != null) await prefs.setString('height', h.toString());
    if (w != null) await prefs.setString('weight', w.toString());
    if (a != null) await prefs.setString('age', a.toString());
    
    state = AppState(
      bpm: state.bpm,
      isPlaying: state.isPlaying,
      sound: state.sound,
      height: h ?? state.height,
      weight: w ?? state.weight,
      age: a ?? state.age,
    );
    
    return h != null && w != null && a != null;
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

final stateServiceProvider = StateNotifierProvider<StateService, AppState>(
  (ref) => StateService(),
);
