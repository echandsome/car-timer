import 'package:car_timer/widgets/app_dialog.dart';
import 'package:car_timer/widgets/profile_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/config_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    final t = config.translations;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'assets/images/background.jpeg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(t['app_title'] ?? "DE 0-100 Timer"),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        Text(
                          t['car_timer'] ?? "Car Timer",
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 50),
                        _buildFeature(
                          Icons.speed,
                          t['feature_1_title'] ?? "",
                          t['feature_1_desc'] ?? "",
                        ),
                        _buildFeature(
                          Icons.av_timer,
                          t['feature_2_title'] ?? "",
                          t['feature_2_desc'] ?? "",
                        ),
                        _buildFeature(
                          Icons.gps_fixed,
                          t['feature_3_title'] ?? "",
                          t['feature_3_desc'] ?? "",
                        ),
                      ],
                    ),
                  ),
                ),
                _buildLangButton(context, config),
                _buildBeginButton(t['btn_begin'] ?? "BEGIN"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.black.withOpacity(0.7),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Row(
        children: [
          Icon(icon, size: 35, color: Colors.white),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangButton(BuildContext context, AppConfig config) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(
          config.translations['language_label'] ?? "Language",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              config.locale.languageCode.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
        onTap: () {
          // Show a single dialog that starts with a loading spinner
          showDialog(
            context: context,
            // barrierDismissible: false,
            builder: (dialogContext) {
              return FutureBuilder(
                // Short delay ensures the spinner is visible first
                future: Future.delayed(const Duration(milliseconds: 300)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // Show loading spinner
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.red),
                    );
                  }
                  // After delay, show the actual language picker
                  return _buildLanguagePickerDialog(dialogContext);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLanguagePickerDialog(BuildContext dialogContext) {
    final instantLanguages = ref.read(configProvider.notifier).topLanguages;
    final allLanguages = instantLanguages.entries.toList();
    String searchQuery = "";

    return StatefulBuilder(
      builder: (context, setState) {
        final filteredList = allLanguages.where((entry) {
          return entry.value.toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();
        final t = ref.read(configProvider).translations;

        return AlertDialog(
          backgroundColor: const Color(0xFFE0E0E0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: TextField(
            autofocus: true,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: t['search_language'] ?? "Search language...",
              hintStyle: const TextStyle(color: Colors.black45),
              prefixIcon: const Icon(Icons.search, color: Colors.black87),
              filled: true,
              fillColor: Colors.black.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => searchQuery = val),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: filteredList.isEmpty
                ? Center(
                    child: Text(
                      t['no_language_found'] ?? "No language found",
                      style: const TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredList.length,
                    itemExtent: 50,
                    itemBuilder: (context, index) {
                      final langCode = filteredList[index].key;
                      final langName = filteredList[index].value;
                      return ListTile(
                        title: Text(
                          langName,
                          style: const TextStyle(color: Colors.black),
                        ),
                        trailing: Text(
                          langCode.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black38,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(configProvider.notifier)
                              .setLanguage(context, langCode);
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildBeginButton(String label) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC40000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          onPressed: () async {
            final config = ref.read(configProvider);
            final notifier = ref.read(configProvider.notifier);
            final t = ref.read(configProvider).translations;

            // Check if profile already exists
            final profileCreated = await notifier.isProfileCreated();

            if (profileCreated) {
              // Profile already exists, navigate directly
              notifier.completeOnboarding();
            } else {
              final languageName =
                  notifier.topLanguages[config.locale.languageCode] ??
                  config.locale.languageCode.toUpperCase();

              // Show notice dialog first
              AppDialog.show(
                context,
                title: t['notice'] ?? "Notice",
                message:
                    (t['continuing_with'] ??
                            "You are continuing with {language}.")
                        .replaceAll('{language}', languageName),
                type: DialogType.info,
                onOkPressed: () {
                  // After notice, show profile creation dialog
                  showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) => const ProfileDialog(),
                  ).then((profileCreated) {
                    if (profileCreated == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            t['profile_created_success'] ??
                                'Profile created successfully!',
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 1),
                        ),
                      );

                      notifier.completeOnboarding(context);
                    }
                  });
                },
              );
            }
          },
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
