package com.example.android_ip_camera.camera

import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.media.MediaCodec
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.params.StreamConfigurationMap
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.util.Size
import android.view.Surface
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs

class NativeCameraManager(
    private val context: Context,
    private val onError: (String) -> Unit,
) {
    companion object {
        private const val TAG = "CameraManager"
    }

    private val systemCameraManager =
        context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var previewSurface: Surface? = null
    private var encoderSurface: Surface? = null
    private var config = CameraConfiguration()
    private var cameraId: String? = null
    private val sessionReady = AtomicBoolean(false)
    private var sessionReadyLatch: CountDownLatch? = null

    fun getCameraFacingLabel(): String =
        if (config.useFrontCamera) "Front" else "Rear"

    fun updateConfiguration(newConfig: CameraConfiguration) {
        config = newConfig
    }

    fun getConfiguration(): CameraConfiguration = config

    fun listCameraIds(): List<String> = try {
        systemCameraManager.cameraIdList.toList()
    } catch (e: Exception) {
        emptyList()
    }

    fun openPreview(preview: Surface, encoderInput: Surface?) {
        previewSurface = preview
        encoderSurface = encoderInput
        startCameraInternal()
    }

    fun openEncoderOnly(encoderInput: Surface) {
        encoderSurface = encoderInput
        startCameraInternal()
    }

    fun resolveSize(targetW: Int, targetH: Int): Size {
        val id = selectCameraId(config.useFrontCamera) ?: return Size(targetW, targetH)
        return chooseSupportedSize(id, targetW, targetH)
    }

    fun awaitSessionReady(timeoutMs: Long): Boolean {
        if (sessionReady.get()) return true
        val latch = sessionReadyLatch ?: return false
        return try {
            latch.await(timeoutMs, TimeUnit.MILLISECONDS) && sessionReady.get()
        } catch (_: InterruptedException) {
            false
        }
    }

    fun updateEncoderSurface(encoderInput: Surface?) {
        encoderSurface = encoderInput
        if (cameraDevice != null) {
            createCaptureSession()
        }
    }

    fun switchCamera() {
        config = config.copy(useFrontCamera = !config.useFrontCamera)
        closeCamera()
        startCameraInternal()
    }

    fun closeCamera() {
        try {
            captureSession?.close()
        } catch (_: Exception) {
        }
        captureSession = null
        try {
            cameraDevice?.close()
        } catch (_: Exception) {
        }
        cameraDevice = null
        cameraThread?.quitSafely()
        cameraThread = null
        cameraHandler = null
    }

    private fun ensureThread() {
        if (cameraThread == null) {
            cameraThread = HandlerThread("CameraThread").also { it.start() }
            cameraHandler = Handler(cameraThread!!.looper)
        }
    }

    private fun startCameraInternal() {
        ensureThread()
        sessionReady.set(false)
        sessionReadyLatch = CountDownLatch(1)
        closeCaptureSession()
        val id = selectCameraId(config.useFrontCamera)
        if (id == null) {
            onError("No usable camera was found.")
            return
        }
        cameraId = id
        val size = chooseSupportedSize(id, config.width, config.height)
        config = config.copy(width = size.width, height = size.height)
        Log.i(TAG, "Opening camera=$id size=${size.width}x${size.height} fps=${config.fps}")

        val existingDevice = cameraDevice
        if (existingDevice != null) {
            createCaptureSession()
            return
        }

        try {
            systemCameraManager.openCamera(id, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    createCaptureSession()
                }

                override fun onDisconnected(camera: CameraDevice) {
                    Log.w(TAG, "Camera disconnected")
                    camera.close()
                    cameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    Log.e(TAG, "Camera error=$error")
                    onError("Camera error ($error)")
                    camera.close()
                    cameraDevice = null
                }
            }, cameraHandler)
        } catch (e: SecurityException) {
            onError("Camera permission is required to start streaming.")
        } catch (e: Exception) {
            Log.e(TAG, "openCamera failed", e)
            onError(e.message ?: "Failed to open camera")
        }
    }

    private fun closeCaptureSession() {
        try {
            captureSession?.close()
        } catch (_: Exception) {
        }
        captureSession = null
    }

    private fun createCaptureSession() {
        val camera = cameraDevice ?: return
        val surfaces = mutableListOf<Surface>()
        previewSurface?.let { surfaces.add(it) }
        encoderSurface?.let { surfaces.add(it) }
        if (surfaces.isEmpty()) {
            onError("No capture surfaces are available.")
            return
        }

        closeCaptureSession()

        try {
            camera.createCaptureSession(
                surfaces,
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        captureSession = session
                        startRepeatingRequest(session)
                        sessionReady.set(true)
                        sessionReadyLatch?.countDown()
                        Log.i(TAG, "Capture session configured with ${surfaces.size} surface(s)")
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        Log.e(TAG, "Capture session configure failed")
                        sessionReadyLatch?.countDown()
                        onError("Failed to configure camera session")
                    }
                },
                cameraHandler,
            )
        } catch (e: Exception) {
            Log.e(TAG, "createCaptureSession failed", e)
            onError(e.message ?: "Failed to create capture session")
        }
    }

    private fun startRepeatingRequest(session: CameraCaptureSession) {
        val camera = cameraDevice ?: return
        val targets = listOfNotNull(previewSurface, encoderSurface)
        if (targets.isEmpty()) return
        try {
            val builder = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD).apply {
                targets.forEach { addTarget(it) }
                set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, chooseFpsRange(cameraId!!, config.fps))
            }
            session.setRepeatingRequest(builder.build(), null, cameraHandler)
            Log.i(TAG, "Repeating request started")
        } catch (e: Exception) {
            Log.e(TAG, "setRepeatingRequest failed", e)
            onError(e.message ?: "Failed to start camera preview")
        }
    }

    private fun selectCameraId(front: Boolean): String? {
        return try {
            systemCameraManager.cameraIdList.firstOrNull { id ->
                val chars = systemCameraManager.getCameraCharacteristics(id)
                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                if (front) facing == CameraCharacteristics.LENS_FACING_FRONT
                else facing == CameraCharacteristics.LENS_FACING_BACK
            } ?: systemCameraManager.cameraIdList.firstOrNull()
        } catch (e: Exception) {
            null
        }
    }

    private fun chooseSupportedSize(cameraId: String, targetW: Int, targetH: Int): Size {
        return try {
            val map = systemCameraManager
                .getCameraCharacteristics(cameraId)
                .get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                ?: return Size(targetW, targetH)

            val codecSizes = map.getOutputSizes(MediaCodec::class.java)?.toList().orEmpty()
            val surfaceSizes = map.getOutputSizes(Surface::class.java)?.toList().orEmpty()
            val textureSizes = map.getOutputSizes(SurfaceTexture::class.java)?.toList().orEmpty()
            val sizes = when {
                encoderSurface != null && codecSizes.isNotEmpty() -> codecSizes
                encoderSurface != null && surfaceSizes.isNotEmpty() -> surfaceSizes
                textureSizes.isNotEmpty() -> textureSizes
                else -> emptyList()
            }
            if (sizes.isEmpty()) return Size(targetW, targetH)
            sizes.minByOrNull { abs(it.width - targetW) + abs(it.height - targetH) }
                ?: Size(targetW, targetH)
        } catch (e: Exception) {
            Size(targetW, targetH)
        }
    }

    private fun chooseFpsRange(cameraId: String, targetFps: Int): android.util.Range<Int> {
        return try {
            val ranges = systemCameraManager
                .getCameraCharacteristics(cameraId)
                .get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
                ?.toList().orEmpty()
            ranges.minByOrNull { abs(it.upper - targetFps) + abs(it.lower - targetFps) }
                ?: android.util.Range(targetFps, targetFps)
        } catch (_: Exception) {
            android.util.Range(targetFps, targetFps)
        }
    }
}
