import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class GpsSample {
  final int elapsedRealtimeNanos;
  final DateTime sampleTime;
  final double speedKmh;
  final double? speedAccuracyMps;
  final double? latitude;
  final double? longitude;
  final double accuracyMeters;
  final double distanceDeltaMeters;
  final bool hasSpeed;
  final String provider;

  const GpsSample({
    required this.elapsedRealtimeNanos,
    required this.sampleTime,
    required this.speedKmh,
    required this.speedAccuracyMps,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.distanceDeltaMeters,
    required this.hasSpeed,
    required this.provider,
  });
}

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  Position? _currentPosition;

  // Confirmed speed is the trusted GPS/native speed used for UI gating.
  double _currentSpeed = 0.0; // km/h
  double _confirmedSpeedKmh = 0.0; // km/h

  // Timing speed is the unsmoothed Doppler sample used for 0/100 interpolation.
  // It is allowed to be below the "moving" threshold so rollout can be detected.
  double _timingSpeedKmh = 0.0;

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

  DateTime? _lastGpsSampleTime;
  int? _lastElapsedRealtimeNanos;
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
  double _maxTrustedSpeedKmh = 0.0;
  int _satelliteCount = 0;
  int _usedSatelliteCount = 0;
  String _provider = 'none';
  GpsSample? _lastTimingSample;

  static const double strongGpsAccuracyMeters = 50.0;
  static const double testGpsAccuracyMeters = 25.0;

  // UI "vehicle is moving" gate. Timing uses a lower interpolated start trigger.
  static const double minTrustedPlatformSpeedKmh = 0.8;

  static const int freshGpsSeconds = 4;
  static const double maxCredibleAccelerationMps2 = 25.0;
  static const double maxSpeedAccuracyMps = 4.0;

  int get gpsUpdateCount => _gpsUpdateCount;
  int get lastGpsIntervalMs => _lastGpsIntervalMs;
  int get lastGpsSampleAgeMs => _lastGpsSampleAgeMs;
  DateTime? get lastPositionReceivedAt => _lastPositionReceivedAt;
  int? get lastElapsedRealtimeNanos => _lastElapsedRealtimeNanos;
  GpsSample? get lastTimingSample => _lastTimingSample;
  int get satelliteCount => _satelliteCount;
  int get usedSatelliteCount => _usedSatelliteCount;
  String get provider => _provider;

  Position? get currentPosition => _currentPosition;

  double get currentSpeed => _currentSpeed;

  double get confirmedSpeedKmh => _confirmedSpeedKmh;
  double get displaySpeedKmh => _displaySpeedKmh;
  double get rawNativeSpeedKmh => _rawNativeSpeedKmh;
  double get timingSpeedKmh => _timingSpeedKmh;

  double get totalDistance => _totalDistance;
  List<Position> get positionHistory => List.unmodifiable(_positionHistory);

  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  bool get isServiceEnabled => _isServiceEnabled;

  bool get isUsingMotionFallback => false;

  String get speedSource => _speedSource;
  bool get isUsingGps =>
      _speedSource == 'GPS' ||
      _speedSource == 'Native GPS' ||
      _speedSource == 'GNSS' ||
      _speedSource == 'NMEA';
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
    return _gpsReadySamples >= 1;
  }

  bool get hasTrustedSpeed {
    return isUsingGps && _lastGpsSpeedKmh >= minTrustedPlatformSpeedKmh;
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
      nextDisplaySpeed = _displaySpeedKmh * 0.35;

      if (nextDisplaySpeed < 0.25) {
        nextDisplaySpeed = 0.0;
      }
    } else {
      final double delta = target - _displaySpeedKmh;
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
    final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 50),
        forceLocationManager: true,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    }

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
    final accuracy =
        (event['accuracy'] as num?)?.toDouble() ?? _lastGpsAccuracy;

    final hasSpeed = event['hasSpeed'] == true;
    final speedMps = (event['speedMps'] as num?)?.toDouble() ?? 0.0;

    final hasSpeedAccuracy = event['hasSpeedAccuracy'] == true;
    final speedAccuracyMps = (event['speedAccuracyMps'] as num?)?.toDouble();

    final timeMillis = (event['timeMillis'] as num?)?.toInt();
    final elapsedRealtimeNanos = (event['elapsedRealtimeNanos'] as num?)
        ?.toInt();
    final nmeaSpeedOnly = event['nmeaSpeedOnly'] == true;
    final provider = (event['provider'] as String?) ?? 'native';

    _satelliteCount =
        (event['satelliteCount'] as num?)?.toInt() ?? _satelliteCount;
    _usedSatelliteCount =
        (event['usedSatelliteCount'] as num?)?.toInt() ?? _usedSatelliteCount;
    _provider = provider;

    if (!nmeaSpeedOnly && (latitude == null || longitude == null)) return;
    if (nmeaSpeedOnly && !hasSpeed) return;

    final intervalMs = _lastNativeUpdate == null
        ? 0
        : now.difference(_lastNativeUpdate!).inMilliseconds;

    _lastNativeUpdate = now;
    _nativeGpsUpdateCount++;
    _gpsUpdateCount = _nativeGpsUpdateCount;

    _lastGpsUpdate = now;
    _lastPositionReceivedAt = now;
    _lastGpsIntervalMs = intervalMs;
    if (!nmeaSpeedOnly) {
      _lastGpsAccuracy = accuracy;
    }

    if (timeMillis != null && timeMillis > 0) {
      _lastGpsSampleTime = DateTime.fromMillisecondsSinceEpoch(timeMillis);
      _lastGpsSampleAgeMs = now.difference(_lastGpsSampleTime!).inMilliseconds;
    } else {
      _lastGpsSampleTime = now;
      _lastGpsSampleAgeMs = 0;
    }

    if (elapsedRealtimeNanos != null && elapsedRealtimeNanos > 0) {
      _lastElapsedRealtimeNanos = elapsedRealtimeNanos;
    }

    final bool gpsPositionOk =
        nmeaSpeedOnly || _lastGpsAccuracy <= testGpsAccuracyMeters;

    if (!nmeaSpeedOnly) {
      if (gpsPositionOk) {
        _gpsReadySamples++;
        if (_gpsReadySamples > 5) _gpsReadySamples = 5;
      } else if (_gpsReadySamples > 0) {
        // Do not dump a lock on one slightly worse fix.
        _gpsReadySamples = math.max(1, _gpsReadySamples - 1);
      }
    }

    double positionMoveDistance = 0.0;

    if (!nmeaSpeedOnly &&
        latitude != null &&
        longitude != null &&
        _lastNativeLatitude != null &&
        _lastNativeLongitude != null) {
      positionMoveDistance = Geolocator.distanceBetween(
        _lastNativeLatitude!,
        _lastNativeLongitude!,
        latitude,
        longitude,
      );
    }

    if (!nmeaSpeedOnly && latitude != null && longitude != null) {
      _lastNativeLatitude = latitude;
      _lastNativeLongitude = longitude;
    }

    final bool speedAccuracyOk =
        !hasSpeedAccuracy ||
        speedAccuracyMps == null ||
        speedAccuracyMps <= maxSpeedAccuracyMps;

    final bool speedSampleUsable = hasSpeed && speedAccuracyOk;
    final platformSpeedKmh = speedSampleUsable
        ? math.max(0.0, speedMps * 3.6)
        : 0.0;

    _rawNativeSpeedKmh = math.max(0.0, speedMps * 3.6);
    _lastPlatformSpeedKmh = platformSpeedKmh;

    final acceptedSpeed = speedSampleUsable
        ? _filterPlatformSpeed(platformSpeedKmh, elapsedRealtimeNanos)
        : _timingSpeedKmh;

    _applyTimingSample(
      speedKmh: speedSampleUsable ? acceptedSpeed : _timingSpeedKmh,
      usable: speedSampleUsable,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: _lastGpsAccuracy,
      speedAccuracyMps: speedAccuracyMps,
      hasSpeed: hasSpeed,
      provider: provider,
      sampleTime: _lastGpsSampleTime ?? now,
      elapsedRealtimeNanos: elapsedRealtimeNanos,
      positionMoveDistance: positionMoveDistance,
    );

    _speedSource = _sourceLabelForProvider(provider, gpsPositionOk);

    debugPrint(
      'Native GPS update #$_nativeGpsUpdateCount | '
      'provider: $provider | '
      'interval: ${intervalMs}ms | '
      'age: ${_lastGpsSampleAgeMs}ms | '
      'hasSpeed: $hasSpeed | '
      'speedAcc: ${speedAccuracyMps?.toStringAsFixed(2) ?? 'n/a'} m/s | '
      'platform: ${platformSpeedKmh.toStringAsFixed(1)} km/h | '
      'timing: ${_timingSpeedKmh.toStringAsFixed(1)} km/h | '
      'confirmed: ${_confirmedSpeedKmh.toStringAsFixed(1)} km/h | '
      'accuracy: ${_lastGpsAccuracy.toStringAsFixed(0)}m | '
      'sats: $_usedSatelliteCount/$_satelliteCount | '
      'source: $_speedSource',
    );

    notifyListeners();
  }

  String _sourceLabelForProvider(String provider, bool gpsPositionOk) {
    if (!gpsPositionOk) return 'GPS Weak';
    switch (provider) {
      case 'gnss':
        return 'GNSS';
      case 'nmea':
        return 'NMEA';
      case 'fused':
        return 'Native GPS';
      default:
        return 'Native GPS';
    }
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
    _timingSpeedKmh = 0.0;
    _displaySpeedKmh = 0.0;
    _displayTargetSpeedKmh = 0.0;
    _speedSource = 'Idle';
    _gpsReadySamples = 0;

    debugPrint('GPS-only location tracking stopped');
    notifyListeners();
  }

  void resetForNewRun() {
    prepareForNewRun();
  }

  /// Keep the GPS lock and last Doppler sample. Only reset distance so the
  /// start trigger can interpolate from the last stationary sample.
  void prepareForNewRun() {
    _totalDistance = 0.0;
    _lastGpsMoveDistance = 0.0;
    _maxTrustedSpeedKmh = 0.0;
    _positionHistory.clear();
    notifyListeners();
  }

  void _resetLiveValues({required bool clearGpsSignal}) {
    _currentPosition = null;
    _lastPositionForMovement = null;
    _lastGpsSampleTime = null;
    _lastElapsedRealtimeNanos = null;
    _lastTimingSample = null;
    _setConfirmedSpeed(0.0);
    _timingSpeedKmh = 0.0;
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
    _speedSource = 'Idle';
    _lastPositionReceivedAt = null;
    _lastNativeUpdate = null;
    _nativeGpsUpdateCount = 0;
    _gpsUpdateCount = 0;
    _lastGpsIntervalMs = 0;
    _lastGpsSampleAgeMs = 0;
    _lastNativeLatitude = null;
    _lastNativeLongitude = null;
    _satelliteCount = 0;
    _usedSatelliteCount = 0;
    _provider = 'none';

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
    _provider = 'geolocator';

    final gpsTimestamp = newPosition.timestamp;
    _lastGpsSampleAgeMs = now.difference(gpsTimestamp).inMilliseconds;
    _lastGpsSampleTime = gpsTimestamp;
    _lastElapsedRealtimeNanos = gpsTimestamp.microsecondsSinceEpoch * 1000;

    _lastGpsUpdate = now;
    _lastGpsAccuracy = newPosition.accuracy;
    final bool gpsSampleOk = _lastGpsAccuracy <= testGpsAccuracyMeters;

    if (gpsSampleOk) {
      _gpsReadySamples++;
      if (_gpsReadySamples > 5) _gpsReadySamples = 5;
    } else if (_gpsReadySamples > 0) {
      _gpsReadySamples = math.max(1, _gpsReadySamples - 1);
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
    _rawNativeSpeedKmh = platformSpeedKmh;
    _lastGpsMoveDistance = positionMoveDistance;

    final acceptedSpeed = _filterPlatformSpeed(
      platformSpeedKmh,
      _lastElapsedRealtimeNanos,
    );

    _applyTimingSample(
      speedKmh: acceptedSpeed,
      usable: true,
      latitude: newPosition.latitude,
      longitude: newPosition.longitude,
      accuracyMeters: newPosition.accuracy,
      speedAccuracyMps: null,
      hasSpeed: true,
      provider: 'geolocator',
      sampleTime: gpsTimestamp,
      elapsedRealtimeNanos: _lastElapsedRealtimeNanos,
      positionMoveDistance: positionMoveDistance,
    );

    _speedSource = gpsSampleOk ? 'GPS' : 'GPS Weak';

    _positionHistory.add(newPosition);
    if (_positionHistory.length > 100) {
      _positionHistory.removeAt(0);
    }

    debugPrint(
      'GPS update #$_gpsUpdateCount | '
      'interval: ${_lastGpsIntervalMs}ms | '
      'age: ${_lastGpsSampleAgeMs}ms | '
      'platform: ${platformSpeedKmh.toStringAsFixed(1)} km/h | '
      'timing: ${_timingSpeedKmh.toStringAsFixed(1)} km/h | '
      'confirmed: ${_confirmedSpeedKmh.toStringAsFixed(1)} km/h | '
      'accuracy: ${_lastGpsAccuracy.toStringAsFixed(0)}m | '
      'source: $_speedSource',
    );

    notifyListeners();
  }

  void _applyTimingSample({
    required double speedKmh,
    required bool usable,
    required double? latitude,
    required double? longitude,
    required double accuracyMeters,
    required double? speedAccuracyMps,
    required bool hasSpeed,
    required String provider,
    required DateTime sampleTime,
    required int? elapsedRealtimeNanos,
    required double positionMoveDistance,
  }) {
    if (!usable) {
      return;
    }

    final safeSpeed = math.max(0.0, speedKmh);
    final sampleNanos =
        elapsedRealtimeNanos ??
        _lastElapsedRealtimeNanos ??
        (sampleTime.microsecondsSinceEpoch * 1000);

    double distanceDelta = 0.0;
    final previous = _lastTimingSample;
    if (previous != null) {
      final dtSeconds =
          (sampleNanos - previous.elapsedRealtimeNanos) / 1000000000.0;
      if (dtSeconds > 0 && dtSeconds < 2.0) {
        final prevMps = previous.speedKmh / 3.6;
        final currMps = safeSpeed / 3.6;
        distanceDelta = ((prevMps + currMps) / 2.0) * dtSeconds;
      }
    }

    if (distanceDelta <= 0 &&
        positionMoveDistance > 0 &&
        positionMoveDistance < 80) {
      distanceDelta = positionMoveDistance;
    }

    if (distanceDelta < 0 || distanceDelta > 80) {
      distanceDelta = 0.0;
    }

    _lastGpsMoveDistance = distanceDelta;
    _timingSpeedKmh = safeSpeed;
    _lastElapsedRealtimeNanos = sampleNanos;
    _setConfirmedSpeed(safeSpeed);

    if (distanceDelta > 0) {
      _totalDistance += distanceDelta;
    }
    if (safeSpeed > _maxTrustedSpeedKmh) {
      _maxTrustedSpeedKmh = safeSpeed;
    }

    _lastTimingSample = GpsSample(
      elapsedRealtimeNanos: sampleNanos,
      sampleTime: sampleTime,
      speedKmh: safeSpeed,
      speedAccuracyMps: speedAccuracyMps,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      distanceDeltaMeters: distanceDelta,
      hasSpeed: hasSpeed,
      provider: provider,
    );
  }

  void _setConfirmedSpeed(double speedKmh) {
    final safeSpeed = math.max(0.0, speedKmh);
    final uiSpeed = safeSpeed < minTrustedPlatformSpeedKmh ? 0.0 : safeSpeed;

    _confirmedSpeedKmh = uiSpeed;
    _currentSpeed = uiSpeed;
    _lastGpsSpeedKmh = uiSpeed;
    _displayTargetSpeedKmh = uiSpeed;
  }

  double _filterPlatformSpeed(double rawSpeed, int? sampleNanos) {
    if (rawSpeed < 0) return 0.0;

    final previous = _lastTimingSample;
    if (previous == null || sampleNanos == null) {
      return rawSpeed;
    }

    // Do not treat the first moving sample as a spike. Fast cars can already
    // be well above 35 km/h by the time the first GNSS tick arrives.
    if (previous.speedKmh < 1.0) {
      return rawSpeed > 160.0 ? previous.speedKmh : rawSpeed;
    }

    final dtSeconds =
        (sampleNanos - previous.elapsedRealtimeNanos) / 1000000000.0;
    if (dtSeconds <= 0 || dtSeconds > 2.0) {
      return rawSpeed;
    }

    final maxDeltaKmh = maxCredibleAccelerationMps2 * dtSeconds * 3.6;
    final delta = rawSpeed - previous.speedKmh;
    if (delta > maxDeltaKmh && maxDeltaKmh > 0) {
      debugPrint(
        'Rejected GPS speed spike ${rawSpeed.toStringAsFixed(1)} km/h '
        '(+${delta.toStringAsFixed(1)} in ${dtSeconds.toStringAsFixed(3)}s)',
      );
      return previous.speedKmh;
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
