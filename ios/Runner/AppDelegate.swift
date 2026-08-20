import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var gpsHandler: NativeGpsStreamHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let registrar = self.registrar(forPlugin: "NativeGps") {
      let channel = FlutterEventChannel(
        name: "car_timer/native_gps",
        binaryMessenger: registrar.messenger()
      )
      let handler = NativeGpsStreamHandler()
      gpsHandler = handler
      channel.setStreamHandler(handler)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private final class NativeGpsStreamHandler: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private var eventSink: FlutterEventSink?

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    locationManager.distanceFilter = kCLDistanceFilterNone
    locationManager.activityType = .automotiveNavigation
    locationManager.pausesLocationUpdatesAutomatically = false
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events

    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = locationManager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }

    if status == .notDetermined {
      locationManager.requestWhenInUseAuthorization()
    } else if status == .denied || status == .restricted {
      events(
        FlutterError(
          code: "LOCATION_PERMISSION_MISSING",
          message: "Location permission is not granted.",
          details: nil
        )
      )
      return nil
    }

    locationManager.startUpdatingLocation()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    locationManager.stopUpdatingLocation()
    eventSink = nil
    return nil
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if #available(iOS 14.0, *) {
      if manager.authorizationStatus == .authorizedWhenInUse ||
          manager.authorizationStatus == .authorizedAlways {
        manager.startUpdatingLocation()
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    if status == .authorizedWhenInUse || status == .authorizedAlways {
      manager.startUpdatingLocation()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let events = eventSink else { return }

    for location in locations {
      let hasSpeed = location.speed >= 0
      let timestampMillis = Int64(location.timestamp.timeIntervalSince1970 * 1000.0)
      let elapsedNanos = Int64(location.timestamp.timeIntervalSince1970 * 1_000_000_000.0)

      var payload: [String: Any] = [
        "latitude": location.coordinate.latitude,
        "longitude": location.coordinate.longitude,
        "accuracy": location.horizontalAccuracy,
        "hasSpeed": hasSpeed,
        "speedMps": hasSpeed ? location.speed : 0.0,
        "hasSpeedAccuracy": location.speedAccuracy >= 0,
        "hasBearing": location.course >= 0,
        "hasAltitude": true,
        "altitude": location.altitude,
        "timeMillis": timestampMillis,
        "elapsedRealtimeNanos": elapsedNanos,
        "provider": "gnss",
        "satelliteCount": 0,
        "usedSatelliteCount": 0,
        "nmeaSpeedOnly": false
      ]

      if location.speedAccuracy >= 0 {
        payload["speedAccuracyMps"] = location.speedAccuracy
      }
      if location.course >= 0 {
        payload["bearing"] = location.course
      }

      events(payload)
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    eventSink?(
      FlutterError(
        code: "LOCATION_ERROR",
        message: error.localizedDescription,
        details: nil
      )
    )
  }
}
