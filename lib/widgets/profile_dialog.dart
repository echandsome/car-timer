import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/config_provider.dart';

class ProfileDialog extends ConsumerStatefulWidget {
  const ProfileDialog({super.key});

  @override
  ConsumerState<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _carMakeController = TextEditingController();
  final _carModelController = TextEditingController();
  final _yearController = TextEditingController();

  @override
  void dispose() {
    _nicknameController.dispose();
    _carMakeController.dispose();
    _carModelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(configProvider).translations;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 25),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Header
                Icon(Icons.person_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  t['create_profile'] ?? 'Create Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t['profile_subtitle'] ??
                      'Please fill in your details to continue',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),

                // Nickname Field
                TextFormField(
                  controller: _nicknameController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: t['nickname'] ?? 'Nickname',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                    prefixIcon: Icon(Icons.person, color: Colors.red),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.black.withOpacity(0.3)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return t['nickname_required'] ??
                          'Please enter your nickname';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Car Make Field
                TextFormField(
                  controller: _carMakeController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: t['car_make'] ?? 'Car Make',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                    prefixIcon: Icon(Icons.directions_car, color: Colors.red),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.black.withOpacity(0.3)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return t['car_make_required'] ??
                          'Please enter your car make';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Car Model Field
                TextFormField(
                  controller: _carModelController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: t['car_model'] ?? 'Car Model',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                    prefixIcon: Icon(Icons.car_rental, color: Colors.red),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.black.withOpacity(0.3)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return t['car_model_required'] ??
                          'Please enter your car model';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Year Field
                TextFormField(
                  controller: _yearController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t['year'] ?? 'Year',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                    prefixIcon: Icon(Icons.calendar_today, color: Colors.red),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.black.withOpacity(0.3)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return t['year_required'] ?? 'Please enter the year';
                    }
                    final year = int.tryParse(value);
                    final currentYear = DateTime.now().year;
                    if (year == null || year < 1900 || year > currentYear + 1) {
                      final errorMsg =
                          t['year_invalid'] ??
                          'Please enter a valid year (1900-{currentYear})';
                      return errorMsg.replaceAll(
                        '{currentYear}',
                        currentYear.toString(),
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Create Profile Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saveProfile,
                    child: Text(
                      t['create_profile_button'] ?? 'CREATE PROFILE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    if (_formKey.currentState!.validate()) {
      final profile = {
        'nickname': _nicknameController.text.trim(),
        'car_make': _carMakeController.text.trim(),
        'car_model': _carModelController.text.trim(),
        'year': _yearController.text.trim(),
      };

      final notifier = ref.read(configProvider.notifier);
      await notifier.saveProfile(profile);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }
}
