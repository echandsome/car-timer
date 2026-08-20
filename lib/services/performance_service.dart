import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PerformanceType {
  speed, // 0-60 mph, 0-100 km/h, etc.
  distance, // 1/8 mile, 1/4 mile, etc.
  braking, // Stopping distance test
}

enum PerformanceStatus {
  idle, // Not running
  running, // Currently measuring
  completed, // Target reached
  partial, // Stopped before target
  armed, // Waiting for 0 km/h rollout crossing
}

class TimingMath {
  /// VBOX-style default rollout. True 0 km/h is interpolated from the
  /// last sub-threshold sample, not from the button press.
  static const double startTriggerSpeedKmh = 1.0;
  static const double brakingStopSpeedKmh = 0.5;

  static int interpolateCrossingNanos({
    required double previousValue,
    required double currentValue,
    required double targetValue,
    required int previousNanos,
    required int currentNanos,
  }) {
    final valueDelta = currentValue - previousValue;
    final timeDelta = currentNanos - previousNanos;

    if (valueDelta == 0 || timeDelta == 0) {
      return currentNanos;
    }

    final ratio = ((targetValue - previousValue) / valueDelta).clamp(0.0, 1.0);
    return previousNanos + (ratio * timeDelta).round();
  }

  static double nanosToSeconds(int fromNanos, int toNanos) {
    return (toNanos - fromNanos) / 1000000000.0;
  }
}

class PerformanceData {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final PerformanceType type;
  final String presetName;
  final double targetValue;
  final String unit;
  final PerformanceStatus status;
  final double achievedValue;
  final double elapsedSeconds;
  final double maxSpeed;
  final double distanceCovered;
  final Map<String, double> splits;

  PerformanceData({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.type,
    required this.presetName,
    required this.targetValue,
    required this.unit,
    required this.status,
    required this.achievedValue,
    required this.elapsedSeconds,
    required this.maxSpeed,
    required this.distanceCovered,
    required this.splits,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'type': type.index,
      'presetName': presetName,
      'targetValue': targetValue,
      'unit': unit,
      'status': status.index,
      'achievedValue': achievedValue,
      'elapsedSeconds': elapsedSeconds,
      'maxSpeed': maxSpeed,
      'distanceCovered': distanceCovered,
      'splits': splits,
    };
  }

  factory PerformanceData.fromJson(Map<String, dynamic> json) {
    final statusIndex = (json['status'] as num).toInt();
    final status =
        statusIndex >= 0 && statusIndex < PerformanceStatus.values.length
        ? PerformanceStatus.values[statusIndex]
        : PerformanceStatus.completed;

    return PerformanceData(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      type: PerformanceType.values[(json['type'] as num).toInt()],
      presetName: json['presetName'] as String,
      targetValue: (json['targetValue'] as num).toDouble(),
      unit: json['unit'] as String,
      status: status,
      achievedValue: (json['achievedValue'] as num).toDouble(),
      elapsedSeconds: (json['elapsedSeconds'] as num).toDouble(),
      maxSpeed: (json['maxSpeed'] as num).toDouble(),
      distanceCovered: (json['distanceCovered'] as num).toDouble(),
      splits: Map<String, double>.from(
        (json['splits'] as Map).map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
      ),
    );
  }
}

class PerformanceService extends ChangeNotifier {
  static final PerformanceService _instance = PerformanceService._internal();

  factory PerformanceService() => _instance;

  PerformanceService._internal();

  PerformanceData? _currentSession;
  PerformanceStatus _status = PerformanceStatus.idle;

  DateTime? _startTime;
  DateTime? _lastUpdateTime;

  int? _t0Nanos;
  int? _t1Nanos;
  int? _lastSampleNanos;
  int? _previousNanos;
  int? _pendingT0Nanos;

  double _lastSpeed = 0.0;
  double _previousSpeed = 0.0;

  double _maxSpeed = 0.0;
  double _totalDistance = 0.0;
  double _previousTotalDistance = 0.0;

  final List<double> _speedHistory = [];
  final Map<String, double> _splits = {};

  double _lastSplitValue = 0.0;
  DateTime? _splitStartTime;

