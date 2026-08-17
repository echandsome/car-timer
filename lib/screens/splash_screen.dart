// ignore_for_file: deprecated_member_use
import 'package:car_timer/providers/config_provider.dart';
import 'package:car_timer/screens/home_screen.dart';
import 'package:car_timer/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure the widget tree is rendered
    // before we start the async initialization.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startApp();
    });
  }

  Future<void> _startApp() async {
    try {
      // 1. Initialize the config (Language, First Run, Auth)
      await ref.read(configProvider.notifier).init();

      // 2. Wait for branding (Total splash time approx 2s)
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      final notifier = ref.read(configProvider.notifier);

      // Check if profile is created
      final profileCreated = await notifier.isProfileCreated();

      // 3. Navigation Logic
      Widget nextScreen;
      if (!profileCreated) {
        // No profile, go to onboarding
        nextScreen = const OnboardingScreen();
      } else {
        // Profile exists, go to home
        nextScreen = const HomeScreen();
      }

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
      }
    } catch (e) {
      debugPrint("Initialization Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpeg', // Path to your background
              fit: BoxFit.cover,
            ),
          ),
          // Dark Overlay to match the design depth
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
          // Logo
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Image.asset(
                'assets/images/logo.png', // Path to your DE logo
                width: MediaQuery.of(context).size.width * 0.6,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
