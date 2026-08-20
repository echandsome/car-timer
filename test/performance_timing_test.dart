import 'package:car_timer/services/performance_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PerformanceService service;

  setUp(() {
    service = PerformanceService();
    service.reset();
  });

  tearDown(() {
    service.reset();
  });

  test('interpolates rollout and 100 km/h on the GPS clock', () {
    service.startSession(
      type: PerformanceType.speed,
      presetName: '0-100 km/h',
      targetValue: 100.0,
      unit: 'km/h',
      initialSpeed: 0.2,
      initialElapsedRealtimeNanos: 1 * 1000 * 1000 * 1000,
      waitForStartTrigger: true,
    );

    expect(service.isArmed, isTrue);
    expect(service.getCurrentElapsedTime(), 0.0);

    service.updatePerformance(
      currentSpeed: 0.2,
      distanceDelta: 0.0,
      elapsedRealtimeNanos: 2 * 1000 * 1000 * 1000,
    );
    service.updatePerformance(
      currentSpeed: 12.0,
      distanceDelta: 1.5,
      elapsedRealtimeNanos: 3 * 1000 * 1000 * 1000,
    );

    expect(service.isArmed, isFalse);
    expect(service.hasTargetReached, isFalse);

    service.updatePerformance(
      currentSpeed: 40.0,
      distanceDelta: 8.0,
      elapsedRealtimeNanos: 5 * 1000 * 1000 * 1000,
    );
    service.updatePerformance(
      currentSpeed: 90.0,
      distanceDelta: 20.0,
      elapsedRealtimeNanos: 7 * 1000 * 1000 * 1000,
    );
    service.updatePerformance(
      currentSpeed: 110.0,
      distanceDelta: 12.0,
      elapsedRealtimeNanos: 8 * 1000 * 1000 * 1000,
    );

    expect(service.hasTargetReached, isTrue);

    final elapsed = service.getCurrentElapsedTime();
    // Start interpolates 1 km/h between 0.2 at t=2s and 12 at t=3s.
    // Stop interpolates 100 km/h between 90 at t=7s and 110 at t=8s.
    expect(elapsed, closeTo(5.432, 0.05));
  });

  test('does not start the clock from button-press wait time', () {
    service.startSession(
      type: PerformanceType.speed,
      presetName: '0-100 km/h',
      targetValue: 100.0,
      unit: 'km/h',
      initialSpeed: 0.0,
      initialElapsedRealtimeNanos: 10 * 1000 * 1000 * 1000,
      waitForStartTrigger: true,
    );

    service.updatePerformance(
      currentSpeed: 0.0,
      distanceDelta: 0.0,
      elapsedRealtimeNanos: 14 * 1000 * 1000 * 1000,
    );
    service.updatePerformance(
      currentSpeed: 20.0,
      distanceDelta: 2.0,
      elapsedRealtimeNanos: 15 * 1000 * 1000 * 1000,
    );
    service.updatePerformance(
      currentSpeed: 100.0,
      distanceDelta: 30.0,
      elapsedRealtimeNanos: 19 * 1000 * 1000 * 1000,
    );

    expect(service.hasTargetReached, isTrue);
    // If t0 were the arm/button time, elapsed would include the 4s wait (~9s).
    expect(service.getCurrentElapsedTime(), lessThan(5.2));
    expect(service.getCurrentElapsedTime(), greaterThan(4.7));
  });

  test('interpolates braking stop at 0.5 km/h', () {
    service.startSession(
      type: PerformanceType.braking,
      presetName: 'Braking',
      targetValue: 100.0,
      unit: 'km/h',
      initialSpeed: 100.0,
      initialElapsedRealtimeNanos: 1 * 1000 * 1000 * 1000,
      waitForStartTrigger: false,
    );

    service.updatePerformance(
      currentSpeed: 40.0,
      distanceDelta: 12.0,
      elapsedRealtimeNanos: 3 * 1000 * 1000 * 1000,
    );
    service.updatePerformance(
      currentSpeed: 0.2,
      distanceDelta: 4.0,
      elapsedRealtimeNanos: 4 * 1000 * 1000 * 1000,
    );

    expect(service.hasTargetReached, isTrue);
    expect(service.getCurrentElapsedTime(), closeTo(2.992, 0.05));
  });

  test('TimingMath interpolates a crossing between two GPS samples', () {
    final crossing = TimingMath.interpolateCrossingNanos(
      previousValue: 90,
      currentValue: 110,
      targetValue: 100,
      previousNanos: 0,
      currentNanos: 1000000000,
    );

    expect(TimingMath.nanosToSeconds(0, crossing), closeTo(0.5, 0.0001));
  });

  test('interpolates start and 100 km/h from a single sparse GPS sample', () {
    service.startSession(
      type: PerformanceType.speed,
      presetName: '0-100 km/h',
      targetValue: 100.0,
      unit: 'km/h',
      initialSpeed: 0.2,
      initialElapsedRealtimeNanos: 1 * 1000 * 1000 * 1000,
      waitForStartTrigger: true,
    );

    service.updatePerformance(
      currentSpeed: 0.2,
      distanceDelta: 0.0,
      elapsedRealtimeNanos: 2 * 1000 * 1000 * 1000,
    );
    service.updatePerformance(
      currentSpeed: 110.0,
      distanceDelta: 20.0,
      elapsedRealtimeNanos: 3 * 1000 * 1000 * 1000,
    );

    expect(service.hasTargetReached, isTrue);
    // 1 km/h at 2.007s, 100 km/h at 2.907s => ~0.900s
    expect(service.getCurrentElapsedTime(), closeTo(0.900, 0.02));
  });

  test('ignores a wall-clock sample once the run is on the GPS clock', () {
    service.startSession(
      type: PerformanceType.speed,
      presetName: '0-100 km/h',
      targetValue: 100.0,
      unit: 'km/h',
      initialSpeed: 0.0,
      initialElapsedRealtimeNanos: 1 * 1000 * 1000 * 1000,
      waitForStartTrigger: true,
    );

    service.updatePerformance(
      currentSpeed: 20.0,
      distanceDelta: 2.0,
      elapsedRealtimeNanos: 2 * 1000 * 1000 * 1000,
    );
    service.updatePerformance(
      currentSpeed: 100.0,
      distanceDelta: 30.0,
      sampleTime: DateTime.now().add(const Duration(seconds: 30)),
    );
    service.updatePerformance(
      currentSpeed: 100.0,
      distanceDelta: 5.0,
      elapsedRealtimeNanos: 6 * 1000 * 1000 * 1000,
    );

    expect(service.hasTargetReached, isTrue);
    expect(service.getCurrentElapsedTime(), lessThan(6.0));
  });
}