  bool _targetReached = false;
  double? _targetReachedElapsedSeconds;
  DateTime? _targetReachedTime;
  bool _waitForStartTrigger = true;
  bool? _useElapsedRealtimeClock;

  PerformanceData? get currentSession => _currentSession;
  PerformanceStatus get status => _status;
  bool get isRunning =>
      _status == PerformanceStatus.running ||
      _status == PerformanceStatus.armed;
  bool get isArmed => _status == PerformanceStatus.armed;
  bool get hasTargetReached => _targetReached;

  void startSession({
    required PerformanceType type,
    required String presetName,
    required double targetValue,
    required String unit,
    double initialSpeed = 0.0,
    int? initialElapsedRealtimeNanos,
    DateTime? initialSampleTime,
    bool waitForStartTrigger = true,
  }) {
    if (_status == PerformanceStatus.running ||
        _status == PerformanceStatus.armed) {
      debugPrint('Cannot start: Already running a session');
      return;
    }

    final now = initialSampleTime ?? DateTime.now();
    final initialNanos = _resolveNanos(
      elapsedRealtimeNanos: initialElapsedRealtimeNanos,
      sampleTime: initialSampleTime,
      fallbackNow: now,
    );

    _waitForStartTrigger =
        waitForStartTrigger && type != PerformanceType.braking;

    _startTime = _waitForStartTrigger ? null : now;
    _lastUpdateTime = now;
    _splitStartTime = now;

    _lastSpeed = initialSpeed < 0 ? 0.0 : initialSpeed;
    _previousSpeed = _lastSpeed;
    _maxSpeed = _lastSpeed;
    _totalDistance = 0.0;
    _previousTotalDistance = 0.0;

    _speedHistory.clear();
    _splits.clear();

    _lastSplitValue = 0.0;

    _targetReached = false;
    _targetReachedElapsedSeconds = null;
    _targetReachedTime = null;
    _t1Nanos = null;
    _pendingT0Nanos = null;
    _useElapsedRealtimeClock =
        initialElapsedRealtimeNanos != null && initialElapsedRealtimeNanos > 0;
    _lastSampleNanos = initialNanos;
    _previousNanos = initialNanos;

    if (_waitForStartTrigger) {
      _t0Nanos = null;
      _status = PerformanceStatus.armed;
    } else {
      _t0Nanos = initialNanos;
      _status = PerformanceStatus.running;
    }

    _currentSession = PerformanceData(
      id: now.millisecondsSinceEpoch.toString(),
      startTime: now,
      endTime: null,
      type: type,
      presetName: presetName,
      targetValue: targetValue,
      unit: unit,
      status: PerformanceStatus.running,
      achievedValue: 0.0,
      elapsedSeconds: 0.0,
      maxSpeed: _maxSpeed,
      distanceCovered: 0.0,
      splits: const {},
    );

    notifyListeners();
    debugPrint(
      'Performance session ${_waitForStartTrigger ? 'armed' : 'started'}: $presetName',
    );
  }

