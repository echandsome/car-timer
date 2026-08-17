import 'dart:async';
import 'dart:math' as math;
import 'package:car_timer/screens/results_screen.dart';
import 'package:car_timer/services/location_service.dart';
import 'package:car_timer/services/performance_service.dart';
import 'package:car_timer/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/config_provider.dart';

// Preferences Screen Widget
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  String _selectedSpeedUnit = "km/h";
  String _selectedDistanceUnit = "meters";
  bool _muteSounds = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(configProvider).translations;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
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
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(t),
                        const SizedBox(height: 12),
                        _buildSectionTitle(t['units'] ?? 'UNITS'),
                        const SizedBox(height: 12),
                        _buildDropdownTile(
                          label: t['speed_units'] ?? 'Speed Units:',
                          value: _selectedSpeedUnit,
                          items: const ['km/h', 'mph'],
                          onChanged: (value) =>
                              setState(() => _selectedSpeedUnit = value!),
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownTile(
                          label: t['distance_units'] ?? 'Distance Units:',
                          value: _selectedDistanceUnit,
                          items: const ['meters', 'feet'],
                          onChanged: (value) =>
                              setState(() => _selectedDistanceUnit = value!),
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle(
                          t['timer_settings'] ?? 'TIMER SETTINGS',
                        ),
                        const SizedBox(height: 12),

                        _buildSwitchTile(
                          label: t['mute_sounds'] ?? 'Mute Sounds:',
                          value: _muteSounds,
                          onChanged: (value) =>
                              setState(() => _muteSounds = value),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t['disclaimer'] ?? 'DISCLAIMER',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(
                                  minHeight: 80,
                                ),
                                child: Text(
                                  t['disclaimer_text'] ??
                                      'This app is not to be used on public roads.\n\n'
                                          'By using this app, you agree to obey all traffic rules and regulations in your local jurisdiction.\n'
                                          'Do not operate this app in a manner that will distract you from the road.',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        t['disclaimer_warning'] ??
                                            'This app is not to be used on public roads.',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () {
                      AppDialog.show(
                        context,
                        title: t['restore_purchase'] ?? 'Restore Purchase',
                        message: t['under_development'] ?? 'Under Development',
                        type: DialogType.info,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      t['restore_purchase'] ?? '[Restore Purchase]',
                      style: const TextStyle(
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, String> t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t['preferences'] ?? 'Preferences',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t['customize_settings'] ?? 'Customize your app settings',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.red,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDropdownTile({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF1A1A1A),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              underline: Container(),
              items: items.map((String item) {
                return DropdownMenuItem<String>(value: item, child: Text(item));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.red,
            activeTrackColor: Colors.red.withOpacity(0.5),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String _activeTab = "SPEED";
  String _selectedSpeedPreset = "0-60 mph";
  String _selectedDistancePreset = "1/8 mile";
  double _currentSpeed = 0.0;
  double _currentDistance = 0.0;
  double _lastServiceDistance = 0.0;
  double _lastRunProgress = 0.0;
  bool _hasRunData = false;

  // Braking specific variables
  double _brakingStartSpeed = 100.0;
  double _brakingDistance = 0.0;
  double _brakingTime = 0.0;
  bool _isBraking = false;

  // Timer functionality
  bool _isTimerRunning = false;
  final double _maxSpeed = 100.0;
  double _targetSpeed = 0.0;
  double _targetDistance = 201.0;
  String _timerStatus = '';
  bool _showTimerStatus = true;

  // Services
  final LocationService _locationService = LocationService();
  final PerformanceService _performanceService = PerformanceService();

  // UI Update throttling
  DateTime _lastUiUpdate = DateTime.now();

  // Flag to prevent multiple start attempts
  bool _isStarting = false;
  DateTime? _timerStartedAt;
  DateTime? _brakingStartedAt;
  bool _isBlockingDialogOpen = false;
  bool _saveThisRun = true;
  bool _isGpsWeakDialogOpen = false;
  Timer? _distanceDisplayTimer;
  Timer? _brakingAutoStopTimer;
  double _displayDistance = 0.0;
  DateTime? _gpsWeakSince;
  double _gpsMovementWithoutSpeed = 0.0;
  bool _isCompletingRun = false;
  // bool _autoDistanceSessionStarted = false;

  // Live pre-run movement state: used only for button gating and hub display.
  bool _wasMovingBeforeRun = false;
  double _previewDistanceBeforeRun = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTargetsWithSelection();
    _updateTimerStatus();
    _initializeServices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeServices();
    }
  }

  bool get _showGpsDebugOverlay {
    return !const bool.fromEnvironment('dart.vm.product');
  }

  Future<void> _initializeServices() async {
    final initialized = await _locationService.initialize();

    if (!mounted) return;

    if (initialized) {
      _locationService.startTracking();

      // Avoid duplicate listener registration after app resume.
      _locationService.removeListener(_onLocationUpdate);
      _locationService.addListener(_onLocationUpdate);
      return;
    }

    if (!_locationService.isServiceEnabled) {
      AppDialog.show(
        context,
        title: 'Location Required',
        message:
            'Location services are turned off. Please enable GPS/location services to use the car performance timer.',
        type: DialogType.info,
        onOkPressed: () async {
          await _locationService.openLocationSettings();
        },
      );
      return;
    }

    if (!_locationService.hasPermission) {
      AppDialog.show(
        context,
        title: 'Location Permission Required',
        message:
            'This app needs location permission to measure speed, distance, and braking performance. Please allow location access.',
        type: DialogType.info,
        onOkPressed: () async {
          await _locationService.openAppSettings();
        },
      );
      return;
    }

    AppDialog.show(
      context,
      title: 'Location Error',
      message:
          'Unable to start location tracking. Please check your device location settings.',
      type: DialogType.error,
    );
  }

  void _onLocationUpdate() {
    if (!mounted) return;

    if (!_isHomeScreenVisible) return;
    if (!_isTimerTabActive && !_isTimerRunning) return;

    // Confirmed speed is used for test logic/results.
    // Display speed is UI-only smoothing for hub/needle responsiveness.
    final confirmedSpeed = _locationService.confirmedSpeedKmh;
    final displaySpeed = _locationService.displaySpeedKmh;

    final serviceTotalDistance = _locationService.totalDistance;
    final now = DateTime.now();
    final shouldUpdateUi = now.difference(_lastUiUpdate).inMilliseconds > 50;

    double distanceDelta = serviceTotalDistance - _lastServiceDistance;
    if (distanceDelta < 0 || distanceDelta > 80) {
      distanceDelta = 0.0;
    }
    _lastServiceDistance = serviceTotalDistance;

    // Movement truth for UI gating. 1 km/h keeps walking debug usable but blocks
    // acceleration-run start while the car is already rolling.
    final bool isMovingNow = _isLiveSpeedMoving(confirmedSpeed);
    if (!_isTimerRunning && _isTimerTabActive) {
      final shouldRefreshGpsUi =
          now.difference(_lastUiUpdate).inMilliseconds > 100;

      if (shouldRefreshGpsUi) {
        _lastUiUpdate = now;
        setState(() {
          _wasMovingBeforeRun = isMovingNow;

          if (_activeTab == "SPEED") {
            // Acceleration tab: stationary means ready to start; moving means show
            // live speed and block the run until the vehicle stops.
            _currentSpeed = isMovingNow ? displaySpeed : 0.0;
            if (!isMovingNow) {
              _previewDistanceBeforeRun = 0.0;
            }
          } else if (_selectedDistancePreset == "Braking") {
            // Braking tab: moving speed is required so the driver can press start
            // exactly when braking begins.
            _currentSpeed = displaySpeed;
            _brakingStartSpeed = isMovingNow ? confirmedSpeed : 0.0;
          } else {
            // Distance tab pre-run behavior:
            // Moving without pressing START is preview only.
            // It must NOT start a real timer and must NOT save any result.
            _currentSpeed = displaySpeed;
            if (isMovingNow) {
              _previewDistanceBeforeRun += distanceDelta;
              _currentDistance = _previewDistanceBeforeRun;
              _displayDistance = _previewDistanceBeforeRun;
            } else {
              _previewDistanceBeforeRun = 0.0;
              _currentDistance = 0.0;
              _displayDistance = 0.0;
            }
          }
        });
      }
      return;
    }

    if (_isTimerRunning) {
      _handleGpsWeakDialog();

      final gpsAccuracy = _locationService.lastGpsAccuracy;
      final bool gpsAccuracyBad =
          gpsAccuracy > LocationService.strongGpsAccuracyMeters;

      // Do not cancel for normal zero speed. Cancel only for genuinely unreliable GPS.
      if (gpsAccuracyBad || !_locationService.hasFreshGpsUpdate) {
        _abortTimerDueToGpsIssue(_locationService.gpsSignalMessage);
        return;
      }

      if (_isBrakingPreset) {
        _handleBrakingRunningUpdate(
          confirmedSpeed: confirmedSpeed,
          displaySpeed: displaySpeed,
          distanceDelta: distanceDelta,
        );
        return;
      }

      if (shouldUpdateUi) {
        _lastUiUpdate = now;
        setState(() {
          _currentSpeed = displaySpeed;
          _currentDistance += distanceDelta;

          if (_activeTab == "DISTANCE") {
            if (_displayDistance < _currentDistance) {
              _displayDistance =
                  _displayDistance +
                  ((_currentDistance - _displayDistance) * 0.25);
            }
          }

          _lastRunProgress = _getProgressValue();
          _hasRunData = true;
        });
      } else {
        _currentSpeed = displaySpeed;
        _currentDistance += distanceDelta;

        if (_activeTab == "DISTANCE") {
          if (_displayDistance < _currentDistance) {
            _displayDistance =
                _displayDistance +
                ((_currentDistance - _displayDistance) * 0.25);
          }
        }

        _lastRunProgress = _getProgressValue();
        _hasRunData = true;
      }

      _performanceService.updatePerformance(
        currentSpeed: confirmedSpeed,
        distanceDelta: distanceDelta,
        sampleTime: _locationService.lastGpsSampleTime,
      );

      if (_performanceService.isTargetReached()) {
        _finishCompletedRun(showSavedDialog: true);
        return;
      }

      return;
    }
  }

  String _formatDurationSmart(double seconds) {
    final totalSeconds = seconds.round();

    if (totalSeconds < 60) {
      return '${seconds.toStringAsFixed(2)}s';
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  bool _isLiveSpeedMoving(double speedKmh) {
    return speedKmh >= LocationService.minTrustedPlatformSpeedKmh;
  }

  bool get _shouldBlockStartBecauseMoving {
    if (!_locationService.isReadyForTest) return false;
    if (!_wasMovingBeforeRun) return false;

    // Braking is the only preset that should start while moving.
    return !_isBrakingPreset;
  }

  bool get _canStartBrakingRun {
    return _isBrakingPreset &&
        _locationService.isReadyForTest &&
        _wasMovingBeforeRun;
  }

  bool _hasReachedSelectedTarget() {
    if (!_isTimerRunning) return false;

    if (_activeTab == "SPEED") {
      return _performanceService.isTargetReached();
    }

    if (_activeTab == "DISTANCE" && !_isBrakingPreset) {
      return _performanceService.isTargetReached();
    }

    return false;
  }

  Future<void> _finishCompletedRun({
    String? statusMessage,
    bool showSavedDialog = true,
  }) async {
    if (!_isTimerRunning || _isCompletingRun || !mounted) return;

    _isCompletingRun = true;

    _closeGpsWeakDialogIfOpen();
    _gpsWeakSince = null;

    _distanceDisplayTimer?.cancel();
    _distanceDisplayTimer = null;
    _lastDistanceRenderAt = null;

    _brakingAutoStopTimer?.cancel();
    _brakingAutoStopTimer = null;

    final t = ref.read(configProvider).translations;
    final finalSpeed = _currentSpeed;
    final finalDistance = _currentDistance;
    final finalProgress = _getProgressValue();

    await _performanceService.completeSession();

    if (!mounted) return;

    setState(() {
      _isTimerRunning = false;
      _showTimerStatus = true;
      _isBraking = false;
      // _autoDistanceSessionStarted = false;
      _lastRunProgress = finalProgress;
      _hasRunData = true;
      _currentDistance = finalDistance;

      if (_activeTab == "SPEED") {
        _currentSpeed = 0.0;
        _timerStatus =
            statusMessage ??
            '${t['target_reached'] ?? 'Target Reached!'} ${_getTargetSpeedDisplayValue().toInt()} ${_getSpeedUnit()}';
      } else if (_isBrakingPreset) {
        _currentSpeed = finalSpeed;
        _timerStatus =
            statusMessage ??
            '${t['braking_complete'] ?? 'Braking Complete!'} ${_brakingDistance.toStringAsFixed(1)} ${t['meters'] ?? 'm'} / ${_formatDurationSmart(_brakingTime)}';
      } else {
        _currentSpeed = finalSpeed;
        _timerStatus =
            statusMessage ??
            '${t['target_reached'] ?? 'Target Reached!'} ${_targetDistance.toInt()} ${t['meters'] ?? 'm'}';
      }
    });

    _isCompletingRun = false;

    if (showSavedDialog && mounted) {
      _isBlockingDialogOpen = true;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1C1C1C),
            title: const Text(
              'History Saved',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'This completed test result has been saved locally in your results history.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );

      _isBlockingDialogOpen = false;
    }
  }

  // Shows live GPS speed in SPEED tab before a run starts, while Start is blocked.
  bool get _shouldPreviewLiveSpeedInSpeedTab {
    return !_isTimerRunning &&
        _selectedIndex == 0 &&
        _activeTab == "SPEED" &&
        _wasMovingBeforeRun;
  }

  // Future<void> _completeTimerAfterTargetReached() async {
  //   if (!_isTimerRunning || !mounted) return;

  //   _closeGpsWeakDialogIfOpen();
  //   _gpsWeakSince = null;

  //   _distanceDisplayTimer?.cancel();
  //   _distanceDisplayTimer = null;
  //   _lastDistanceRenderAt = null;

  //   _brakingAutoStopTimer?.cancel();
  //   _brakingAutoStopTimer = null;

  //   final t = ref.read(configProvider).translations;
  //   final finalSpeed = _currentSpeed;
  //   final finalDistance = _currentDistance;
  //   final finalProgress = _getProgressValue();

  //   _performanceService.completeSession();

  //   setState(() {
  //     _isTimerRunning = false;
  //     _showTimerStatus = true;
  //     _isBraking = false;
  //     _lastRunProgress = finalProgress;
  //     _hasRunData = true;
  //     _currentDistance = finalDistance;

  //     if (_activeTab == "SPEED") {
  //       _currentSpeed = 0.0;
  //       _timerStatus =
  //           '${t['target_reached'] ?? 'Target Reached!'} ${_targetSpeed.toInt()} ${_getSpeedUnit()}';
  //     } else {
  //       _currentSpeed = finalSpeed;
  //       _timerStatus =
  //           '${t['target_reached'] ?? 'Target Reached!'} ${finalDistance.toInt()} ${t['meters'] ?? 'm'}';
  //     }
  //   });
  // }

  void _handleGpsWeakDialog() {
    if (!_isTimerRunning || !mounted) return;

    final now = DateTime.now();

    final justStarted =
        _timerStartedAt != null &&
        now.difference(_timerStartedAt!).inMilliseconds < 2500;

    if (justStarted) {
      _gpsWeakSince = null;
      return;
    }

    final bool actualGpsProblem =
        !_locationService.hasFreshGpsUpdate ||
        _locationService.lastGpsAccuracy >
            LocationService.strongGpsAccuracyMeters;

    if (actualGpsProblem) {
      _gpsWeakSince ??= now;

      final weakLongEnough =
          now.difference(_gpsWeakSince!).inMilliseconds >= 1500;

      if (weakLongEnough) {
        _abortTimerDueToGpsIssue(_locationService.gpsSignalMessage);
      }
    } else {
      _gpsWeakSince = null;
      _closeGpsWeakDialogIfOpen();
    }
  }

  // Future<void> _showGpsWeakDialogIfNeeded() async {
  //   if (_isGpsWeakDialogOpen || !_isTimerRunning || !mounted) return;

  //   _isGpsWeakDialogOpen = true;

  //   await showDialog<void>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (dialogContext) {
  //       return AlertDialog(
  //         backgroundColor: const Color(0xFF1C1C1C),
  //         title: const Text(
  //           'GPS Signal Weak',
  //           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  //         ),
  //         content: Text(
  //           _locationService.gpsSignalMessage,
  //           style: const TextStyle(color: Colors.white70),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               if (Navigator.of(dialogContext).canPop()) {
  //                 Navigator.of(dialogContext).pop();
  //               }
  //             },
  //             child: const Text(
  //               'OK',
  //               style: TextStyle(
  //                 color: Colors.red,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           ),
  //         ],
  //       );
  //     },
  //   );

  //   _isGpsWeakDialogOpen = false;
  // }

  void _closeGpsWeakDialogIfOpen() {
    if (!_isGpsWeakDialogOpen || !mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }

    _isGpsWeakDialogOpen = false;
  }

  Future<void> _abortTimerDueToGpsIssue(String message) async {
    if (!_isTimerRunning || !mounted) return;

    _closeGpsWeakDialogIfOpen();
    _gpsWeakSince = null;

    _distanceDisplayTimer?.cancel();
    _distanceDisplayTimer = null;
    _lastDistanceRenderAt = null;

    _brakingAutoStopTimer?.cancel();
    _brakingAutoStopTimer = null;

    _saveThisRun = false;

    setState(() {
      _isTimerRunning = false;
      _showTimerStatus = true;
      _isBraking = false;
      _currentSpeed = 0.0;
      _timerStatus = 'Test cancelled: GPS signal unreliable';
      _lastRunProgress = _getProgressValue();
      _hasRunData = true;
    });

    _performanceService.reset();
    if (!mounted) return;

    _isBlockingDialogOpen = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1C),
          title: const Text(
            'Test Cancelled',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    _isBlockingDialogOpen = false;
  }

  void _handleBrakingRunningUpdate({
    required double confirmedSpeed,
    required double displaySpeed,
    required double distanceDelta,
  }) {
    final now = DateTime.now();

    // Braking should already be marked at START click.
    // Do not reset braking start time from GPS update.
    _brakingStartedAt ??= _timerStartedAt ?? now;
    _isBraking = true;

    final elapsedSeconds =
        now.difference(_brakingStartedAt!).inMilliseconds / 1000.0;

    setState(() {
      _currentSpeed = displaySpeed;
      _currentDistance += distanceDelta;
      _brakingDistance = _currentDistance;
      _brakingTime = elapsedSeconds;
      _lastRunProgress = _getProgressValue();
      _hasRunData = true;
    });

    _performanceService.updatePerformance(
      currentSpeed: confirmedSpeed,
      distanceDelta: distanceDelta,
      sampleTime: _locationService.lastGpsSampleTime,
    );

    final justStarted = now.difference(_brakingStartedAt!).inMilliseconds < 700;

    // Auto-stop braking when confirmed speed is near zero.
    // Short delay avoids stopping on a single noisy zero sample.
    if (!justStarted && confirmedSpeed <= 1.0) {
      _brakingAutoStopTimer ??= Timer(const Duration(milliseconds: 500), () {
        if (!mounted || !_isTimerRunning || !_isBrakingPreset) {
          _brakingAutoStopTimer = null;
          return;
        }

        if (_locationService.confirmedSpeedKmh <= 1.0) {
          _stopTimer(
            saveAsCompleted: true,
            notRecordedReason: 'Vehicle did not come to a confirmed stop.',
          );
        }

        _brakingAutoStopTimer = null;
      });
    } else {
      _brakingAutoStopTimer?.cancel();
      _brakingAutoStopTimer = null;
    }
  }

  Future<void> _confirmManualStartRun() async {
    if (!_isHomeScreenVisible ||
        !_isTimerTabActive ||
        _isBlockingDialogOpen ||
        _isTimerRunning ||
        _isStarting) {
      return;
    }

    _isBlockingDialogOpen = true;
    // _locationService.setMotionDebugEnabled(false);

    final shouldStart = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1C),
          title: const Text(
            'Start Test?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Do you want to start this test and save its result in history?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Yes, Start',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    _isBlockingDialogOpen = false;
    // _syncMotionDebugState();

    if (!mounted || !_isHomeScreenVisible || !_isTimerTabActive) return;

    if (shouldStart == true) {
      _saveThisRun = true;
      _startTimer();
    }
  }

  void _updateTimerStatus() {
    final t = ref.read(configProvider).translations;
    setState(() {
      _timerStatus = t['timer_stopped'] ?? 'Timer Stopped!';
    });
  }

  void _syncTargetsWithSelection() {
    _targetSpeed = _getTargetSpeedFromPreset(_selectedSpeedPreset);
    _targetDistance = _getTargetDistanceFromPreset(_selectedDistancePreset);
  }

  void _startDistanceDisplayTimer() {
    _distanceDisplayTimer?.cancel();

    _distanceDisplayTimer = Timer.periodic(const Duration(milliseconds: 120), (
      _,
    ) {
      if (!mounted || !_isTimerRunning) return;

      if (_activeTab != "DISTANCE" || _selectedDistancePreset == "Braking") {
        return;
      }

      // No artificial distance extrapolation.
      // Distance hub must reflect confirmed GPS distance only.
      setState(() {
        _displayDistance = _currentDistance.clamp(0.0, _targetDistance);
        _lastRunProgress = _getProgressValue();
        _hasRunData = true;
      });
    });
  }

  DateTime? _lastDistanceRenderAt;

  bool get _isBrakingPreset {
    return _activeTab == "DISTANCE" && _selectedDistancePreset == "Braking";
  }

  bool get _isHomeScreenVisible {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  bool get _isTimerTabActive {
    return _selectedIndex == 0 && _isHomeScreenVisible;
  }

  bool _blockNavigationDuringRun() {
    if (_isTimerRunning || _isStarting) {
      _showWarning(ref.read(configProvider).translations);
      return true;
    }

    return false;
  }

  @override
  void dispose() {
    _closeGpsWeakDialogIfOpen();
    _distanceDisplayTimer?.cancel();
    _brakingAutoStopTimer?.cancel();
    _locationService.removeListener(_onLocationUpdate);
    _locationService.stopTracking();
    super.dispose();
  }

  void _startTimer() {
    // Prevent multiple simultaneous start attempts
    if (_isTimerRunning || _isStarting) return;

    if (!_isHomeScreenVisible || !_isTimerTabActive || _isBlockingDialogOpen) {
      return;
    }
    _saveThisRun = true;

    _isStarting = true;
    _syncTargetsWithSelection();

    if (!_isBrakingPreset &&
        _isLiveSpeedMoving(_locationService.confirmedSpeedKmh)) {
      AppDialog.show(
        context,
        title: 'Stop Car First',
        message:
            'Acceleration and distance runs must start from 0. Stop the vehicle before starting this test.',
        type: DialogType.error,
      );
      _isStarting = false;
      return;
    }

    if (_isBrakingPreset &&
        !_isLiveSpeedMoving(_locationService.confirmedSpeedKmh)) {
      AppDialog.show(
        context,
        title: 'Move Car First',
        message:
            'For braking test, start moving first, then press Start Braking at the moment you begin braking.',
        type: DialogType.error,
      );
      _isStarting = false;
      return;
    }
    // if (_isBrakingPreset && _locationService.currentSpeed < 3.0) {
    //   AppDialog.show(
    //     context,
    //     title: 'Braking Test Not Ready',
    //     message:
    //         'Start braking test only when the app is showing live GPS speed above 3 km/h.',
    //     type: DialogType.error,
    //   );
    //   _isStarting = false;
    //   return;
    // }
    final double confirmedSpeedBeforeReset = _locationService.confirmedSpeedKmh;
    final double displaySpeedBeforeReset = _locationService.displaySpeedKmh;
    final double brakingStartBeforeReset = _brakingStartSpeed;
    final DateTime runStartMoment = DateTime.now();

    _locationService.resetForNewRun();

    // Braking start speed must be captured exactly when user presses START.
    // Do not allow next GPS sample to redefine the braking start speed.
    if (_isBrakingPreset) {
      _currentSpeed = displaySpeedBeforeReset;
      _brakingStartSpeed = confirmedSpeedBeforeReset > 0.8
          ? confirmedSpeedBeforeReset
          : brakingStartBeforeReset;
      _brakingStartedAt = runStartMoment;
    }

    _lastServiceDistance = 0.0;

    setState(() {
      _isTimerRunning = true;
      _showTimerStatus = false;
      _currentSpeed = _isBrakingPreset ? displaySpeedBeforeReset : 0.0;
      _currentDistance = 0.0;
      _displayDistance = 0.0;
      _lastDistanceRenderAt = DateTime.now();
      _lastRunProgress = 0.0;
      _hasRunData = true;
      _gpsMovementWithoutSpeed = 0.0;
      _timerStartedAt = runStartMoment;
      if (_isBrakingPreset) {
        _isBraking = true;
        _brakingStartedAt = runStartMoment;
        _brakingDistance = 0.0;
        _brakingTime = 0.0;

        _currentSpeed = displaySpeedBeforeReset;

        _brakingStartSpeed = confirmedSpeedBeforeReset > 1.0
            ? confirmedSpeedBeforeReset
            : brakingStartBeforeReset;
      }
    });

    // Start performance session based on active tab and preset
    if (_activeTab == "SPEED") {
      final targetSpeed = _getTargetSpeedFromPreset(_selectedSpeedPreset);
      _performanceService.startSession(
        type: PerformanceType.speed,
        presetName: _selectedSpeedPreset,
        targetValue: targetSpeed,
        unit: _getSpeedUnit(),
      );
    } else if (_activeTab == "DISTANCE") {
      if (_selectedDistancePreset == "Braking") {
        _performanceService.startSession(
          type: PerformanceType.braking,
          presetName: "Braking",
          targetValue: _brakingStartSpeed,
          unit: _getSpeedUnit(),
        );
      } else {
        final targetDistance = _getTargetDistanceFromPreset(
          _selectedDistancePreset,
        );
        _performanceService.startSession(
          type: PerformanceType.distance,
          presetName: _selectedDistancePreset,
          targetValue: targetDistance,
          unit: "m",
        );
      }
    }

    if (_activeTab == "DISTANCE" && _selectedDistancePreset != "Braking") {
      _startDistanceDisplayTimer();
    }

    _isStarting = false;
  }

  Future<void> _stopTimer({
    bool saveAsCompleted = false,
    String notRecordedReason = 'Target was not reached.',
  }) async {
    if (!_isTimerRunning) return;

    _closeGpsWeakDialogIfOpen();
    _gpsWeakSince = null;

    _distanceDisplayTimer?.cancel();
    _distanceDisplayTimer = null;
    _lastDistanceRenderAt = null;

    _brakingAutoStopTimer?.cancel();
    _brakingAutoStopTimer = null;

    final t = ref.read(configProvider).translations;
    final bool targetReached = _performanceService.isTargetReached();
    final bool shouldSaveCompleted =
        saveAsCompleted || targetReached || _isBrakingPreset;

    final finalSpeed = _currentSpeed;
    final finalDistance = _currentDistance;
    final finalProgress = _getProgressValue();

    if (shouldSaveCompleted && _saveThisRun) {
      if (_isBrakingPreset) {
        _performanceService.updatePerformance(
          currentSpeed: _brakingStartSpeed,
          distanceDelta: 0.0,
          sampleTime: _locationService.lastGpsSampleTime,
        );
      }

      await _performanceService.completeSession();

      setState(() {
        _isTimerRunning = false;
        _showTimerStatus = true;
        _isBraking = false;
        _currentSpeed = _isBrakingPreset ? finalSpeed : 0.0;
        _currentDistance = finalDistance;
        _lastRunProgress = finalProgress;
        _hasRunData = true;

        if (_activeTab == "SPEED") {
          _timerStatus =
              '${t['target_reached'] ?? 'Target Reached!'} ${_targetSpeed.toInt()} ${_getSpeedUnit()}';
        } else if (_selectedDistancePreset == "Braking") {
          _timerStatus =
              '${t['braking_complete'] ?? 'Braking Complete!'} ${_brakingDistance.toStringAsFixed(1)} ${t['meters'] ?? 'm'} / ${_formatDurationSmart(_brakingTime)}';
        } else {
          _timerStatus =
              '${t['target_reached'] ?? 'Target Reached!'} ${_targetDistance.toInt()} ${t['meters'] ?? 'm'}';
        }
      });

      if (mounted) {
        _isBlockingDialogOpen = true;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1C),
              title: const Text(
                'History Saved',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: const Text(
                'This test result has been saved locally in your results history.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        _isBlockingDialogOpen = false;
      }

      return;
    }

    // Client requirement: do not invent/save a result when the target was not hit.
    _performanceService.reset();
    // _autoDistanceSessionStarted = false;
    setState(() {
      _isTimerRunning = false;
      _showTimerStatus = true;
      _isBraking = false;
      _currentSpeed = 0.0;
      _currentDistance = finalDistance;
      _lastRunProgress = finalProgress;
      _hasRunData = true;
      _timerStatus = 'Run not recorded: $notRecordedReason';
    });
  }

  double _getTargetSpeedFromPreset(String preset) {
    switch (preset) {
      case "0-60 mph":
        return 96.5604; // 60 mph in km/h
      case "0-60 km/h":
        return 60.0;
      case "0-100 km/h":
        return 100.0;
      case "0-100 mph":
        return 160.934; // 100 mph in km/h
      case "Debug 2 km/h":
        return 2.0;
      case "Debug 5 mph":
        return 8.04672; // 5 mph in km/h
      default:
        return 100.0;
    }
  }

  double _getTargetSpeedDisplayValue() {
    switch (_selectedSpeedPreset) {
      case "0-60 mph":
        return 60.0;
      case "0-60 km/h":
        return 60.0;
      case "0-100 km/h":
        return 100.0;
      case "0-100 mph":
        return 100.0;
      case "Debug 2 km/h":
        return 2.0;
      case "Debug 5 mph":
        return 5.0;
      default:
        return _targetSpeed;
    }
  }

  double _getTargetDistanceFromPreset(String preset) {
    switch (preset) {
      case "1/8 mile":
        return 201.0;
      case "1/4 mile":
        return 402.0;
      case "Debug 20 m":
        return 20.0;
      case "Braking":
        return 0.0;
      default:
        return 201.0;
    }
  }

  String _getSpeedUnit() {
    return _selectedSpeedPreset.contains("mph") ? "mph" : "km/h";
  }

  void _resetValues({bool clearRunData = true}) {
    final t = ref.read(configProvider).translations;

    _syncTargetsWithSelection();
    _gpsWeakSince = null;

    setState(() {
      _currentSpeed = 0.0;
      _currentDistance = 0.0;
      _displayDistance = 0.0;
      _lastDistanceRenderAt = null;
      _brakingDistance = 0.0;
      _brakingTime = 0.0;
      _brakingStartSpeed = 100.0;
      _timerStatus = t['timer_stopped'] ?? 'Timer Stopped!';
      _showTimerStatus = true;
      // _autoDistanceSessionStarted = false;
      _isCompletingRun = false;

      if (clearRunData) {
        _lastRunProgress = 0.0;
        _hasRunData = false;
      }
    });
  }

  bool _isInRedZone() => _currentSpeed >= 85;

  double _getProgressValue() {
    double value;

    if (_activeTab == "SPEED") {
      value = _targetSpeed > 0 ? _currentSpeed / _targetSpeed : 0.0;
    } else {
      if (_selectedDistancePreset == "Braking") {
        value = _brakingStartSpeed > 0
            ? 1 - (_currentSpeed / _brakingStartSpeed)
            : 0.0;
      } else {
        final distanceForProgress = _isTimerRunning
            ? _displayDistance
            : _currentDistance;

        value = _targetDistance > 0
            ? distanceForProgress / _targetDistance
            : 0.0;
      }
    }

    if (value.isNaN || value.isInfinite) return 0.0;
    return value.clamp(0.0, 1.0);
  }

  double _getDistanceHubDisplayValue() {
    // Preview mode: user is moving without pressing START.
    // This is not a real test, so it must not be limited by selected preset target.
    if (!_isTimerRunning && _activeTab == "DISTANCE" && !_isBrakingPreset) {
      return _displayDistance < 0 ? 0.0 : _displayDistance;
    }

    // Real test mode: clamp to target so completed tests don't visually overshoot.
    if (_activeTab == "DISTANCE" && !_isBrakingPreset) {
      return _displayDistance.clamp(0.0, _targetDistance);
    }

    return _displayDistance;
  }

  String _getProgressText() {
    final t = ref.read(configProvider).translations;

    if (_activeTab == "SPEED") {
      final currentKmh = _isTimerRunning || _hasRunData ? _currentSpeed : 0.0;
      final displayCurrent = _getSpeedUnit() == 'mph'
          ? currentKmh / 1.60934
          : currentKmh;

      return '${displayCurrent.toStringAsFixed(1)} / ${_getTargetSpeedDisplayValue().toInt()} ${_getSpeedUnit()}';
    }

    if (_selectedDistancePreset == "Braking") {
      final startSpeed = _brakingStartSpeed.clamp(0.0, 999.0);
      final currentSpeed = _currentSpeed.clamp(0.0, 999.0);
      return '${startSpeed.toStringAsFixed(1)} → ${currentSpeed.toStringAsFixed(1)} ${_getSpeedUnit()} • ${_formatDurationSmart(_brakingTime)}';
    }

    final bool isPreviewOnly =
        !_isTimerRunning && _activeTab == "DISTANCE" && !_isBrakingPreset;

    final currentDistance = isPreviewOnly
        ? _currentDistance.clamp(0.0, double.infinity)
        : (_isTimerRunning ? _displayDistance : _currentDistance).clamp(
            0.0,
            _targetDistance,
          );

    return isPreviewOnly
        ? '${currentDistance.toStringAsFixed(1)} ${t['meters'] ?? 'm'} preview'
        : '${currentDistance.toStringAsFixed(1)} / ${_targetDistance.toInt()} ${t['meters'] ?? 'm'}';
  }

  Widget _buildGpsDebugOverlay() {
    if (!_showGpsDebugOverlay) return const SizedBox.shrink();

    final confirmedKmh = _locationService.confirmedSpeedKmh;
    final displayKmh = _locationService.displaySpeedKmh;
    final rawNativeKmh = _locationService.rawNativeSpeedKmh;

    final speedDisplay = _getSpeedUnit() == 'mph'
        ? displayKmh / 1.60934
        : displayKmh;

    return Positioned(
      top: 8,
      right: 8,
      child: IgnorePointer(
        child: Container(
          width: 190,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.72),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 9,
              height: 1.25,
              fontFamily: 'monospace',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GPS DEBUG'),
                Text(
                  'speed: ${speedDisplay.toStringAsFixed(1)} ${_getSpeedUnit()}',
                ),
                Text('display km/h: ${displayKmh.toStringAsFixed(1)}'),
                Text('confirmed km/h: ${confirmedKmh.toStringAsFixed(1)}'),
                Text('raw native km/h: ${rawNativeKmh.toStringAsFixed(1)}'),
                Text('interval: ${_locationService.lastGpsIntervalMs}ms'),
                Text('sample age: ${_locationService.lastGpsSampleAgeMs}ms'),
                Text(
                  'accuracy: ${_locationService.lastGpsAccuracy.toStringAsFixed(0)}m',
                ),
                Text(
                  'move: ${_locationService.lastGpsMoveDistance.toStringAsFixed(1)}m',
                ),
                Text('updates: ${_locationService.gpsUpdateCount}'),
                Text('ready: ${_locationService.isReadyForTest}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(configProvider).translations;
    final bool isBrakingPreset =
        _activeTab == "DISTANCE" && _selectedDistancePreset == "Braking";

    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false;
        }

        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            // Timer Tab Content
            Stack(
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(t),
                        const SizedBox(height: 8),
                        _buildTabContainer(t),
                        const SizedBox(height: 12),
                        _activeTab == "SPEED"
                            ? _buildSpeedPresets(t)
                            : _buildDistancePresets(t),
                        Expanded(
                          flex: isBrakingPreset ? 5 : 4,
                          child: Center(
                            child: _buildSpeedometerWithHub(t, isBrakingPreset),
                          ),
                        ),
                        _buildTimerStatusSection(t),
                        const SizedBox(height: 6),
                        _buildActionButtons(t),
                        const SizedBox(height: 10),
                        _buildNavigationGrid(t),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                if (_showGpsDebugOverlay) _buildGpsDebugOverlay(),
              ],
            ),
            const PreferencesScreen(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(t),
      ),
    );
  }

  Widget _buildHeader(Map<String, String> t) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t['app_title'] ?? "DE 0-100 Timer",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t['mounting_msg'] ?? "",
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContainer(Map<String, String> t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          _tabItem(t['tab_speed'] ?? "SPEED", "SPEED"),
          _tabItem(t['tab_distance'] ?? "Distance", "DISTANCE"),
        ],
      ),
    );
  }

  Widget _tabItem(String label, String tabValue) {
    bool isSelected = _activeTab == tabValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_blockNavigationDuringRun()) {
            return;
          }

          _activeTab = tabValue;
          _resetValues(clearRunData: true);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white30,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 2,
              width: 80,
              color: isSelected ? Colors.red : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedPresets(Map<String, String> t) {
    final List<Map<String, String>> modes = [
      {'id': '0-60 mph', 'label': t['preset_0_60_mph'] ?? '0-60 mph'},
      {'id': '0-60 km/h', 'label': t['preset_0_60_kmh'] ?? '0-60 km/h'},
      {'id': '0-100 km/h', 'label': t['preset_0_100_kmh'] ?? '0-100 km/h'},
      {'id': '0-100 mph', 'label': t['preset_0_100_mph'] ?? '0-100 mph'},
      // Debug-only test presets. These appear only in debug mode, not release APK.
      if (!const bool.fromEnvironment('dart.vm.product'))
        {'id': 'Debug 2 km/h', 'label': 'Debug 2 km/h'},
      if (!const bool.fromEnvironment('dart.vm.product'))
        {'id': 'Debug 5 mph', 'label': 'Debug 5 mph'},
    ];

    return Row(
      children: modes.map((mode) {
        bool isActive = _selectedSpeedPreset == mode['id'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                if (_blockNavigationDuringRun()) {
                  return;
                }

                _selectedSpeedPreset = mode['id']!;
                _syncTargetsWithSelection();
                _resetValues(clearRunData: true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? Colors.red : const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  mode['label']!,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDistancePresets(Map<String, String> t) {
    final List<Map<String, dynamic>> modes = [
      {
        'id': '1/8 mile',
        'value': t['preset_1_8_mile'] ?? '1/8 mile',
        'range': '(0–201 ${t['meters'] ?? 'm'})',
      },
      {
        'id': '1/4 mile',
        'value': t['preset_1_4_mile'] ?? '1/4 mile',
        'range': '(0–402 ${t['meters'] ?? 'm'})',
      },
      {
        'id': 'Braking',
        'value': t['braking'] ?? 'Braking',
        'range': t['stopping_distance'] ?? 'Stopping Distance',
      },
      if (!const bool.fromEnvironment('dart.vm.product'))
        {'id': 'Debug 20 m', 'value': 'Debug 20 m', 'range': '(0–20 m)'},
    ];

    return Column(
      children: [
        Row(
          children: modes.map((mode) {
            bool isActive = _selectedDistancePreset == mode['id'];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    if (_blockNavigationDuringRun()) {
                      return;
                    }

                    _selectedDistancePreset = mode['id'];
                    _syncTargetsWithSelection();
                    _resetValues(clearRunData: true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.red : const Color(0xFF1C1C1C),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      mode['value'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        if (_selectedDistancePreset != 'Braking')
          Text(
            modes.firstWhere(
              (m) => m['id'] == _selectedDistancePreset,
            )['range'],
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
      ],
    );
  }

  Widget _buildSpeedometerWithHub(Map<String, String> t, bool isBrakingPreset) {
    double gaugeSize = isBrakingPreset ? 360 : 380;
    double hubSize = isBrakingPreset ? 115 : 125;
    double fontSize = isBrakingPreset ? 38 : 44;
    double smallFontSize = isBrakingPreset ? 12 : 14;

    return SizedBox(
      width: gaugeSize,
      height: gaugeSize * 0.7,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: SpeedometerPainter(
                speed:
                    (_isTimerRunning ||
                        isBrakingPreset ||
                        _shouldPreviewLiveSpeedInSpeedTab)
                    ? _currentSpeed
                    : 0.0,
                maxSpeed: _maxSpeed,
                isRunning: _isTimerRunning,
                isInRedZone: _activeTab == "SPEED" ? _isInRedZone() : false,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.78),
            child: Container(
              width: hubSize,
              height: hubSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _activeTab == "SPEED"
                  ? _buildSpeedHubContent(fontSize, smallFontSize)
                  : _buildDistanceHubContent(t, fontSize, smallFontSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedHubContent(double fontSize, double smallFontSize) {
    final rawSpeedKmh = (_isTimerRunning || _shouldPreviewLiveSpeedInSpeedTab)
        ? _currentSpeed
        : 0.0;

    final displaySpeed = _getSpeedUnit() == 'mph'
        ? rawSpeedKmh / 1.60934
        : rawSpeedKmh;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          displaySpeed < 10
              ? displaySpeed.toStringAsFixed(1)
              : displaySpeed.toInt().toString(),
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
        Text(
          _getSpeedUnit(),
          style: TextStyle(
            color: Colors.black,
            fontSize: smallFontSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildDistanceHubContent(
    Map<String, String> t,
    double fontSize,
    double smallFontSize,
  ) {
    if (_selectedDistancePreset == "Braking") {
      return Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${_currentSpeed.toInt()}",
              style: TextStyle(
                color: Colors.black,
                fontSize: fontSize - 4,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            Text(
              _getSpeedUnit(),
              style: TextStyle(
                color: Colors.black,
                fontSize: smallFontSize - 2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Container(width: 60, height: 1, color: Colors.black12),
            const SizedBox(height: 2),
            Text(
              '${_brakingStartSpeed.toInt()} → 0',
              style: TextStyle(
                color: Colors.black54,
                fontSize: smallFontSize - 3,
              ),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${_getDistanceHubDisplayValue().toInt()}",
              style: TextStyle(
                color: Colors.black,
                fontSize: fontSize - 4,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            Text(
              t['meters'] ?? 'm',
              style: TextStyle(
                color: Colors.black,
                fontSize: smallFontSize - 2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Container(width: 60, height: 1, color: Colors.black12),
            const SizedBox(height: 2),
            Text(
              '${_targetDistance.toInt()} ${t['meters'] ?? 'm'}',
              style: TextStyle(
                color: Colors.black54,
                fontSize: smallFontSize - 3,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTimerStatusSection(Map<String, String> t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showTimerStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              _timerStatus,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        if (_activeTab == "DISTANCE" &&
            _selectedDistancePreset == "Braking" &&
            !_isTimerRunning)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              t['braking_from_current'] ?? 'Braking : From current speed to 0',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        if (_activeTab == "DISTANCE" &&
            _selectedDistancePreset == "Braking" &&
            !_isTimerRunning &&
            _brakingDistance > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_left,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${_brakingDistance.toStringAsFixed(1)} ${t['meters'] ?? 'm'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDurationSmart(_brakingTime),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_right,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (_isTimerRunning || _hasRunData)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: _isTimerRunning
                      ? _getProgressValue()
                      : _lastRunProgress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  minHeight: 2,
                ),
                const SizedBox(height: 2),
                Text(
                  _getProgressText(),
                  style: const TextStyle(color: Colors.white54, fontSize: 8),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _buildSpeedSourceLabel(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Map<String, String> t) {
    final bool gpsReady = _locationService.isReadyForTest;

    final String label;
    final Color color;
    final VoidCallback? action;

    if (_isTimerRunning) {
      label = t['btn_stop'] ?? "STOP";
      color = Colors.red;
      action = _stopTimer;
    } else if (!gpsReady) {
      label = "WAITING GPS";
      color = Colors.grey;
      action = null;
    } else if (_isBrakingPreset) {
      if (_canStartBrakingRun) {
        label = "START BRAKING";
        color = Colors.deepOrange;
        action = _confirmManualStartRun;
      } else {
        label = "MOVE CAR FOR BRAKING TEST";
        color = Colors.grey;
        action = null;
      }
    } else if (_shouldBlockStartBecauseMoving) {
      label = "STOP CAR FIRST";
      color = Colors.grey;
      action = null;
    } else {
      label = t['btn_start'] ?? "START";
      color = Colors.deepOrange;
      action = _confirmManualStartRun;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(children: [_actionBtn(label, color, action)]),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback? onTap) {
    return Expanded(
      child: Material(
        color: color.withOpacity(onTap == null ? 0.5 : 1.0),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationGrid(Map<String, String> t) {
    if (_activeTab == "DISTANCE" && _selectedDistancePreset == "Braking") {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _gridBtn(
                Icons.list,
                t['btn_results'] ?? "RESULTS",
                onTap: () {
                  if (_blockNavigationDuringRun()) {
                    return;
                  }

                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ResultsScreen()),
                  );
                },
              ),
              const SizedBox(width: 8),
              _gridBtn(
                Icons.bar_chart,
                t['btn_leaderboard'] ?? "LEADERBOARD",
                onTap: () {
                  if (_blockNavigationDuringRun()) {
                    return;
                  }
                  AppDialog.show(
                    context,
                    title: t['btn_leaderboard'] ?? 'Leaderboard',
                    message: t['under_development'] ?? 'Under Development',
                    type: DialogType.info,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _gridBtn(
                Icons.history,
                t['nav_timer'] ?? "Timer",
                onTap: () {
                  if (_blockNavigationDuringRun()) {
                    return;
                  }
                  AppDialog.show(
                    context,
                    title: t['nav_timer'] ?? 'Timer',
                    message: t['under_development'] ?? 'Under Development',
                    type: DialogType.info,
                  );
                },
              ),
              const SizedBox(width: 8),
              _gridBtn(
                Icons.help_outline,
                t['help'] ?? "HELP",
                onTap: () {
                  if (_blockNavigationDuringRun()) {
                    return;
                  }
                  AppDialog.show(
                    context,
                    title: t['help'] ?? 'Help',
                    message: t['under_development'] ?? 'Under Development',
                    type: DialogType.info,
                  );
                },
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _gridBtn(
          Icons.list,
          t['btn_results'] ?? "RESULTS",
          isFullWidth: true,
          onTap: () {
            if (_blockNavigationDuringRun()) {
              return;
            }

            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ResultsScreen()));
          },
        ),
        const SizedBox(height: 6),
        _gridBtn(
          Icons.bar_chart,
          t['btn_leaderboard'] ?? "LEADERBOARD",
          isFullWidth: true,
          onTap: () {
            if (_blockNavigationDuringRun()) {
              return;
            }
            AppDialog.show(
              context,
              title: t['btn_leaderboard'] ?? 'Leaderboard',
              message: t['under_development'] ?? 'Under Development',
              type: DialogType.info,
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _gridBtn(
              Icons.history,
              t['nav_timer'] ?? "Timer",
              onTap: () {
                if (_blockNavigationDuringRun()) {
                  return;
                }
                AppDialog.show(
                  context,
                  title: t['nav_timer'] ?? 'Timer',
                  message: t['under_development'] ?? 'Under Development',
                  type: DialogType.info,
                );
              },
            ),
            const SizedBox(width: 6),
            _gridBtn(
              Icons.help_outline,
              t['help'] ?? "HELP",
              onTap: () {
                if (_blockNavigationDuringRun()) {
                  return;
                }
                AppDialog.show(
                  context,
                  title: t['help'] ?? 'Help',
                  message: t['under_development'] ?? 'Under Development',
                  type: DialogType.info,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _gridBtn(
    IconData icon,
    String label, {
    bool isFullWidth = false,
    VoidCallback? onTap,
  }) {
    Widget content = Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (isFullWidth) {
      return InkWell(onTap: onTap, child: content);
    } else {
      return Expanded(
        child: InkWell(onTap: onTap, child: content),
      );
    }
  }

  Widget _buildBottomNav(Map<String, String> t) {
    return BottomNavigationBar(
      selectedItemColor: Colors.red,
      unselectedItemColor: Colors.white,
      currentIndex: _selectedIndex,
      onTap: (index) {
        if (index == _selectedIndex) {
          return;
        }

        if (_blockNavigationDuringRun()) {
          return;
        }

        setState(() {
          _selectedIndex = index;
        });
      },
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.timer),
          label: t['nav_timer'] ?? "Timer",
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.tune),
          label: t['nav_preference'] ?? "Preference",
        ),
      ],
    );
  }

  Widget _buildSpeedSourceLabel() {
    final source = _locationService.speedSource;
    final accuracy = _locationService.lastGpsAccuracy;

    Color sourceColor;
    String label;

    if (source == 'GPS' || source == 'Native GPS') {
      sourceColor = Colors.greenAccent;
      label = accuracy < 999
          ? 'Source: $source  •  Accuracy: ${accuracy.toStringAsFixed(0)}m'
          : 'Source: $source';
    } else if (source == 'GPS Weak' || source == 'GPS Verifying') {
      sourceColor = Colors.orangeAccent;
      label = accuracy < 999
          ? 'Source: $source  •  Accuracy: ${accuracy.toStringAsFixed(0)}m'
          : 'Source: $source';
    } else {
      sourceColor = Colors.white38;
      label = 'Source: Idle';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: sourceColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _locationService.isReadyForTest
                  ? 'GPS Ready • Accuracy ${_locationService.lastGpsAccuracy.toStringAsFixed(0)}m'
                  : _locationService.gpsSignalMessage,
              style: TextStyle(
                color: _locationService.isReadyForTest
                    ? Colors.green
                    : Colors.orange,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showWarning(Map<String, String> t) {
    AppDialog.show(
      context,
      title: t['stop_timer_first'] ?? 'Please stop the timer first',
      message: '',
      type: DialogType.error,
    );
  }
}

class SpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final bool isRunning;
  final bool isInRedZone;

  SpeedometerPainter({
    required this.speed,
    required this.maxSpeed,
    required this.isRunning,
    required this.isInRedZone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width * 0.44;
    final hubRadius = 57.5;

    final double startAngle = math.pi;
    final double sweepAngle = math.pi;

    final trackPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    final redBlockPaint = Paint()
      ..color = const Color(0xFFFF3B30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.butt;

    double redZoneStartPercent = 85 / maxSpeed;
    double redZoneEndPercent = 100 / maxSpeed;
    double redZoneStartAngle = startAngle + (redZoneStartPercent * sweepAngle);
    double redZoneSweepAngle =
        (redZoneEndPercent - redZoneStartPercent) * sweepAngle;

    canvas.drawArc(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
      redZoneStartAngle,
      redZoneSweepAngle,
      false,
      redBlockPaint,
    );

    for (int i = 0; i <= 100; i += 5) {
      double percent = i / maxSpeed;
      double angle = startAngle + (percent * sweepAngle);
      bool isLargeTick = i % 10 == 0;
      Color tickColor = i >= 85 ? const Color(0xFFFF3B30) : Colors.white;

      final tickPaint = Paint()
        ..color = tickColor
        ..strokeWidth = isLargeTick ? 4 : 2;

      double innerR = isLargeTick ? radius - 15 : radius - 8;
      double outerR = radius + 5;

      Offset p1 =
          center + Offset(math.cos(angle) * innerR, math.sin(angle) * innerR);
      Offset p2 =
          center + Offset(math.cos(angle) * outerR, math.sin(angle) * outerR);
      canvas.drawLine(p1, p2, tickPaint);

      if (i == 0 || i % 10 == 0 || i == 100) {
        double labelRadius = isLargeTick ? radius - 28 : radius - 24;
        _drawLabel(canvas, center, angle, labelRadius, i.toString(), tickColor);
      } else if (i % 5 == 0) {
        _drawLabel(
          canvas,
          center,
          angle,
          radius - 28,
          i.toString(),
          tickColor.withOpacity(0.8),
        );
      }
    }

    Color needleColor;
    if (isInRedZone) {
      needleColor = const Color(0xFFFF3B30);
    } else if (isRunning) {
      needleColor = Colors.white;
    } else {
      needleColor = Colors.grey;
    }

    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    double safeSpeed = speed > maxSpeed ? maxSpeed : speed;
    double percent = safeSpeed / maxSpeed;
    double needleAngle = startAngle + (percent * sweepAngle);

    Offset needleStart =
        center +
        Offset(
          math.cos(needleAngle) * hubRadius,
          math.sin(needleAngle) * hubRadius,
        );
    Offset needleEnd =
        center +
        Offset(
          math.cos(needleAngle) * (radius - 18),
          math.sin(needleAngle) * (radius - 18),
        );
    canvas.drawLine(needleStart, needleEnd, needlePaint);

    final baseCirclePaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6, baseCirclePaint);

    if (isRunning && isInRedZone) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFF3B30).withOpacity(0.3)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawLine(needleStart, needleEnd, glowPaint);
    }
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    double angle,
    double r,
    String text,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    Offset pos = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant SpeedometerPainter old) {
    return old.speed != speed ||
        old.isRunning != isRunning ||
        old.isInRedZone != isInRedZone;
  }
}
