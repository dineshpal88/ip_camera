package com.example.android_ip_camera

import android.content.Context
import android.media.MediaCodec
import android.util.Log
import android.view.Surface
import com.example.android_ip_camera.camera.CameraConfiguration
import com.example.android_ip_camera.camera.NativeCameraManager
import com.example.android_ip_camera.encoder.H264Encoder
import com.example.android_ip_camera.network.NetworkUtils
import com.example.android_ip_camera.rtsp.RtspServer
import com.example.android_ip_camera.rtsp.SdpBuilder
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

object IpCameraEngine {
    private const val TAG = "IPCamera"
    const val RTSP_PORT = 8554
    const val STREAM_PATH = "/live"

    private var appContext: Context? = null
    private var cameraManager: NativeCameraManager? = null
    private var encoder: H264Encoder? = null
    private var rtspServer: RtspServer? = null
    private var previewSurface: Surface? = null
    private var config = CameraConfiguration()
    private val streaming = AtomicBoolean(false)
    private val listeners = CopyOnWriteArrayList<(Map<String, Any?>) -> Unit>()
    private var sps: ByteArray? = null
    private var pps: ByteArray? = null
    private var lanOnly = true
    private var lastVideoPtsUs: Long = 0
    private var previewBufferSizeListener: ((Int, Int) -> Unit)? = null

    fun getPreviewBufferSize(): Pair<Int, Int> = Pair(config.width, config.height)

    fun setPreviewBufferSizeListener(listener: ((Int, Int) -> Unit)?) {
        previewBufferSizeListener = listener
    }

    private fun notifyPreviewBufferSize() {
        previewBufferSizeListener?.invoke(config.width, config.height)
    }

    fun initialize(context: Context) {
        appContext = context.applicationContext
        if (cameraManager == null) {
            cameraManager = NativeCameraManager(context.applicationContext) { msg ->
                emit(mapOf("type" to "cameraError", "message" to msg))
            }
        }
    }

    fun setEventListener(listener: ((Map<String, Any?>) -> Unit)?) {
        listeners.clear()
        listener?.let { listeners.add(it) }
    }

    fun getConfiguration(): CameraConfiguration = config

    fun setResolution(width: Int, height: Int) {
        if (streaming.get()) return
        config = config.copy(width = width, height = height)
    }

    fun setFps(fps: Int) {
        if (streaming.get()) return
        config = config.copy(fps = fps)
    }

    fun setBitrate(bitrate: Int) {
        if (streaming.get()) return
        config = config.copy(bitrate = bitrate)
    }

    fun setLanOnlyOnly(enabled: Boolean) {
        lanOnly = enabled
    }

    fun startPreview(surface: Surface) {
        initialize(appContext ?: return)
        previewSurface = surface
        if (streaming.get()) {
            attachCameraToEncoder()
        } else {
            cameraManager?.updateConfiguration(config)
            cameraManager?.openPreview(surface, null)
        }
    }

    fun stopPreview() {
        previewSurface = null
        if (!streaming.get()) {
            cameraManager?.closeCamera()
        }
    }

    fun switchCamera() {
        cameraManager?.switchCamera()
        config = cameraManager?.getConfiguration() ?: config
        emit(mapOf("type" to "stateChanged", "camera" to cameraFacing()))
    }

