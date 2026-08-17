import 'dart:async';
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
      status: PerformanceStatus.values[(json['status'] as num).toInt()],
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

  double _lastSpeed = 0.0;
  double _previousSpeed = 0.0;

  double _maxSpeed = 0.0;
  double _totalDistance = 0.0;
  double _previousTotalDistance = 0.0;

  final List<double> _speedHistory = [];
  final Map<String, double> _splits = {};

  double _lastSplitValue = 0.0;
  DateTime? _splitStartTime;

  // Target interpolation state.
  bool _targetReached = false;
  double? _targetReachedElapsedSeconds;
  DateTime? _targetReachedTime;

  PerformanceData? get currentSession => _currentSession;
  PerformanceStatus get status => _status;
  bool get isRunning => _status == PerformanceStatus.running;
  bool get hasTargetReached => _targetReached;

  void startSession({
    required PerformanceType type,
    required String presetName,
    required double targetValue,
    required String unit,
  }) {
    if (_status == PerformanceStatus.running) {
      debugPrint('Cannot start: Already running a session');
      return;
    }

    final now = DateTime.now();

    _startTime = now;
    _lastUpdateTime = now;
    _splitStartTime = now;

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

    _status = PerformanceStatus.running;

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
      maxSpeed: 0.0,
      distanceCovered: 0.0,
      splits: const {},
    );

    notifyListeners();
    debugPrint('Performance session started: $presetName');
  }

  /// Update performance with confirmed GPS/native data only.
  ///
  /// Do not pass smoothed/display speed here.
  /// [sampleTime] is optional for now; when native GPS timestamp is exposed,
  /// pass the real GPS sample time to improve interpolation accuracy.
  void updatePerformance({
    required double currentSpeed,
    required double distanceDelta,
    DateTime? sampleTime,
  }) {
    if (_status != PerformanceStatus.running || _currentSession == null) return;

    DateTime now = sampleTime ?? DateTime.now();

    // First GPS sample after pressing START can carry an Android timestamp
    // slightly older than the button press moment. Clamp it instead of rejecting.
    if (_startTime != null && now.isBefore(_startTime!)) {
      now = _startTime!;
    }

    if (_lastUpdateTime != null && now.isBefore(_lastUpdateTime!)) {
      now = _lastUpdateTime!.add(const Duration(milliseconds: 1));
    }

    final elapsedSeconds = now.difference(_startTime!).inMilliseconds / 1000.0;
    final previousElapsedSeconds = _lastUpdateTime == null
        ? 0.0
        : _lastUpdateTime!.difference(_startTime!).inMilliseconds / 1000.0;

    _previousSpeed = _lastSpeed;
    _previousTotalDistance = _totalDistance;

    final safeDistanceDelta = distanceDelta.isFinite && distanceDelta > 0
        ? distanceDelta
        : 0.0;

    _totalDistance += safeDistanceDelta;
    _lastSpeed = currentSpeed < 0 ? 0.0 : currentSpeed;
    _lastUpdateTime = now;

    if (_lastSpeed > _maxSpeed) {
      _maxSpeed = _lastSpeed;
    }

    _speedHistory.add(_lastSpeed);
    if (_speedHistory.length > 100) {
      _speedHistory.removeAt(0);
    }

    _updateSplits(
      currentSpeed: _lastSpeed,
      elapsedSeconds: elapsedSeconds,
      previousElapsedSeconds: previousElapsedSeconds,
    );

    _checkTargetCrossing(
      elapsedSeconds: elapsedSeconds,
      previousElapsedSeconds: previousElapsedSeconds,
    );

    _currentSession = PerformanceData(
      id: _currentSession!.id,
      startTime: _currentSession!.startTime,
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

  void _checkTargetCrossing({
    required double elapsedSeconds,
    required double previousElapsedSeconds,
  }) {
    if (_targetReached || _currentSession == null) return;

    final type = _currentSession!.type;
    final target = _currentSession!.targetValue;

    if (type == PerformanceType.speed) {
      final bool crossed = _previousSpeed < target && _lastSpeed >= target;

      if (!crossed) return;

      final crossingElapsed = _interpolateCrossingElapsedSeconds(
        previousValue: _previousSpeed,
        currentValue: _lastSpeed,
        targetValue: target,
        previousElapsedSeconds: previousElapsedSeconds,
        currentElapsedSeconds: elapsedSeconds,
      );

      _markTargetReached(crossingElapsed);
    } else if (type == PerformanceType.distance) {
      final bool crossed =
          _previousTotalDistance < target && _totalDistance >= target;

      if (!crossed) return;

      final crossingElapsed = _interpolateCrossingElapsedSeconds(
        previousValue: _previousTotalDistance,
        currentValue: _totalDistance,
        targetValue: target,
        previousElapsedSeconds: previousElapsedSeconds,
        currentElapsedSeconds: elapsedSeconds,
      );

      _markTargetReached(crossingElapsed);
    }
  }

  double _interpolateCrossingElapsedSeconds({
    required double previousValue,
    required double currentValue,
    required double targetValue,
    required double previousElapsedSeconds,
    required double currentElapsedSeconds,
  }) {
    final valueDelta = currentValue - previousValue;
    final timeDelta = currentElapsedSeconds - previousElapsedSeconds;

    if (valueDelta <= 0 || timeDelta <= 0) {
      return currentElapsedSeconds;
    }

    final ratio = ((targetValue - previousValue) / valueDelta).clamp(0.0, 1.0);
    return previousElapsedSeconds + (ratio * timeDelta);
  }

  void _markTargetReached(double elapsedSeconds) {
    _targetReached = true;
    _targetReachedElapsedSeconds = elapsedSeconds;
    _targetReachedTime = _startTime!.add(
      Duration(milliseconds: (elapsedSeconds * 1000).round()),
    );

    debugPrint(
      'Target reached by interpolation: '
      '${_currentSession!.presetName} in ${elapsedSeconds.toStringAsFixed(2)}s',
    );
  }

  void _updateSplits({
    required double currentSpeed,
    required double elapsedSeconds,
    required double previousElapsedSeconds,
  }) {
    if (_currentSession == null) return;

    final target = _currentSession!.targetValue;
    final type = _currentSession!.type;

    if (type == PerformanceType.speed) {
      const int splitInterval = 10;

      final currentSplitValue =
          ((currentSpeed / splitInterval).floor() * splitInterval).toDouble();

      if (currentSplitValue > _lastSplitValue && currentSplitValue <= target) {
        final splitElapsed = _interpolateCrossingElapsedSeconds(
          previousValue: _previousSpeed,
          currentValue: currentSpeed,
          targetValue: currentSplitValue,
          previousElapsedSeconds: previousElapsedSeconds,
          currentElapsedSeconds: elapsedSeconds,
        );

        _splits['${_lastSplitValue.toInt()}-${currentSplitValue.toInt()} ${_currentSession!.unit}'] =
            splitElapsed;

        _lastSplitValue = currentSplitValue;
        _splitStartTime = _startTime!.add(
          Duration(milliseconds: (splitElapsed * 1000).round()),
        );
      }
    } else if (type == PerformanceType.distance) {
      const int splitInterval = 50;

      final currentSplitValue =
          ((_totalDistance / splitInterval).floor() * splitInterval).toDouble();

      if (currentSplitValue > _lastSplitValue && currentSplitValue <= target) {
        final splitElapsed = _interpolateCrossingElapsedSeconds(
          previousValue: _previousTotalDistance,
          currentValue: _totalDistance,
          targetValue: currentSplitValue,
          previousElapsedSeconds: previousElapsedSeconds,
          currentElapsedSeconds: elapsedSeconds,
        );

        _splits['${_lastSplitValue.toInt()}-${currentSplitValue.toInt()}m'] =
            splitElapsed;

        _lastSplitValue = currentSplitValue;
        _splitStartTime = _startTime!.add(
          Duration(milliseconds: (splitElapsed * 1000).round()),
        );
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
    if (_status != PerformanceStatus.running) return false;
    return _targetReached;
  }

  Future<void> completeSession() async {
    if (_status != PerformanceStatus.running || _currentSession == null) return;

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
        fallbackEndTime.difference(_startTime!).inMilliseconds / 1000.0;

    final achievedValue = _currentSession!.type == PerformanceType.speed
        ? _currentSession!.targetValue
        : _getAchievedValue(_lastSpeed);

    _currentSession = PerformanceData(
      id: _currentSession!.id,
      startTime: _currentSession!.startTime,
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
    if (_status != PerformanceStatus.running || _currentSession == null) return;

    final endTime = DateTime.now();
    final elapsedSeconds =
        endTime.difference(_startTime!).inMilliseconds / 1000.0;
    final achievedValue = _getAchievedValue(_lastSpeed);

    _currentSession = PerformanceData(
      id: _currentSession!.id,
      startTime: _currentSession!.startTime,
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

    // Critical: partial/manual runs are intentionally NOT saved.
    // Client explicitly rejected fake/partial saved results.
  }

  void reset() {
    _status = PerformanceStatus.idle;
    _currentSession = null;

    _startTime = null;
    _lastUpdateTime = null;
    _splitStartTime = null;

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
    if (_startTime == null || _status != PerformanceStatus.running) return 0.0;
    return DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
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
}
