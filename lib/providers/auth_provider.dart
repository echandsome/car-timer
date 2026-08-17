import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/config_provider.dart';
import '../screens/onboarding_screen.dart';

class SplashNotifier extends Notifier<void> {
  @override
  void build() {}

  void decideNavigation(BuildContext context, WidgetRef ref) {
    // Just a simple delay now since config is already loaded in main.dart
    Future.delayed(const Duration(seconds: 2), () {
      if (!context.mounted) return;

      final config = ref.read(configProvider);

      if (config.isFirstRun) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else {
        // Placeholder for Dashboard
        debugPrint("User has seen onboarding. Navigate to Dashboard.");
      }
    });
  }
}

final splashProvider = NotifierProvider<SplashNotifier, void>(
  SplashNotifier.new,
);
