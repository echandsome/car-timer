package com.example.car_timer

import android.Manifest
import android.content.pm.PackageManager
import android.location.GnssStatus
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
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
    private val mainHandler = Handler(Looper.getMainLooper())

    private var locationManager: LocationManager? = null
    private var gpsLocationListener: LocationListener? = null
    private var nmeaListener: android.location.OnNmeaMessageListener? = null
    private var gnssStatusCallback: GnssStatus.Callback? = null

    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var fusedLocationCallback: LocationCallback? = null
    private var usingFusedFallback = false

    private var eventSink: EventChannel.EventSink? = null
    private var satelliteCount = 0
    private var usedSatelliteCount = 0
    private var lastGnssElapsedRealtimeNanos = 0L
    private var lastNmeaEmitElapsedRealtimeNanos = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            nativeGpsChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                if (events == null) return
                startNativeGpsStream(events)
            }

            override fun onCancel(arguments: Any?) {
                stopNativeGpsStream()
                eventSink = null
            }
        })
    }

    private fun hasLocationPermission(): Boolean {
        val fineGranted = ActivityCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarseGranted = ActivityCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        return fineGranted || coarseGranted
    }

    private fun startNativeGpsStream(events: EventChannel.EventSink) {
        if (!hasLocationPermission()) {
            events.error(
                "LOCATION_PERMISSION_MISSING",
                "Location permission is not granted.",
                null
            )
            return
        }

        stopNativeGpsStream()
        usingFusedFallback = false

        val manager = locationManager
        val gpsEnabled = manager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true

        if (manager != null && gpsEnabled) {
            startGnssProvider(manager, events)
            return
        }

        startFusedFallback(events)
    }

    @Suppress("MissingPermission")
    private fun startGnssProvider(manager: LocationManager, events: EventChannel.EventSink) {
        try {
            manager.sendExtraCommand(LocationManager.GPS_PROVIDER, "force_xtra_injection", Bundle())
            manager.sendExtraCommand(LocationManager.GPS_PROVIDER, "force_time_injection", Bundle())
        } catch (_: Exception) {
        }

        val listener = LocationListener { location ->
            lastGnssElapsedRealtimeNanos = location.elapsedRealtimeNanos
            emitLocation(
                events = events,
                location = location,
                providerOverride = "gnss"
            )
        }
        gpsLocationListener = listener

        try {
            manager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                0L,
                0f,
                listener,
                Looper.getMainLooper()
            )
        } catch (error: Exception) {
            startFusedFallback(events)
            return
        }

        registerGnssStatus(manager)
        registerNmeaListener(manager, events)
    }

    @Suppress("MissingPermission")
    private fun registerGnssStatus(manager: LocationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return

        val callback = object : GnssStatus.Callback() {
            override fun onSatelliteStatusChanged(status: GnssStatus) {
                var used = 0
                for (i in 0 until status.satelliteCount) {
                    if (status.usedInFix(i)) used++
                }
                satelliteCount = status.satelliteCount
                usedSatelliteCount = used
            }
        }
        gnssStatusCallback = callback

        try {
            manager.registerGnssStatusCallback(callback, mainHandler)
        } catch (_: Exception) {
        }
    }

    @Suppress("MissingPermission")
    private fun registerNmeaListener(manager: LocationManager, events: EventChannel.EventSink) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return

        val listener = android.location.OnNmeaMessageListener { message, _ ->
            handleNmeaMessage(message, events)
        }
        nmeaListener = listener

        try {
            manager.addNmeaListener(listener, mainHandler)
        } catch (_: Exception) {
        }
    }

    private fun handleNmeaMessage(message: String, events: EventChannel.EventSink) {
        // RMC carries Doppler speed in knots and is often emitted more often than Location.
        val sentence = message.trim()
        if (!sentence.contains("RMC", ignoreCase = true)) return

        val starIndex = sentence.indexOf('*')
        val body = if (starIndex > 0) sentence.substring(0, starIndex) else sentence
        val fields = body.split(',')
        if (fields.size < 8) return

        val status = fields.getOrNull(2)
        if (status != null && status != "A") return

        val knots = fields.getOrNull(7)?.toDoubleOrNull() ?: return
        if (!knots.isFinite() || knots < 0.0) return

        val nowNanos = SystemClock.elapsedRealtimeNanos()
        if (nowNanos - lastGnssElapsedRealtimeNanos < 40_000_000L) return
        if (nowNanos - lastNmeaEmitElapsedRealtimeNanos < 40_000_000L) return
        lastNmeaEmitElapsedRealtimeNanos = nowNanos

        val speedMps = knots * 0.514444
        val payload = hashMapOf<String, Any?>(
            "hasSpeed" to true,
            "speedMps" to speedMps,
            "hasSpeedAccuracy" to false,
            "timeMillis" to System.currentTimeMillis(),
            "elapsedRealtimeNanos" to nowNanos,
            "provider" to "nmea",
            "satelliteCount" to satelliteCount,
            "usedSatelliteCount" to usedSatelliteCount,
            "nmeaSpeedOnly" to true
        )

        events.success(payload)
    }

    @Suppress("MissingPermission")
    private fun startFusedFallback(events: EventChannel.EventSink) {
        usingFusedFallback = true

        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            50L
        )
            .setMinUpdateIntervalMillis(0L)
            .setMinUpdateDistanceMeters(0f)
            .setMaxUpdateDelayMillis(0L)
            .setWaitForAccurateLocation(false)
            .build()

        fusedLocationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                for (location in result.locations) {
                    emitLocation(
                        events = events,
                        location = location,
                        providerOverride = "fused"
                    )
                }
            }
        }

        fusedLocationClient?.requestLocationUpdates(
            request,
            fusedLocationCallback!!,
            Looper.getMainLooper()
        )
    }

    private fun emitLocation(
        events: EventChannel.EventSink,
        location: Location,
        providerOverride: String
    ) {
        val hasSpeed = location.hasSpeed()
        val hasSpeedAccuracy = location.hasSpeedAccuracy()

        val payload = hashMapOf<String, Any?>(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to location.accuracy.toDouble(),
            "hasSpeed" to hasSpeed,
            "speedMps" to if (hasSpeed) location.speed.toDouble() else 0.0,
            "hasSpeedAccuracy" to hasSpeedAccuracy,
            "speedAccuracyMps" to if (hasSpeedAccuracy) {
                location.speedAccuracyMetersPerSecond.toDouble()
            } else {
                null
            },
            "hasBearing" to location.hasBearing(),
            "bearing" to if (location.hasBearing()) location.bearing.toDouble() else null,
            "hasAltitude" to location.hasAltitude(),
            "altitude" to if (location.hasAltitude()) location.altitude else null,
            "timeMillis" to location.time,
            "elapsedRealtimeNanos" to location.elapsedRealtimeNanos,
            "provider" to providerOverride,
            "satelliteCount" to satelliteCount,
            "usedSatelliteCount" to usedSatelliteCount,
            "nmeaSpeedOnly" to false
        )

        events.success(payload)
    }

    private fun stopNativeGpsStream() {
        gpsLocationListener?.let { listener ->
            try {
                locationManager?.removeUpdates(listener)
            } catch (_: Exception) {
            }
        }
        gpsLocationListener = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            nmeaListener?.let { listener ->
                try {
                    locationManager?.removeNmeaListener(listener)
                } catch (_: Exception) {
                }
            }
            gnssStatusCallback?.let { callback ->
                try {
                    locationManager?.unregisterGnssStatusCallback(callback)
                } catch (_: Exception) {
                }
            }
        }
        nmeaListener = null
        gnssStatusCallback = null

        fusedLocationCallback?.let { callback ->
            fusedLocationClient?.removeLocationUpdates(callback)
        }
        fusedLocationCallback = null
        usingFusedFallback = false
        lastGnssElapsedRealtimeNanos = 0L
        lastNmeaEmitElapsedRealtimeNanos = 0L
    }

    override fun onDestroy() {
        stopNativeGpsStream()
        super.onDestroy()
    }
}