    fun startStream(): Map<String, Any?> {
        val context = appContext ?: return errorMap("App not initialized")
        if (streaming.get()) return getStreamInfo()

        val ip = NetworkUtils.getWifiIpv4Address(context)
        if (ip.isNullOrBlank()) {
            return errorMap("Connect the phone to Wi-Fi before starting the LAN stream.")
        }

        val manager = cameraManager ?: return errorMap("Camera is not initialized.")
        manager.updateConfiguration(config)
        val resolved = manager.resolveSize(config.width, config.height)
        config = config.copy(width = resolved.width, height = resolved.height)
        notifyPreviewBufferSize()

        val firstFrameLatch = CountDownLatch(1)

        val enc = H264Encoder(
            width = config.width,
            height = config.height,
            bitrate = config.bitrate,
            fps = config.fps,
            onEncodedFrame = { data, pts, flags ->
                if ((flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                    lastVideoPtsUs = pts
                    firstFrameLatch.countDown()
                }
                val isKey = (flags and MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0
                rtspServer?.broadcastFrame(
                    data,
                    pts,
                    isKey,
                    sps,
                    pps,
                )
            },
            onCodecConfig = { s, p ->
                sps = s
                pps = p
            },
            onError = { msg ->
                emit(mapOf("type" to "encoderError", "message" to msg))
                stopStream()
            },
        )

        if (!enc.start()) {
            return errorMap("H.264 hardware encoder is not available on this device.")
        }
        encoder = enc

        attachCameraToEncoder()

        if (!manager.awaitSessionReady(5000)) {
            enc.stop()
            encoder = null
            detachEncoderFromCamera()
            return errorMap("Camera session failed to start for streaming.")
        }

        val sdpReady = waitForSpsPps(enc, 5000)
        if (!sdpReady) {
            enc.stop()
            encoder = null
            detachEncoderFromCamera()
            return errorMap("Failed to obtain H.264 codec configuration.")
        }

        if (!firstFrameLatch.await(5, TimeUnit.SECONDS)) {
            enc.stop()
            encoder = null
            detachEncoderFromCamera()
            return errorMap("Camera is not producing video frames for the stream.")
        }

        val server = RtspServer(
            port = RTSP_PORT,
            streamPath = STREAM_PATH,
            contentBase = "rtsp://$ip:$RTSP_PORT$STREAM_PATH",
            sdpProvider = { buildSdp() },
            onClientConnected = {
                emit(mapOf("type" to "clientConnected", "clientCount" to getClientCount()))
            },
            onClientDisconnected = {
                emit(mapOf("type" to "clientDisconnected", "clientCount" to getClientCount()))
            },
            onPlay = { session ->
                val s = sps
                val p = pps
                // Use a small PTS near stream time so RTP timestamps stay continuous.
                val pts = if (lastVideoPtsUs > 0) lastVideoPtsUs else 0L
                if (s != null && p != null) {
                    rtspServer?.sendCodecConfigToSession(session, s, p, pts)
                }
                encoder?.requestKeyFrame()
                // Request again shortly — first request is sometimes ignored on OEM codecs.
                Thread({
                    try {
                        Thread.sleep(400)
                        encoder?.requestKeyFrame()
                    } catch (_: Exception) {
                    }
                }, "RequestKeyFrame").start()
                Log.i(TAG, "Client started playback, sent codec config and requested keyframe")
            },
            onError = { msg ->
                emit(mapOf("type" to "error", "message" to msg))
            },
        )

        if (!server.start()) {
            enc.stop()
            encoder = null
            return errorMap("RTSP port $RTSP_PORT is already in use.")
        }

        rtspServer = server
        streaming.set(true)
        val info = getStreamInfo()
        emit(mapOf("type" to "streamingStarted", "rtspUrl" to info["rtspUrl"]))
        Log.i(TAG, "Streaming started ${info["rtspUrl"]}")
        return info
    }

    fun stopStream() {
        if (!streaming.getAndSet(false)) return
        rtspServer?.stop()
        rtspServer = null
        encoder?.stop()
        encoder = null
        detachEncoderFromCamera()
        emit(mapOf("type" to "streamingStopped"))
        Log.i(TAG, "Streaming stopped")
    }

    fun isStreaming(): Boolean = streaming.get()

    fun getClientCount(): Int = rtspServer?.getClientCount() ?: 0

    fun requestKeyFrame() {
        encoder?.requestKeyFrame()
    }

    fun getDeviceIp(): String? {
        val context = appContext ?: return null
        return NetworkUtils.getWifiIpv4Address(context)
    }

    fun getStreamInfo(): Map<String, Any?> {
        val ip = getDeviceIp()
        val url = if (!ip.isNullOrBlank()) "rtsp://$ip:$RTSP_PORT$STREAM_PATH" else null
        return mapOf(
            "ip" to (ip ?: ""),
            "port" to RTSP_PORT,
            "path" to STREAM_PATH,
            "rtspUrl" to (url ?: ""),
            "streaming" to streaming.get(),
            "clientCount" to getClientCount(),
            "camera" to cameraFacing(),
            "resolution" to "${config.width}x${config.height}",
            "fps" to config.fps,
            "bitrate" to config.bitrate,
            "lanOnly" to lanOnly,
        )
    }

    fun cameraFacing(): String = cameraManager?.getCameraFacingLabel() ?: "Rear"

    fun dispose() {
        stopStream()
        stopPreview()
        cameraManager?.closeCamera()
        cameraManager = null
        listeners.clear()
    }

    private fun attachCameraToEncoder() {
        val encSurface = encoder?.surface ?: return
        val manager = cameraManager ?: return
        manager.updateConfiguration(config)
        val preview = previewSurface
        if (preview != null) {
            manager.openPreview(preview, encSurface)
        } else {
            manager.openEncoderOnly(encSurface)
        }
    }

    private fun detachEncoderFromCamera() {
        val manager = cameraManager ?: return
        val preview = previewSurface
        if (preview != null) {
            manager.openPreview(preview, null)
        } else {
            manager.closeCamera()
        }
    }

    private fun buildSdp(): String? {
        val s = sps ?: encoder?.getSpsPps()?.first
        val p = pps ?: encoder?.getSpsPps()?.second
        if (s == null || p == null) return null
        return SdpBuilder.buildH264Sdp(
            sessionName = "Android IP Camera",
            controlTrack = "track0",
            sps = s,
            pps = p,
            width = config.width,
            height = config.height,
            fps = config.fps,
        )
    }

    private fun waitForSpsPps(enc: H264Encoder, timeoutMs: Long): Boolean {
        val start = System.currentTimeMillis()
        while (System.currentTimeMillis() - start < timeoutMs) {
            val pair = enc.getSpsPps()
            if (pair != null) {
                sps = pair.first
                pps = pair.second
                return true
            }
            Thread.sleep(50)
        }
        return sps != null && pps != null
    }

    private fun emit(event: Map<String, Any?>) {
        listeners.forEach { listener ->
            try {
                listener(event)
            } catch (e: Exception) {
                Log.w(TAG, "Event listener error", e)
            }
        }
    }

    private fun errorMap(message: String): Map<String, Any?> {
        emit(mapOf("type" to "error", "message" to message))
        return mapOf("error" to message)
    }
}
