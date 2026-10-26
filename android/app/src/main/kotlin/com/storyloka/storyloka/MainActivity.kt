package com.storyloka.storyloka

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val EVENT_CHANNEL = "storyloka/light"
    private val METHOD_CHANNEL = "storyloka/light_status"

    private var sensorManager: SensorManager? = null
    private var lightSensor: Sensor? = null
    private var sensorEventListener: SensorEventListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        lightSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LIGHT)

        // MethodChannel untuk cek ketersediaan sensor cahaya — PRD §10.4
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSensorAvailable", "hasLightSensor" -> {
                    result.success(lightSensor != null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // EventChannel "storyloka/light" mengirim nilai lux (double) — PRD §10.4
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    val sensor = lightSensor
                    val manager = sensorManager
                    if (sensor == null || manager == null) {
                        events?.error("UNAVAILABLE", "Sensor cahaya tidak tersedia pada perangkat ini", null)
                        return
                    }

                    sensorEventListener = object : SensorEventListener {
                        override fun onSensorChanged(event: SensorEvent?) {
                            if (event != null && event.values.isNotEmpty()) {
                                val lux = event.values[0].toDouble()
                                events?.success(lux)
                            }
                        }

                        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
                            // No-op
                        }
                    }

                    manager.registerListener(
                        sensorEventListener,
                        sensor,
                        SensorManager.SENSOR_DELAY_NORMAL
                    )
                }

                override fun onCancel(arguments: Any?) {
                    sensorEventListener?.let {
                        sensorManager?.unregisterListener(it)
                    }
                    sensorEventListener = null
                }
            }
        )
    }

    override fun onDestroy() {
        sensorEventListener?.let {
            sensorManager?.unregisterListener(it)
        }
        sensorEventListener = null
        super.onDestroy()
    }
}
