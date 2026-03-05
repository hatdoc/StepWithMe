import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/main.dart';

class UserInfoPage extends ConsumerStatefulWidget {
  const UserInfoPage({super.key});

  @override
  ConsumerState<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends ConsumerState<UserInfoPage> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load existing data into controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(stateServiceProvider);
      if (state.height != null) _heightController.text = state.height!.toString();
      if (state.weight != null) _weightController.text = state.weight!.toString();
      if (state.age != null) _ageController.text = state.age!.toString();
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _saveUserInfo() async {
    // Save via the StateService to trigger immediate UI updates
    await ref.read(stateServiceProvider.notifier).updateUserInfo(
      height: _heightController.text,
      weight: _weightController.text,
      age: _ageController.text,
    );
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Personal Profile',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Updating your details will recalculate your target heart rate and step cadence.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 48),
              _buildTextField(
                controller: _ageController,
                labelText: 'Age (years)',
                icon: Icons.calendar_today,
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _heightController,
                labelText: 'Height (cm)',
                icon: Icons.height,
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _weightController,
                labelText: 'Weight (kg)',
                icon: Icons.monitor_weight,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _saveUserInfo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: theme.colorScheme.primary,
                ),
                child: Text(
                  'Apply Changes',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.secondary.withOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(color: theme.colorScheme.secondary),
      ),
      keyboardType: TextInputType.number,
      style: GoogleFonts.poppins(color: theme.colorScheme.onSurface),
    );
  }
}
