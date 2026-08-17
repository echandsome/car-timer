import 'package:car_timer/services/performance_service.dart';
import 'package:flutter/material.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final PerformanceService _performanceService = PerformanceService();
  late Future<List<PerformanceData>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  void _loadResults() {
    _resultsFuture = _performanceService.getResults();
  }

  String _typeLabel(PerformanceType type) {
    switch (type) {
      case PerformanceType.speed:
        return 'Speed Test';
      case PerformanceType.distance:
        return 'Distance Test';
      case PerformanceType.braking:
        return 'Braking Test';
    }
  }

  String _statusLabel(PerformanceStatus status) {
    switch (status) {
      case PerformanceStatus.completed:
        return 'Completed';
      case PerformanceStatus.partial:
        return 'Stopped Early';
      case PerformanceStatus.running:
        return 'Running';
      case PerformanceStatus.idle:
        return 'Idle';
    }
  }

  Color _statusColor(PerformanceStatus status) {
    switch (status) {
      case PerformanceStatus.completed:
        return Colors.greenAccent;
      case PerformanceStatus.partial:
        return Colors.orangeAccent;
      case PerformanceStatus.running:
        return Colors.blueAccent;
      case PerformanceStatus.idle:
        return Colors.white54;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year  $hour:$minute';
  }

  String _speedUnitForResult(PerformanceData result) {
    if (result.type == PerformanceType.speed ||
        result.type == PerformanceType.braking) {
      return result.unit;
    }

    // Distance tests store target distance unit as "m".
    // Speed unit is not separately stored yet, so use km/h as safe display fallback.
    if (result.unit == 'm' || result.unit == 'meters') {
      return 'km/h';
    }

    return result.unit;
  }

  String _targetSpeedUnitForSpeedPreset(PerformanceData result) {
    final preset = result.presetName.toLowerCase();

    if (preset.contains('mph')) return 'mph';
    if (preset.contains('km/h') || preset.contains('kmh')) return 'km/h';

    return result.unit;
  }

  String _mainResultText(PerformanceData result) {
    if (result.type == PerformanceType.speed) {
      return '${result.elapsedSeconds.toStringAsFixed(2)} s';
    }

    if (result.type == PerformanceType.distance) {
      final speedUnit = _speedUnitForResult(result);
      return '${result.elapsedSeconds.toStringAsFixed(2)} s @ ${result.maxSpeed.toStringAsFixed(1)} $speedUnit';
    }

    final brakeStartSpeed = result.targetValue > 0
        ? result.targetValue
        : result.maxSpeed;

    return '${brakeStartSpeed.toStringAsFixed(1)} ${result.unit} → 0';
  }

  String _subResultText(PerformanceData result) {
    if (result.type == PerformanceType.speed) {
      final unit = _targetSpeedUnitForSpeedPreset(result);
      return 'Target: ${result.targetValue.toStringAsFixed(0)} $unit';
    }

    if (result.type == PerformanceType.distance) {
      return 'Distance: ${result.distanceCovered.toStringAsFixed(1)} m';
    }

    return 'Stopped in ${result.elapsedSeconds.toStringAsFixed(2)} s';
  }

  Future<void> _clearResults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1C),
          title: const Text(
            'Clear Results?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This will delete all locally saved results.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _performanceService.clearResults();
      if (!mounted) return;

      setState(() {
        _loadResults();
      });
    }
  }

  Widget _buildResultCard(PerformanceData result) {
    final statusColor = _statusColor(result.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(result, statusColor),
          const SizedBox(height: 6),
          Text(
            _typeLabel(result.type),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            _mainResultText(result),
            style: const TextStyle(
              color: Colors.red,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subResultText(result),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _buildStatsRow(result),
          const SizedBox(height: 8),
          Text(
            _formatDate(result.startTime),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader(PerformanceData result, Color statusColor) {
    return Row(
      children: [
        Expanded(
          child: Text(
            result.presetName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.5)),
          ),
          child: Text(
            _statusLabel(result.status),
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(PerformanceData result) {
    if (result.type == PerformanceType.speed) {
      final unit = _targetSpeedUnitForSpeedPreset(result);

      return Row(
        children: [
          Expanded(
            child: _miniStat(
              'Target Speed',
              '${result.targetValue.toStringAsFixed(0)} $unit',
            ),
          ),
          Expanded(
            child: _miniStat(
              'Max Speed',
              '${result.maxSpeed.toStringAsFixed(1)} $unit',
            ),
          ),
          Expanded(
            child: _miniStat(
              'Time',
              '${result.elapsedSeconds.toStringAsFixed(2)} s',
            ),
          ),
        ],
      );
    }

    if (result.type == PerformanceType.distance) {
      final speedUnit = _speedUnitForResult(result);

      return Row(
        children: [
          Expanded(
            child: _miniStat(
              'Target Distance',
              '${result.targetValue.toStringAsFixed(0)} m',
            ),
          ),
          Expanded(
            child: _miniStat(
              'End Speed',
              '${result.maxSpeed.toStringAsFixed(1)} $speedUnit',
            ),
          ),
          Expanded(
            child: _miniStat(
              'Time',
              '${result.elapsedSeconds.toStringAsFixed(2)} s',
            ),
          ),
        ],
      );
    }

    final brakeStartSpeed = result.targetValue > 0
        ? result.targetValue
        : result.maxSpeed;

    return Row(
      children: [
        Expanded(
          child: _miniStat(
            'Brake Start',
            '${brakeStartSpeed.toStringAsFixed(1)} ${result.unit}',
          ),
        ),
        Expanded(
          child: _miniStat(
            'Stop Distance',
            '${result.distanceCovered.toStringAsFixed(1)} m',
          ),
        ),
        Expanded(
          child: _miniStat(
            'Stop Time',
            '${result.elapsedSeconds.toStringAsFixed(2)} s',
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.white12,
        foregroundColor: Colors.white,
        title: const Text('Results'),
        actions: [
          IconButton(
            onPressed: _clearResults,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Results',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.25,
              child: Image.asset(
                'assets/images/background.jpeg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          FutureBuilder<List<PerformanceData>>(
            future: _resultsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                );
              }

              final results = snapshot.data ?? [];

              if (results.isEmpty) {
                return const Center(
                  child: Text(
                    'No results saved yet.',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  return _buildResultCard(results[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