  /// Update performance with confirmed GPS/native data only.
  ///
  /// Do not pass smoothed/display speed here.
  /// Prefer [elapsedRealtimeNanos] from the GNSS fix so repeated runs do not
  /// drift against wall-clock time.
  void updatePerformance({
    required double currentSpeed,
    required double distanceDelta,
    DateTime? sampleTime,
    int? elapsedRealtimeNanos,
  }) {
    if ((_status != PerformanceStatus.running &&
            _status != PerformanceStatus.armed) ||
        _currentSession == null) {
      return;
    }

    final DateTime now = sampleTime ?? DateTime.now();
    if (_useElapsedRealtimeClock == true &&
        (elapsedRealtimeNanos == null || elapsedRealtimeNanos <= 0)) {
      return;
    }

    final int sampleNanos = _resolveNanos(
      elapsedRealtimeNanos: elapsedRealtimeNanos,
      sampleTime: sampleTime,
      fallbackNow: now,
    );

    if (_lastSampleNanos != null && sampleNanos < _lastSampleNanos!) {
      return;
    }

    final previousElapsedSeconds = _elapsedSecondsAt(_lastSampleNanos);
    final previousNanos = _lastSampleNanos ?? sampleNanos;

    _previousSpeed = _lastSpeed;
    _previousTotalDistance = _totalDistance;
    _previousNanos = previousNanos;

    final safeDistanceDelta = distanceDelta.isFinite && distanceDelta > 0
        ? distanceDelta
        : 0.0;

    _totalDistance += safeDistanceDelta;
    _lastSpeed = currentSpeed < 0 ? 0.0 : currentSpeed;
    _lastUpdateTime = now;
    _lastSampleNanos = sampleNanos;

    if (_lastSpeed > _maxSpeed) {
      _maxSpeed = _lastSpeed;
    }

    _speedHistory.add(_lastSpeed);
    if (_speedHistory.length > 100) {
      _speedHistory.removeAt(0);
    }

    _checkStartTrigger(sampleNanos: sampleNanos);

    final elapsedSeconds = _elapsedSecondsAt(sampleNanos);

    if (_t0Nanos != null) {
      _updateSplits(
        currentSpeed: _lastSpeed,
        elapsedSeconds: elapsedSeconds,
        previousElapsedSeconds: previousElapsedSeconds,
      );

      _checkTargetCrossing(
        elapsedSeconds: elapsedSeconds,
        previousElapsedSeconds: previousElapsedSeconds,
        sampleNanos: sampleNanos,
      );
    }

    _currentSession = PerformanceData(
      id: _currentSession!.id,
      startTime: _startTime ?? _currentSession!.startTime,
      endTime: null,
      type: _currentSession!.type,
      presetName: _currentSession!.presetName,
      targetValue: _currentSession!.targetValue,
      unit: _currentSession!.unit,
      status: PerformanceStatus.running,
      achievedValue: _getAchievedValue(_lastSpeed),
      elapsedSeconds: _targetReachedElapsedSeconds ?? elapsedSeconds,
      maxSpeed: _maxSpeed,
      distanceCovered: _totalDistance,
      splits: Map<String, double>.from(_splits),
    );

    notifyListeners();
  }

  void _checkStartTrigger({required int sampleNanos}) {
    if (!_waitForStartTrigger || _currentSession == null) return;
    if (_t0Nanos != null) return;

    const startTrigger = TimingMath.startTriggerSpeedKmh;
    final previousNanos = _previousNanos ?? sampleNanos;

    if (_pendingT0Nanos != null) {
      if (_lastSpeed >= startTrigger) {
        _markStarted(_pendingT0Nanos!);
      } else {
        _pendingT0Nanos = null;
      }
      return;
    }

    final bool crossed =
        _previousSpeed < startTrigger && _lastSpeed >= startTrigger;

    if (!crossed) return;

    final t0 = TimingMath.interpolateCrossingNanos(
      previousValue: _previousSpeed,
      currentValue: _lastSpeed,
      targetValue: startTrigger,
      previousNanos: previousNanos,
      currentNanos: sampleNanos,
    );

    // Fast launches can already be well above crawl on the first moving sample.
    // Confirm immediately so 0-100 is not delayed by an extra GPS tick.
    if (_lastSpeed >= 8.0) {
      _markStarted(t0);
      return;
    }

    _pendingT0Nanos = t0;
  }

  void _markStarted(int t0Nanos) {
    _t0Nanos = t0Nanos;
    _pendingT0Nanos = null;
    _status = PerformanceStatus.running;
    _startTime = _timestampFromNanos(t0Nanos);

    debugPrint(
      'Rollout start interpolated at '
      '${TimingMath.startTriggerSpeedKmh.toStringAsFixed(1)} km/h',
    );
  }

