import 'dart:convert';
import 'package:car_timer/main.dart';
import 'package:car_timer/screens/home_screen.dart';
import 'package:car_timer/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';

class AppConfig {
  final Locale locale;
  final bool isFirstRun;
  final Map<String, String> translations;
  final bool isAuthenticated;

  // New preferences
  final bool autoStartEnabled;
  final bool autoStopEnabled;
  final String speedUnit;
  final String distanceUnit;

  AppConfig({
    required this.locale,
    required this.isFirstRun,
    this.translations = const {},
    required this.isAuthenticated,
    required this.autoStartEnabled,
    required this.autoStopEnabled,
    required this.speedUnit,
    required this.distanceUnit,
  });
}

class ConfigNotifier extends Notifier<AppConfig> {
  final _translator = GoogleTranslator();

  // 20+ Hardcoded languages for INSTANT loading
  final Map<String, String> topLanguages = {
    "en": "English",
    "ur": "Urdu (اردو)",
    "ar": "Arabic (العربية)",
    "hi": "Hindi (हिन्दी)",
    "es": "Spanish (Español)",
    "fr": "French (Français)",
    "de": "German (Deutsch)",
    "zh": "Chinese (中文)",
    "ja": "Japanese (日本語)",
    "ru": "Russian (Русский)",
    "pt": "Portuguese (Português)",
    "pa": "Punjabi (ਪੰਜਾਬੀ)",
    "bn": "Bengali (বাংলা)",
    "ko": "Korean (한국어)",
    "tr": "Turkish (Türkçe)",
    "it": "Italian (Italiano)",
    "vi": "Vietnamese (Tiếng Việt)",
    "fa": "Persian (فارسی)",
    "nl": "Dutch (Nederlands)",
    "pl": "Polish (Polski)",
    "id": "Indonesian (Bahasa Indonesia)",
    "th": "Thai (ไทย)",
  };

  // Master English Text
  final Map<String, String> _sourceText = {
    "app_title": "DE 0-100 Timer",
    "car_timer": "Car Timer",
    "feature_1_title": "Track Your Car's Acceleration",
    "feature_1_desc":
        "The App can track your acceleration across various modes such as 0-50/0-100km/h (0-30/0-60mph) or 0-200/0-400m (1/8 or 1/4 mile)",
    "feature_2_title": "Customisable mode & top speed",
    "feature_2_desc":
        "A mode that allows you to track acceleration between speeds that you define is built right into the app, along with a mode that records the top speed.",
    "feature_3_title": "GPS and algorithms",
    "feature_3_desc":
        "To be as precise as possible the app employs a combination of GPS and custom-made algorithms that estimate speeds even if the GPS is unreliable or late to deliver updates.",
    "language_label": "Language",
    "btn_begin": "BEGIN",
    "select_language": "Select Language",
    "tab_speed": "SPEED",
    "tab_distance": "Distance",
    "timer_stopped": "Timer Stopped!",
    "btn_start": "START",
    "btn_stop": "STOP",
    "btn_results": "RESULTS",
    "btn_leaderboard": "LEADERBOARD",
    "nav_timer": "Timer",
    "nav_preference": "Preference",
    "mounting_msg":
        "In order for this app to run with optimum accuracy, please ensure your device is securely mounted in/on the vehicle.",
    // Add these new keys for Home Screen
    "max_speed_reached": "Max Speed Reached!",
    "target_reached": "Target Reached!",
    "timer_stopped_at": "Timer Stopped at",
    "running": "RUNNING...",
    "stop_timer_first": "Please stop the timer first",
    "help": "HELP",
    "custom": "Custom",
    // Distance tab keys
    "mile": "mile",
    "meters": "m",
    "braking": "Braking",
    "stopping_distance": "Stopping Distance",
    "distance": "Distance",
    "1/8_mile": "1/8 mile",
    "1/4_mile": "1/4 mile",
    // Braking related keys
    "braking_complete": "Braking Complete!",
    "braking_stopped": "Braking Stopped",
    "braking_from_current": "Braking : From current speed to 0",
    "stopping_time": "Stopping time",
    "seconds": "s",
    'under_development': 'Under Development',
    'units': 'UNITS',
    'speed_units': 'Speed Units',
    'distance_units': 'Distance Units',
    'timer_settings': 'TIMER SETTINGS',
    'mute_sounds': 'Mute Sounds',
    'auto_start': 'Auto Start',
    'auto_start_desc': 'Auto-start timer when movement detected',
    'auto_stop': 'Auto Stop',
    'auto_stop_desc': 'Auto-stop when target reached or movement stops',
    'disclaimer': 'DISCLAIMER',
    'disclaimer_text':
        'This app is not to be used on public roads.\n\n'
        'By using this app, you agree to obey all traffic rules and regulations in your local jurisdiction.\n'
        'Do not operate this app in a manner that will distract you from the road.',
    'disclaimer_warning': 'This app is not to be used on public roads.',
    'restore_purchase': 'Restore Purchase',
    'preferences': 'Preferences',
    'customize_settings': 'Customize your app settings',
    // Add after existing keys
    "search_language": "Search language...",
    "no_language_found": "No language found",
    "notice": "Notice",
    "continuing_with": "You are continuing with {language}.",
    "ok": "OK",
    // Preset keys for speed and distance
    "preset_1_8_mile": "1/8 mile",
    "preset_1_4_mile": "1/4 mile",
    // Profile dialog keys
    "create_profile": "Create Profile",
    "profile_subtitle": "Please fill in your details to continue",
    "nickname": "Nickname",
    "car_make": "Car Make",
    "car_model": "Car Model",
    "year": "Year",
    "create_profile_button": "CREATE PROFILE",
    "nickname_required": "Please enter your nickname",
    "car_make_required": "Please enter your car make",
    "car_model_required": "Please enter your car model",
    "year_required": "Please enter the year",
    "year_invalid": "Please enter a valid year (1900-{currentYear})",
    "profile_created_success": "Profile created successfully!",
    // Speed preset keys
    "preset_0_60_mph": "0-60 mph",
    "preset_0_60_kmh": "0-60 km/h",
    "preset_0_100_kmh": "0-100 km/h",
    "preset_0_100_mph": "0-100 mph",
  };

