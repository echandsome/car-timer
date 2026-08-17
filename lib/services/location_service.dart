import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  Position? _currentPosition;

  // Confirmed speed is the trusted GPS/native speed used for test logic/results.
  double _currentSpeed = 0.0; // km/h
  double _confirmedSpeedKmh = 0.0; // km/h

  // Display speed is UI-only smoothing for hub/needle responsiveness.
  // Never use this for result saving or target completion.
  double _displaySpeedKmh = 0.0;
  double _displayTargetSpeedKmh = 0.0;
  Timer? _displaySmoothingTimer;

  double _totalDistance = 0.0; // meters
  final List<Position> _positionHistory = [];

  Position? _lastPositionForMovement;

  StreamSubscription<Position>? _positionStream;
  static const EventChannel _nativeGpsChannel = EventChannel(
    'car_timer/native_gps',
  );

  StreamSubscription<dynamic>? _nativeGpsSubscription;

  double? _lastNativeLatitude;
  double? _lastNativeLongitude;
  DateTime? _lastNativeUpdate;
  int _nativeGpsUpdateCount = 0;

  bool _isTracking = false;
  bool _hasPermission = false;
  bool _isServiceEnabled = false;

  DateTime? _lastGpsUpdate;

  // Real sample timestamp from Android/Fused GPS when available.
  // Used for better target-crossing interpolation in PerformanceService.
  DateTime? _lastGpsSampleTime;
  double _lastGpsSpeedKmh = 0.0;
  double _lastPlatformSpeedKmh = 0.0;
  double _rawNativeSpeedKmh = 0.0;
  double _lastGpsMoveDistance = 0.0;
  double _lastGpsAccuracy = 9999.0;
  String _speedSource = 'Idle';
  DateTime? _lastPositionReceivedAt;
  int _gpsUpdateCount = 0;
  int _lastGpsIntervalMs = 0;
  int _lastGpsSampleAgeMs = 0;
  int _gpsReadySamples = 0;
  int _movingSamples = 0;
  double _maxTrustedSpeedKmh = 0.0;

  static const double strongGpsAccuracyMeters = 35.0;
  static const double testGpsAccuracyMeters = 20.0;

  // 0.8 km/h se neeche phone GPS noise bohat hota hai.
  static const double minTrustedPlatformSpeedKmh = 0.8;

  static const int freshGpsSeconds = 4;

  int get gpsUpdateCount => _gpsUpdateCount;
  int get lastGpsIntervalMs => _lastGpsIntervalMs;
  int get lastGpsSampleAgeMs => _lastGpsSampleAgeMs;
  DateTime? get lastPositionReceivedAt => _lastPositionReceivedAt;

  Position? get currentPosition => _currentPosition;

  // Existing getter remains confirmed speed so old test logic does not accidentally use smoothed UI speed.
  double get currentSpeed => _currentSpeed;

  double get confirmedSpeedKmh => _confirmedSpeedKmh;
  double get displaySpeedKmh => _displaySpeedKmh;
  double get rawNativeSpeedKmh => _rawNativeSpeedKmh;

  double get totalDistance => _totalDistance;
  List<Position> get positionHistory => List.unmodifiable(_positionHistory);

  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  bool get isServiceEnabled => _isServiceEnabled;

  bool get isUsingMotionFallback => false;

  String get speedSource => _speedSource;
  bool get isUsingGps => _speedSource == 'GPS' || _speedSource == 'Native GPS';
  double get lastGpsAccuracy => _lastGpsAccuracy;
  double get lastGpsSpeedKmh => _lastGpsSpeedKmh;
  double get lastPlatformSpeedKmh => _lastPlatformSpeedKmh;
  double get lastGpsMoveDistance => _lastGpsMoveDistance;
  DateTime? get lastGpsUpdate => _lastGpsUpdate;
  DateTime? get lastGpsSampleTime => _lastGpsSampleTime;

  bool get hasFreshGpsUpdate {
    if (_lastGpsUpdate == null) return false;
    return DateTime.now().difference(_lastGpsUpdate!).inSeconds <=
        freshGpsSeconds;
  }

  bool get isGpsSignalStrong {
    return hasFreshGpsUpdate && _lastGpsAccuracy <= strongGpsAccuracyMeters;
  }

  bool get isGpsSignalWeak {
    if (!_isTracking) return false;
    return !isGpsSignalStrong;
  }

  bool get isReadyForTest {
    if (!_isTracking) return false;
    if (!hasFreshGpsUpdate) return false;
    if (_lastGpsAccuracy > testGpsAccuracyMeters) return false;

    // 1 sample enough rakha hai taake user ko 10–20 sec wait na karna paray.
    return _gpsReadySamples >= 1;
  }

  bool get hasTrustedSpeed {
    return (_speedSource == 'GPS' || _speedSource == 'Native GPS') &&
        _lastGpsSpeedKmh >= minTrustedPlatformSpeedKmh;
  }

  String get gpsSignalMessage {
    if (!_isServiceEnabled) {
      return 'Location services are turned off.';
    }

    if (!_hasPermission) {
      return 'Location permission is not granted.';
    }

    if (_lastGpsUpdate == null) {
      return 'Waiting for GPS signal. Move to an open sky area.';
    }

    if (!hasFreshGpsUpdate) {
      return 'GPS signal is stale. Move to an open sky area.';
    }

    if (_lastGpsAccuracy > strongGpsAccuracyMeters) {
      return 'GPS signal is weak. Accuracy is ${_lastGpsAccuracy.toStringAsFixed(0)}m. Move to open sky for accurate measurement.';
    }

    return 'GPS signal is strong.';
  }

  Future<bool> initialize() async {
    try {
      _isServiceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!_isServiceEnabled) {
        debugPrint('Location services are disabled');
        _hasPermission = false;
        notifyListeners();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          _hasPermission = false;
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        _hasPermission = false;
        notifyListeners();
        return false;
      }

      _hasPermission = true;
      debugPrint('Location service initialized successfully');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error initializing location service: $e');
      _hasPermission = false;
      notifyListeners();
      return false;
    }
  }

  void startTracking() {
    if (_isTracking) return;
    if (!_hasPermission) return;

    _resetLiveValues(clearGpsSignal: true);

    _isTracking = true;
    _startDisplaySmoothingTimer();
    _startGpsTracking();

    debugPrint('GPS-only location tracking started');
    notifyListeners();
  }

  void _startDisplaySmoothingTimer() {
    _displaySmoothingTimer?.cancel();

    _displaySmoothingTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _tickDisplaySpeed(),
    );
  }

  void _tickDisplaySpeed() {
    final bool gpsFresh = hasFreshGpsUpdate;
    final double target = gpsFresh ? _displayTargetSpeedKmh : 0.0;

    double nextDisplaySpeed;

    if (target <= 0.05) {
      // Fast decay prevents the UI from feeling stuck at old speed after stop.
      nextDisplaySpeed = _displaySpeedKmh * 0.35;

      if (nextDisplaySpeed < 0.25) {
        nextDisplaySpeed = 0.0;
      }
    } else {
      final double delta = target - _displaySpeedKmh;

      // Faster response when accelerating, stronger decay when slowing.
      final double factor = delta >= 0 ? 0.45 : 0.65;
      nextDisplaySpeed = _displaySpeedKmh + (delta * factor);

      if (nextDisplaySpeed < 0.25) {
        nextDisplaySpeed = 0.0;
      }
    }

    if ((nextDisplaySpeed - _displaySpeedKmh).abs() < 0.03) {
      return;
    }

    _displaySpeedKmh = nextDisplaySpeed;
    notifyListeners();
  }

  void _startGpsTracking() {
    _nativeGpsSubscription?.cancel();
    _positionStream?.cancel();

    _nativeGpsSubscription = _nativeGpsChannel.receiveBroadcastStream().listen(
      _updateLocationFromNativeGps,
      onError: (error) {
        debugPrint('Native GPS stream error: $error');
        _startGeolocatorFallbackTracking();
      },
      cancelOnError: false,
    );

    debugPrint('Native high-frequency GPS tracking requested');
  }

  void _startGeolocatorFallbackTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStream?.cancel();
    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          _updateLocationFromGps,
          onError: (error) {
            debugPrint('GPS stream error: $error');
            _setConfirmedSpeed(0.0);
            _speedSource = 'GPS Weak';
            notifyListeners();
          },
          cancelOnError: false,
        );

    debugPrint('Fallback Geolocator GPS tracking started');
  }

  void _updateLocationFromNativeGps(dynamic event) {
    if (event is! Map) return;

    final now = DateTime.now();

    final latitude = (event['latitude'] as num?)?.toDouble();
    final longitude = (event['longitude'] as num?)?.toDouble();
    final accuracy = (event['accuracy'] as num?)?.toDouble() ?? 9999.0;

    final hasSpeed = event['hasSpeed'] == true;
    final speedMps = (event['speedMps'] as num?)?.toDouble() ?? 0.0;

    final hasSpeedAccuracy = event['hasSpeedAccuracy'] == true;
    final speedAccuracyMps = (event['speedAccuracyMps'] as num?)?.toDouble();

    final timeMillis = (event['timeMillis'] as num?)?.toInt();

    if (latitude == null || longitude == null) return;

    final intervalMs = _lastNativeUpdate == null
        ? 0
        : now.difference(_lastNativeUpdate!).inMilliseconds;

    _lastNativeUpdate = now;
    _nativeGpsUpdateCount++;

    _lastGpsUpdate = now;
    _lastPositionReceivedAt = now;
    _lastGpsIntervalMs = intervalMs;
    _lastGpsAccuracy = accuracy;

    if (timeMillis != null && timeMillis > 0) {
      _lastGpsSampleTime = DateTime.fromMillisecondsSinceEpoch(timeMillis);
      _lastGpsSampleAgeMs = now.difference(_lastGpsSampleTime!).inMilliseconds;
    } else {
      _lastGpsSampleTime = now;
      _lastGpsSampleAgeMs = 0;
    }

    final bool gpsPositionOk = _lastGpsAccuracy <= testGpsAccuracyMeters;

    if (gpsPositionOk) {
      _gpsReadySamples++;
      if (_gpsReadySamples > 5) _gpsReadySamples = 5;
    } else {
      _gpsReadySamples = 0;
    }

    double positionMoveDistance = 0.0;

    if (_lastNativeLatitude != null && _lastNativeLongitude != null) {
      positionMoveDistance = Geolocator.distanceBetween(
        _lastNativeLatitude!,
        _lastNativeLongitude!,
        latitude,
        longitude,
      );
    }

    _lastNativeLatitude = latitude;
    _lastNativeLongitude = longitude;

    final bool speedAccuracyOk =
        !hasSpeedAccuracy ||
        speedAccuracyMps == null ||
        speedAccuracyMps <= 2.5;

    final bool speedSampleUsable = hasSpeed && speedAccuracyOk;

    final platformSpeedKmh = speedSampleUsable
        ? math.max(0.0, speedMps * 3.6)
        : 0.0;

    final bool trustedSpeedSampleOk = gpsPositionOk && speedSampleUsable;

    _rawNativeSpeedKmh = platformSpeedKmh;
    _lastPlatformSpeedKmh = platformSpeedKmh;
    _lastGpsMoveDistance = positionMoveDistance;

    if (!gpsPositionOk) {
      _setConfirmedSpeed(0.0);
      _movingSamples = 0;
      _speedSource = 'GPS Weak';
    } else if (!trustedSpeedSampleOk ||
        platformSpeedKmh < minTrustedPlatformSpeedKmh) {
      _setConfirmedSpeed(0.0);
      _movingSamples = 0;
      _speedSource = 'Native GPS';
    } else {
      _movingSamples++;

      final acceptedSpeed = _filterPlatformSpeed(platformSpeedKmh);

      _setConfirmedSpeed(acceptedSpeed);
      _speedSource = 'Native GPS';

      if (acceptedSpeed > _maxTrustedSpeedKmh) {
        _maxTrustedSpeedKmh = acceptedSpeed;
      }
    }

    if (trustedSpeedSampleOk &&
        _confirmedSpeedKmh >= minTrustedPlatformSpeedKmh &&
        positionMoveDistance >= 0 &&
        positionMoveDistance < 80) {
      _totalDistance += positionMoveDistance;
    }

    debugPrint(
      'Native GPS update #$_nativeGpsUpdateCount | '
      'interval: ${intervalMs}ms | '
      'age: ${_lastGpsSampleAgeMs}ms | '
      'hasSpeed: $hasSpeed | '
      'speedAcc: ${speedAccuracyMps?.toStringAsFixed(2) ?? 'n/a'} m/s | '
      'platform: ${platformSpeedKmh.toStringAsFixed(1)} km/h | '
      'confirmed: ${_confirmedSpeedKmh.toStringAsFixed(1)} km/h | '
      'display: ${_displaySpeedKmh.toStringAsFixed(1)} km/h | '
      'accuracy: ${_lastGpsAccuracy.toStringAsFixed(0)}m | '
      'moved: ${positionMoveDistance.toStringAsFixed(1)}m | '
      'source: $_speedSource',
    );

    notifyListeners();
  }

  void stopTracking() {
    if (!_isTracking) return;

    _nativeGpsSubscription?.cancel();
    _nativeGpsSubscription = null;

    _positionStream?.cancel();
    _positionStream = null;

    _displaySmoothingTimer?.cancel();
    _displaySmoothingTimer = null;

    _isTracking = false;
    _setConfirmedSpeed(0.0);
    _displaySpeedKmh = 0.0;
    _displayTargetSpeedKmh = 0.0;
    _speedSource = 'Idle';
    _gpsReadySamples = 0;
    _movingSamples = 0;

    debugPrint('GPS-only location tracking stopped');
    notifyListeners();
  }

  void resetForNewRun() {
    _positionHistory.clear();
    _lastPositionForMovement = null;
    _lastGpsSampleTime = null;
    _lastNativeLatitude = null;
    _lastNativeLongitude = null;

    _totalDistance = 0.0;
    _lastGpsMoveDistance = 0.0;
    _lastGpsSpeedKmh = 0.0;
    _lastGpsIntervalMs = 0;
    _lastGpsSampleAgeMs = 0;
    _lastPlatformSpeedKmh = 0.0;
    _rawNativeSpeedKmh = 0.0;
    _setConfirmedSpeed(0.0);
    _maxTrustedSpeedKmh = 0.0;
    _movingSamples = 0;

    // GPS readiness clear nahi karni. Warna START ke baad fake waiting state ban jati hai.
    notifyListeners();
  }

  void _resetLiveValues({required bool clearGpsSignal}) {
    _currentPosition = null;
    _lastPositionForMovement = null;
    _lastGpsSampleTime = null;
    _setConfirmedSpeed(0.0);
    _displaySpeedKmh = 0.0;
    _displayTargetSpeedKmh = 0.0;

    _totalDistance = 0.0;
    _positionHistory.clear();

    _lastGpsSpeedKmh = 0.0;
    _lastPlatformSpeedKmh = 0.0;
    _rawNativeSpeedKmh = 0.0;
    _lastGpsMoveDistance = 0.0;
    _maxTrustedSpeedKmh = 0.0;
    _gpsReadySamples = 0;
    _movingSamples = 0;
    _speedSource = 'Idle';
    _lastPositionReceivedAt = null;
    _lastNativeUpdate = null;
    _nativeGpsUpdateCount = 0;
    _gpsUpdateCount = 0;
    _lastGpsIntervalMs = 0;
    _lastGpsSampleAgeMs = 0;
    _lastNativeLatitude = null;
    _lastNativeLongitude = null;

    if (clearGpsSignal) {
      _lastGpsUpdate = null;
      _lastGpsAccuracy = 9999.0;
    }
  }

  Future<Position?> getCurrentLocation() async {
    try {
      if (!_hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 6),
      );

      _updateLocationFromGps(position);
      return position;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  double calculateDistance(Position start, Position end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  void _updateLocationFromGps(Position newPosition) {
    final now = DateTime.now();

    if (_lastPositionReceivedAt != null) {
      _lastGpsIntervalMs = now
          .difference(_lastPositionReceivedAt!)
          .inMilliseconds;
    } else {
      _lastGpsIntervalMs = 0;
    }

    _lastPositionReceivedAt = now;
    _gpsUpdateCount++;

    final gpsTimestamp = newPosition.timestamp;
    _lastGpsSampleAgeMs = gpsTimestamp == null
        ? 0
        : now.difference(gpsTimestamp).inMilliseconds;
    _lastGpsSampleTime = gpsTimestamp ?? now;

    _lastGpsUpdate = now;
    _lastGpsAccuracy = newPosition.accuracy;
    final bool gpsSampleOk = _lastGpsAccuracy <= testGpsAccuracyMeters;

    if (gpsSampleOk) {
      _gpsReadySamples++;
      if (_gpsReadySamples > 5) _gpsReadySamples = 5;
    } else {
      _gpsReadySamples = 0;
    }

    double positionMoveDistance = 0.0;

    if (_currentPosition != null) {
      final previousPosition = _currentPosition!;
      positionMoveDistance = calculateDistance(previousPosition, newPosition);
      _lastPositionForMovement = previousPosition;
    }

    _currentPosition = newPosition;

    final platformSpeedKmh = math.max(0.0, newPosition.speed * 3.6);

    _lastPlatformSpeedKmh = platformSpeedKmh;
    _lastGpsMoveDistance = positionMoveDistance;

    if (!gpsSampleOk) {
      _setConfirmedSpeed(0.0);
      _movingSamples = 0;
      _speedSource = 'GPS Weak';
    } else if (platformSpeedKmh < minTrustedPlatformSpeedKmh) {
      _setConfirmedSpeed(0.0);
      _movingSamples = 0;
      _speedSource = 'GPS';
    } else {
      _movingSamples++;

      final acceptedSpeed = _filterPlatformSpeed(platformSpeedKmh);

      _setConfirmedSpeed(acceptedSpeed);
      _speedSource = 'GPS';

      if (acceptedSpeed > _maxTrustedSpeedKmh) {
        _maxTrustedSpeedKmh = acceptedSpeed;
      }
    }

    // Distance only counts while GPS platform speed confirms real movement.
    // This prevents stationary GPS drift from increasing distance after the user stops.
    if (gpsSampleOk &&
        _confirmedSpeedKmh >= minTrustedPlatformSpeedKmh &&
        positionMoveDistance >= 0 &&
        positionMoveDistance < 80 &&
        _currentPosition != null &&
        _lastPositionForMovement != null) {
      _totalDistance += positionMoveDistance;
    }

    _positionHistory.add(newPosition);

    if (_positionHistory.length > 100) {
      _positionHistory.removeAt(0);
    }

    debugPrint(
      'GPS update #$_gpsUpdateCount | '
      'interval: ${_lastGpsIntervalMs}ms | '
      'age: ${_lastGpsSampleAgeMs}ms | '
      'platform: ${platformSpeedKmh.toStringAsFixed(1)} km/h | '
      'confirmed: ${_confirmedSpeedKmh.toStringAsFixed(1)} km/h | '
      'display: ${_displaySpeedKmh.toStringAsFixed(1)} km/h | '
      'accuracy: ${_lastGpsAccuracy.toStringAsFixed(0)}m | '
      'moved: ${positionMoveDistance.toStringAsFixed(1)}m | '
      'source: $_speedSource',
    );

    notifyListeners();
  }

  void _setConfirmedSpeed(double speedKmh) {
    final safeSpeed = math.max(0.0, speedKmh);

    _confirmedSpeedKmh = safeSpeed;
    _currentSpeed = safeSpeed;
    _lastGpsSpeedKmh = safeSpeed;

    // UI-only target. Display timer will animate toward this.
    _displayTargetSpeedKmh = safeSpeed;
  }

  double _filterPlatformSpeed(double rawSpeed) {
    if (rawSpeed < minTrustedPlatformSpeedKmh) return 0.0;

    // No fake fallback. Sirf platform speed.
    // Tiny unrealistic single spike ko avoid karne ke liye basic sanity cap.
    if (_confirmedSpeedKmh == 0.0 && rawSpeed > 35.0 && _movingSamples <= 1) {
      return 0.0;
    }

    return rawSpeed;
  }

  bool hasMovedSignificantly() {
    return _confirmedSpeedKmh > 1.0;
  }

  double getLastMovementDistance() {
    if (_currentPosition == null || _lastPositionForMovement == null) {
      return 0.0;
    }

    return calculateDistance(_lastPositionForMovement!, _currentPosition!);
  }

  double getMaxSpeed() {
    return _maxTrustedSpeedKmh;
  }

  bool isMoving({double threshold = 1.0}) {
    return _confirmedSpeedKmh > threshold;
  }

  Future<bool> isLocationEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  void dispose() {
    _displaySmoothingTimer?.cancel();
    stopTracking();
    super.dispose();
  }
}
