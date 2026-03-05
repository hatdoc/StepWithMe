import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/app_state.dart';

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
    final messenger = ScaffoldMessenger.of(context);
    
    // Save via the StateService to trigger immediate UI updates
    final success = await ref.read(stateServiceProvider.notifier).updateUserInfo(
      height: _heightController.text,
      weight: _weightController.text,
      age: _ageController.text,
    );
    
    if (!success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter valid numeric values.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('Your Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set your details for scientifically accurate step cadences.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            _buildTextField(
              controller: _ageController,
              labelText: 'Age (years)',
              icon: Icons.calendar_today,
              hint: 'e.g. 30',
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _heightController,
              labelText: 'Height (cm)',
              icon: Icons.height,
              hint: 'e.g. 174',
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _weightController,
              labelText: 'Weight (kg)',
              icon: Icons.monitor_weight,
              hint: 'e.g. 80',
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _saveUserInfo,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(
                'Apply Changes',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (Navigator.of(context).canPop())
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? hint,
  }) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hint,
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(color: theme.colorScheme.secondary),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.poppins(color: theme.colorScheme.onSurface),
    );
  }
}