  @override
  AppConfig build() {
    return AppConfig(
      locale: const Locale('en'),
      isFirstRun: true,
      translations: _sourceText,
      isAuthenticated: false,
      autoStartEnabled: true, // Default: Auto-start ON
      autoStopEnabled: true, // Default: Auto-stop ON
      speedUnit: 'km/h', // Default speed unit
      distanceUnit: 'meters', // Default distance unit
    );
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final langCode = prefs.getString('language_code') ?? 'en';
    final hasRun = prefs.getBool('has_run') ?? false;
    final isAuth = prefs.getBool('is_auth') ?? false;

    // Load preferences
    final autoStartEnabled = prefs.getBool('auto_start') ?? true;
    final autoStopEnabled = prefs.getBool('auto_stop') ?? true;
    final speedUnit = prefs.getString('speed_unit') ?? 'km/h';
    final distanceUnit = prefs.getString('distance_unit') ?? 'meters';

    Map<String, String> loadedTranslations = _sourceText;
    String? savedJson = prefs.getString('cached_translations');

    if (savedJson != null) {
      try {
        loadedTranslations = Map<String, String>.from(json.decode(savedJson));
      } catch (e) {
        loadedTranslations = _sourceText;
      }
    }

    state = AppConfig(
      locale: Locale(langCode),
      isFirstRun: !hasRun,
      isAuthenticated: isAuth,
      translations: loadedTranslations,
      autoStartEnabled: autoStartEnabled,
      autoStopEnabled: autoStopEnabled,
      speedUnit: speedUnit,
      distanceUnit: distanceUnit,
    );
  }

