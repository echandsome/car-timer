package com.example.car_timer

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.os.Looper
import androidx.core.app.ActivityCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val nativeGpsChannel = "car_timer/native_gps"

    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var nativeLocationCallback: LocationCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            nativeGpsChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (events == null) return
                startNativeGpsStream(events)
            }

            override fun onCancel(arguments: Any?) {
                stopNativeGpsStream()
            }
        })
    }

    private fun startNativeGpsStream(events: EventChannel.EventSink) {
        val fineGranted = ActivityCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarseGranted = ActivityCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        if (!fineGranted && !coarseGranted) {
            events.error(
                "LOCATION_PERMISSION_MISSING",
                "Location permission is not granted.",
                null
            )
            return
        }

        stopNativeGpsStream()

        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            100L
        )
            .setMinUpdateIntervalMillis(100L)
            .setMaxUpdateDelayMillis(0L)
            .setWaitForAccurateLocation(false)
            .build()

        nativeLocationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                for (location: Location in result.locations) {
                    val hasSpeed = location.hasSpeed()
val hasSpeedAccuracy = location.hasSpeedAccuracy()

val payload = hashMapOf<String, Any?>(
    "latitude" to location.latitude,
    "longitude" to location.longitude,
    "accuracy" to location.accuracy.toDouble(),

    // Native Android/Fused speed data.
    "hasSpeed" to hasSpeed,
    "speedMps" to if (hasSpeed) {
        location.speed.toDouble()
    } else {
        0.0
    },

    // Useful for rejecting noisy speed values in Dart.
    "hasSpeedAccuracy" to hasSpeedAccuracy,
    "speedAccuracyMps" to if (hasSpeedAccuracy) {
        location.speedAccuracyMetersPerSecond.toDouble()
    } else {
        null
    },

    "hasBearing" to location.hasBearing(),
    "bearing" to if (location.hasBearing()) {
        location.bearing.toDouble()
    } else {
        null
    },

    "hasAltitude" to location.hasAltitude(),
    "altitude" to if (location.hasAltitude()) {
        location.altitude
    } else {
        null
    },

    // timeMillis = wall-clock timestamp from Android location.
    // elapsedRealtimeNanos = monotonic Android timestamp, better for diagnostics.
    "timeMillis" to location.time,
    "elapsedRealtimeNanos" to location.elapsedRealtimeNanos,
    "provider" to location.provider
)
                    events.success(payload)
                }
            }
        }

        fusedLocationClient?.requestLocationUpdates(
            request,
            nativeLocationCallback!!,
            Looper.getMainLooper()
        )
    }

    private fun stopNativeGpsStream() {
        nativeLocationCallback?.let {
            fusedLocationClient?.removeLocationUpdates(it)
        }
        nativeLocationCallback = null
    }

    override fun onDestroy() {
        stopNativeGpsStream()
        super.onDestroy()
    }
}