  void _checkTargetCrossing({
    required double elapsedSeconds,
    required double previousElapsedSeconds,
    required int sampleNanos,
  }) {
    if (_targetReached || _currentSession == null || _t0Nanos == null) return;

    final type = _currentSession!.type;
    final target = _currentSession!.targetValue;
    final previousNanos = _previousNanos ?? sampleNanos;

    if (type == PerformanceType.speed) {
      final bool crossed = _previousSpeed < target && _lastSpeed >= target;
      if (!crossed) return;

      final crossingNanos = TimingMath.interpolateCrossingNanos(
        previousValue: _previousSpeed,
        currentValue: _lastSpeed,
        targetValue: target,
        previousNanos: previousNanos,
        currentNanos: sampleNanos,
      );

      _markTargetReachedNanos(crossingNanos);
    } else if (type == PerformanceType.distance) {
      final bool crossed =
          _previousTotalDistance < target && _totalDistance >= target;
      if (!crossed) return;

      final crossingNanos = TimingMath.interpolateCrossingNanos(
        previousValue: _previousTotalDistance,
        currentValue: _totalDistance,
        targetValue: target,
        previousNanos: previousNanos,
        currentNanos: sampleNanos,
      );

      _markTargetReachedNanos(crossingNanos);
    } else if (type == PerformanceType.braking) {
      const stopTrigger = TimingMath.brakingStopSpeedKmh;
      final bool crossed =
          _previousSpeed > stopTrigger && _lastSpeed <= stopTrigger;
      if (!crossed) return;

      final crossingNanos = TimingMath.interpolateCrossingNanos(
        previousValue: _previousSpeed,
        currentValue: _lastSpeed,
        targetValue: stopTrigger,
        previousNanos: previousNanos,
        currentNanos: sampleNanos,
      );

      _markTargetReachedNanos(crossingNanos);
    }
  }

  void _markTargetReachedNanos(int crossingNanos) {
    if (_t0Nanos == null) return;

    var safeCrossing = crossingNanos;
    if (safeCrossing < _t0Nanos!) {
      safeCrossing = _t0Nanos!;
    }

    _t1Nanos = safeCrossing;
    _targetReached = true;
    _targetReachedElapsedSeconds = TimingMath.nanosToSeconds(
      _t0Nanos!,
      safeCrossing,
    );
    _targetReachedTime = _timestampFromNanos(safeCrossing);

    debugPrint(
      'Target reached by interpolation: '
      '${_currentSession!.presetName} in '
      '${_targetReachedElapsedSeconds!.toStringAsFixed(3)}s',
    );
  }

  void _updateSplits({
    required double currentSpeed,
    required double elapsedSeconds,
    required double previousElapsedSeconds,
  }) {
    if (_currentSession == null || _t0Nanos == null) return;

    final target = _currentSession!.targetValue;
    final type = _currentSession!.type;
    final previousNanos = _previousNanos;
    final currentNanos = _lastSampleNanos;
    if (previousNanos == null || currentNanos == null) return;

    if (type == PerformanceType.speed) {
      const int splitInterval = 10;

      final currentSplitValue =
          ((currentSpeed / splitInterval).floor() * splitInterval).toDouble();

      if (currentSplitValue > _lastSplitValue && currentSplitValue <= target) {
        final splitNanos = TimingMath.interpolateCrossingNanos(
          previousValue: _previousSpeed,
          currentValue: currentSpeed,
          targetValue: currentSplitValue,
          previousNanos: previousNanos,
          currentNanos: currentNanos,
        );

        final splitElapsed = TimingMath.nanosToSeconds(_t0Nanos!, splitNanos);

        _splits['${_lastSplitValue.toInt()}-${currentSplitValue.toInt()} ${_currentSession!.unit}'] =
            splitElapsed;

        _lastSplitValue = currentSplitValue;
        _splitStartTime = _timestampFromNanos(splitNanos);
      }
    } else if (type == PerformanceType.distance) {
      const int splitInterval = 50;

      final currentSplitValue =
          ((_totalDistance / splitInterval).floor() * splitInterval).toDouble();

      if (currentSplitValue > _lastSplitValue && currentSplitValue <= target) {
        final splitNanos = TimingMath.interpolateCrossingNanos(
          previousValue: _previousTotalDistance,
          currentValue: _totalDistance,
          targetValue: currentSplitValue,
          previousNanos: previousNanos,
          currentNanos: currentNanos,
        );

        final splitElapsed = TimingMath.nanosToSeconds(_t0Nanos!, splitNanos);

        _splits['${_lastSplitValue.toInt()}-${currentSplitValue.toInt()}m'] =
            splitElapsed;

        _lastSplitValue = currentSplitValue;
        _splitStartTime = _timestampFromNanos(splitNanos);
      }
    }
  }

