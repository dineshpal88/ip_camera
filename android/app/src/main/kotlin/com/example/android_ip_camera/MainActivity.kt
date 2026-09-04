package com.example.android_ip_camera

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.example.android_ip_camera.service.CameraStreamingService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "android_ip_camera/camera"
        private const val EVENT_CHANNEL = "android_ip_camera/events"
        private const val PREVIEW_VIEW = "android_ip_camera/preview"
        private const val PERMISSION_REQUEST = 1001
    }

    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        IpCameraEngine.initialize(this)

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(PREVIEW_VIEW, CameraPreviewFactory())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        IpCameraEngine.initialize(this)
                        IpCameraEngine.setEventListener { event -> emitEvent(event) }
                        result.success(true)
                    }
                    "startPreview" -> result.success(true)
                    "stopPreview" -> {
                        IpCameraEngine.stopPreview()
                        result.success(true)
                    }
                    "startStream" -> {
                        if (!hasRequiredPermissions()) {
                            result.error("PERMISSION", "Camera permission is required.", null)
                            return@setMethodCallHandler
                        }
                        Thread({
                            val info = IpCameraEngine.startStream()
                            runOnUiThread {
                                if (info.containsKey("error")) {
                                    result.error("STREAM", info["error"].toString(), null)
                                } else {
                                    startStreamingService(info["rtspUrl"]?.toString())
                                    result.success(info)
                                }
                            }
                        }, "StartStream").start()
                    }
                    "stopStream" -> {
                        Thread({
                            IpCameraEngine.stopStream()
                            runOnUiThread {
                                stopService(Intent(this, CameraStreamingService::class.java))
                                result.success(true)
                            }
                        }, "StopStream").start()
                    }
                    "switchCamera" -> {
                        IpCameraEngine.switchCamera()
                        result.success(IpCameraEngine.getStreamInfo())
                    }
                    "setResolution" -> {
                        val w = call.argument<Int>("width") ?: 720
                        val h = call.argument<Int>("height") ?: 1280
                        IpCameraEngine.setResolution(w, h)
                        result.success(true)
                    }
                    "setFps" -> {
                        IpCameraEngine.setFps(call.argument<Int>("fps") ?: 30)
                        result.success(true)
                    }
                    "setBitrate" -> {
                        IpCameraEngine.setBitrate(call.argument<Int>("bitrate") ?: 2_000_000)
                        result.success(true)
                    }
                    "getDeviceIp" -> result.success(IpCameraEngine.getDeviceIp())
                    "getStreamInfo" -> result.success(IpCameraEngine.getStreamInfo())
                    "isStreaming" -> result.success(IpCameraEngine.isStreaming())
                    "getClientCount" -> result.success(IpCameraEngine.getClientCount())
                    "requestKeyFrame" -> {
                        IpCameraEngine.requestKeyFrame()
                        result.success(true)
                    }
                    "setLanOnly" -> {
                        IpCameraEngine.setLanOnlyOnly(call.argument<Boolean>("enabled") ?: true)
                        result.success(true)
                    }
                    "dispose" -> {
                        IpCameraEngine.dispose()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    IpCameraEngine.setEventListener { event -> emitEvent(event) }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestPermissionsIfNeeded()
    }

    override fun onDestroy() {
        if (!IpCameraEngine.isStreaming()) {
            IpCameraEngine.dispose()
        }
        super.onDestroy()
    }

    private fun emitEvent(event: Map<String, Any?>) {
        runOnUiThread {
            eventSink?.success(event)
        }
    }

    private fun startStreamingService(rtspUrl: String?) {
        val intent = Intent(this, CameraStreamingService::class.java).apply {
            putExtra("rtspUrl", rtspUrl)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun hasRequiredPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermissionsIfNeeded() {
        val needed = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            needed.add(Manifest.permission.CAMERA)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (needed.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, needed.toTypedArray(), PERMISSION_REQUEST)
        }
    }
}