  Future<void> setAutoStartEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_start', value);
    state = AppConfig(
      locale: state.locale,
      isFirstRun: state.isFirstRun,
      isAuthenticated: state.isAuthenticated,
      translations: state.translations,
      autoStartEnabled: value,
      autoStopEnabled: state.autoStopEnabled,
      speedUnit: state.speedUnit,
      distanceUnit: state.distanceUnit,
    );
  }

  Future<void> setAutoStopEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_stop', value);
    state = AppConfig(
      locale: state.locale,
      isFirstRun: state.isFirstRun,
      isAuthenticated: state.isAuthenticated,
      translations: state.translations,
      autoStartEnabled: state.autoStartEnabled,
      autoStopEnabled: value,
      speedUnit: state.speedUnit,
      distanceUnit: state.distanceUnit,
    );
  }

  Future<void> setSpeedUnit(String unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('speed_unit', unit);
    state = AppConfig(
      locale: state.locale,
      isFirstRun: state.isFirstRun,
      isAuthenticated: state.isAuthenticated,
      translations: state.translations,
      autoStartEnabled: state.autoStartEnabled,
      autoStopEnabled: state.autoStopEnabled,
      speedUnit: unit,
      distanceUnit: state.distanceUnit,
    );
  }

  Future<void> setDistanceUnit(String unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('distance_unit', unit);
    state = AppConfig(
      locale: state.locale,
      isFirstRun: state.isFirstRun,
      isAuthenticated: state.isAuthenticated,
      translations: state.translations,
      autoStartEnabled: state.autoStartEnabled,
      autoStopEnabled: state.autoStopEnabled,
      speedUnit: state.speedUnit,
      distanceUnit: unit,
    );
  }

  // Add these methods to ConfigNotifier class
  Future<bool> isProfileCreated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('profile_created') ?? false;
  }

  Future<Map<String, String>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('profile_data');
    if (profileJson != null) {
      return Map<String, String>.from(json.decode(profileJson));
    }
    return {};
  }

  Future<void> saveProfile(Map<String, String> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_created', true);
    await prefs.setString('profile_data', json.encode(profile));
  }

  Future<void> setLanguage(BuildContext context, String rawCode) async {
    String cleanCode = rawCode.split('_')[0].split('-')[0];

    // 1. Show Spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.red)),
    );

    try {
      Map<String, String> newTranslations = {};
      for (var entry in _sourceText.entries) {
        var translation = await _translator.translate(
          entry.value,
          to: cleanCode,
        );
        newTranslations[entry.key] = translation.text;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', cleanCode);
      await prefs.setString(
        'cached_translations',
        json.encode(newTranslations),
      );

      state = AppConfig(
        locale: Locale(cleanCode),
        isFirstRun: state.isFirstRun,
        isAuthenticated: state.isAuthenticated,
        translations: newTranslations,
        autoStartEnabled: state.autoStartEnabled,
        autoStopEnabled: state.autoStopEnabled,
        speedUnit: state.speedUnit,
        distanceUnit: state.distanceUnit,
      );
    } catch (e) {
      debugPrint("Translation Error: $e");
      // 2. Use AppDialog for errors
      if (context.mounted) {
        AppDialog.show(
          context,
          title: "Connection Error",
          message: "Could not translate UI. Please check your internet.",
          type: DialogType.error,
        );
      }
    } finally {
      // 3. THE FIX: Always close the spinner using the Global Key
      // This works even if the local 'context' is no longer valid
      if (navigatorKey.currentState?.canPop() ?? false) {
        navigatorKey.currentState?.pop();
      }
    }
  }

  void completeOnboarding([BuildContext? context]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_run', true);

    // Save default preferences on first run
    if (state.isFirstRun) {
      await prefs.setBool('auto_start', true);
      await prefs.setBool('auto_stop', true);
      await prefs.setString('speed_unit', 'km/h');
      await prefs.setString('distance_unit', 'meters');
    }

    state = AppConfig(
      locale: state.locale,
      isFirstRun: false,
      isAuthenticated: state.isAuthenticated,
      translations: state.translations,
      autoStartEnabled: state.autoStartEnabled,
      autoStopEnabled: state.autoStopEnabled,
      speedUnit: state.speedUnit,
      distanceUnit: state.distanceUnit,
    );

    // Navigate to Home screen - Use WidgetsBinding to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context != null) {
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (navigatorKey.currentState != null) {
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // Fallback: print error for debugging
        debugPrint("Navigator key is not available");
      }
    });
  }
}

final configProvider = NotifierProvider<ConfigNotifier, AppConfig>(
  ConfigNotifier.new,
);