  double _getAchievedValue(double currentSpeed) {
    final type = _currentSession!.type;

    if (type == PerformanceType.speed) {
      return currentSpeed;
    }

    if (type == PerformanceType.distance) {
      return _totalDistance;
    }

    return _totalDistance;
  }

  bool isTargetReached() {
    if (_status != PerformanceStatus.running &&
        _status != PerformanceStatus.armed) {
      return false;
    }
    return _targetReached;
  }

  Future<void> completeSession() async {
    if ((_status != PerformanceStatus.running &&
            _status != PerformanceStatus.armed) ||
        _currentSession == null) {
      return;
    }

    final bool isBrakingSession =
        _currentSession!.type == PerformanceType.braking;

    if (!_targetReached && !isBrakingSession) {
      debugPrint(
        'Complete ignored: target was not reached for ${_currentSession!.presetName}',
      );
      return;
    }

    final fallbackEndTime = DateTime.now();
    final endTime = _targetReachedTime ?? fallbackEndTime;
    final elapsedSeconds =
        _targetReachedElapsedSeconds ??
        (_t0Nanos != null && _t1Nanos != null
            ? TimingMath.nanosToSeconds(_t0Nanos!, _t1Nanos!)
            : (_t0Nanos != null && _lastSampleNanos != null
                  ? TimingMath.nanosToSeconds(_t0Nanos!, _lastSampleNanos!)
                  : 0.0));

    final achievedValue = _currentSession!.type == PerformanceType.speed
        ? _currentSession!.targetValue
        : _getAchievedValue(_lastSpeed);

    _currentSession = PerformanceData(
      id: _currentSession!.id,
      startTime: _startTime ?? _currentSession!.startTime,
      endTime: endTime,
      type: _currentSession!.type,
      presetName: _currentSession!.presetName,
      targetValue: _currentSession!.targetValue,
      unit: _currentSession!.unit,
      status: PerformanceStatus.completed,
      achievedValue: achievedValue,
      elapsedSeconds: elapsedSeconds,
      maxSpeed: _maxSpeed,
      distanceCovered: _totalDistance,
      splits: Map<String, double>.from(_splits),
    );

    _status = PerformanceStatus.completed;
    notifyListeners();

    debugPrint(
      'Performance session completed: '
      '${_currentSession!.presetName} in ${elapsedSeconds.toStringAsFixed(2)}s',
    );

    await saveResult(_currentSession!);
  }

  Future<void> stopSession() async {
    if ((_status != PerformanceStatus.running &&
            _status != PerformanceStatus.armed) ||
        _currentSession == null) {
      return;
    }

    final endTime = DateTime.now();
    final elapsedSeconds = _t0Nanos != null && _lastSampleNanos != null
        ? TimingMath.nanosToSeconds(_t0Nanos!, _lastSampleNanos!)
        : 0.0;
    final achievedValue = _getAchievedValue(_lastSpeed);

    _currentSession = PerformanceData(
      id: _currentSession!.id,
      startTime: _startTime ?? _currentSession!.startTime,
      endTime: endTime,
      type: _currentSession!.type,
      presetName: _currentSession!.presetName,
      targetValue: _currentSession!.targetValue,
      unit: _currentSession!.unit,
      status: PerformanceStatus.partial,
      achievedValue: achievedValue,
      elapsedSeconds: elapsedSeconds,
      maxSpeed: _maxSpeed,
      distanceCovered: _totalDistance,
      splits: Map<String, double>.from(_splits),
    );

    _status = PerformanceStatus.partial;
    notifyListeners();

    debugPrint(
      'Run not recorded: target was not reached. '
      '${_currentSession!.presetName} stopped at ${achievedValue.toStringAsFixed(1)} ${_currentSession!.unit}',
    );
  }

  void reset() {
    _status = PerformanceStatus.idle;
    _currentSession = null;

    _startTime = null;
    _lastUpdateTime = null;
    _splitStartTime = null;
    _t0Nanos = null;
    _t1Nanos = null;
    _lastSampleNanos = null;
    _previousNanos = null;
    _pendingT0Nanos = null;
    _waitForStartTrigger = true;
    _useElapsedRealtimeClock = null;

    _lastSpeed = 0.0;
    _previousSpeed = 0.0;
    _maxSpeed = 0.0;
    _totalDistance = 0.0;
    _previousTotalDistance = 0.0;

    _speedHistory.clear();
    _splits.clear();

    _lastSplitValue = 0.0;

    _targetReached = false;
    _targetReachedElapsedSeconds = null;
    _targetReachedTime = null;

    notifyListeners();
  }

  Future<void> saveResult(PerformanceData result) async {
    if (result.status != PerformanceStatus.completed) {
      debugPrint(
        'Result not saved: ${result.presetName} is ${result.status.name}',
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    const resultsKey = 'performance_results';
    final List<String> existingResults = prefs.getStringList(resultsKey) ?? [];

    existingResults.add(json.encode(result.toJson()));

    if (existingResults.length > 100) {
      existingResults.removeAt(0);
    }

    await prefs.setStringList(resultsKey, existingResults);
    debugPrint('Result saved: ${result.presetName}');
  }

  Future<List<PerformanceData>> getResults() async {
    final prefs = await SharedPreferences.getInstance();
    const resultsKey = 'performance_results';
    final List<String> savedResults = prefs.getStringList(resultsKey) ?? [];

    return savedResults
        .map((jsonStr) => PerformanceData.fromJson(json.decode(jsonStr)))
        .where((result) => result.status == PerformanceStatus.completed)
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Future<void> clearResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('performance_results');
    debugPrint('All results cleared');
  }

  double getCurrentElapsedTime() {
    if (_t0Nanos == null ||
        (_status != PerformanceStatus.running &&
            _status != PerformanceStatus.armed)) {
      return 0.0;
    }

    if (_targetReachedElapsedSeconds != null) {
      return _targetReachedElapsedSeconds!;
    }

    if (_lastSampleNanos != null) {
      return TimingMath.nanosToSeconds(_t0Nanos!, _lastSampleNanos!);
    }

    return 0.0;
  }

  String getCurrentDisplayValue() {
    if (_currentSession == null) return '0';

    final achieved = _getAchievedValue(_lastSpeed);
    return achieved.toStringAsFixed(1);
  }

  static String formatElapsedTime(double seconds) {
    final totalSeconds = seconds.floor();
    final centiseconds = ((seconds - totalSeconds) * 100).floor();

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}.'
          '${centiseconds.toString().padLeft(2, '0')}';
    }

    if (minutes > 0) {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}.'
          '${centiseconds.toString().padLeft(2, '0')}';
    }

    return '${secs.toString()}.${centiseconds.toString().padLeft(2, '0')}s';
  }

  int _resolveNanos({
    int? elapsedRealtimeNanos,
    DateTime? sampleTime,
    required DateTime fallbackNow,
  }) {
    final elapsed = elapsedRealtimeNanos;
    final hasElapsed = elapsed != null && elapsed > 0;

    _useElapsedRealtimeClock ??= hasElapsed;

    if (_useElapsedRealtimeClock == true) {
      if (hasElapsed) return elapsed;
      return _lastSampleNanos ?? (fallbackNow.microsecondsSinceEpoch * 1000);
    }

    final time = sampleTime ?? fallbackNow;
    return time.microsecondsSinceEpoch * 1000;
  }

  double _elapsedSecondsAt(int? sampleNanos) {
    if (_t0Nanos == null || sampleNanos == null) return 0.0;
    final seconds = TimingMath.nanosToSeconds(_t0Nanos!, sampleNanos);
    return seconds < 0 ? 0.0 : seconds;
  }

  DateTime _timestampFromNanos(int nanos) {
    if (_lastUpdateTime != null && _lastSampleNanos != null) {
      final deltaSeconds = TimingMath.nanosToSeconds(_lastSampleNanos!, nanos);
      return _lastUpdateTime!.add(
        Duration(milliseconds: (deltaSeconds * 1000).round()),
      );
    }
    return DateTime.now();
  }
}
