package com.example.android_ip_camera.encoder

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import com.example.android_ip_camera.rtsp.NalUtils
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

class H264Encoder(
    private val width: Int,
    private val height: Int,
    private val bitrate: Int,
    private val fps: Int,
    private val onEncodedFrame: (ByteArray, Long, Int) -> Unit,
    private val onCodecConfig: (ByteArray, ByteArray) -> Unit,
    private val onError: (String) -> Unit,
) {
    companion object {
        private const val TAG = "H264Encoder"
        private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC
        private const val IFRAME_INTERVAL = 1
    }

    private var codec: MediaCodec? = null
    private var inputSurface: Surface? = null
    private var encoderThread: HandlerThread? = null
    private var encoderHandler: Handler? = null
    private val running = AtomicBoolean(false)
    private var sps: ByteArray? = null
    private var pps: ByteArray? = null

    val surface: Surface?
        get() = inputSurface

    fun start(): Boolean {
        stopInternal()
        val baseFormat = createBaseFormat()
        if (startWithFormat(applyBaselineProfile(baseFormat))) {
            return true
        }
        Log.w(TAG, "Baseline profile unavailable, retrying with default encoder settings")
        if (startWithFormat(baseFormat)) {
            return true
        }
        onError("H.264 encoder unavailable")
        return false
    }

    private fun createBaseFormat(): MediaFormat {
        return MediaFormat.createVideoFormat(MIME, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, IFRAME_INTERVAL)
            setInteger(MediaFormat.KEY_BITRATE_MODE, MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR)
        }
    }

    private fun applyBaselineProfile(format: MediaFormat): MediaFormat {
        return MediaFormat.createVideoFormat(MIME, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, format.getInteger(MediaFormat.KEY_BIT_RATE))
            setInteger(MediaFormat.KEY_FRAME_RATE, format.getInteger(MediaFormat.KEY_FRAME_RATE))
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, format.getInteger(MediaFormat.KEY_I_FRAME_INTERVAL))
            setInteger(MediaFormat.KEY_BITRATE_MODE, MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR)
            setInteger(MediaFormat.KEY_PROFILE, MediaCodecInfo.CodecProfileLevel.AVCProfileBaseline)
            setInteger(MediaFormat.KEY_LEVEL, MediaCodecInfo.CodecProfileLevel.AVCLevel31)
        }
    }

    private fun startWithFormat(format: MediaFormat): Boolean {
        try {
            val encoder = MediaCodec.createEncoderByType(MIME)
            encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            inputSurface = encoder.createInputSurface()
            encoderThread = HandlerThread("H264EncoderThread").also { it.start() }
            encoderHandler = Handler(encoderThread!!.looper)
            encoder.setCallback(object : MediaCodec.Callback() {
                override fun onInputBufferAvailable(codec: MediaCodec, index: Int) {}

                override fun onOutputBufferAvailable(
                    codec: MediaCodec,
                    index: Int,
                    info: MediaCodec.BufferInfo,
                ) {
                    handleOutputBuffer(codec, index, info)
                }

                override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {
                    Log.e(TAG, "Encoder error: ${e.message}", e)
                    onError(e.message ?: "Encoder error")
                }

                override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {
                    extractCodecConfig(format)
                }
            }, encoderHandler)
            encoder.start()
            codec = encoder
            running.set(true)
            Log.i(TAG, "Started encoder ${width}x$height @ ${fps}fps bitrate=$bitrate name=${encoder.name}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start encoder", e)
            stopInternal()
            return false
        }
    }

    fun requestKeyFrame() {
        val encoder = codec ?: return
        try {
            val params = android.os.Bundle()
            params.putInt(MediaCodec.PARAMETER_KEY_REQUEST_SYNC_FRAME, 0)
            encoder.setParameters(params)
            Log.i(TAG, "Requested sync frame")
        } catch (e: Exception) {
            Log.w(TAG, "requestKeyFrame failed", e)
        }
    }

    fun stop() {
        running.set(false)
        stopInternal()
    }

    fun getSpsPps(): Pair<ByteArray, ByteArray>? {
        val s = sps
        val p = pps
        return if (s != null && p != null) Pair(s, p) else null
    }

    private fun stopInternal() {
        try {
            codec?.stop()
        } catch (_: Exception) {
        }
        try {
            codec?.release()
        } catch (_: Exception) {
        }
        codec = null
        try {
            inputSurface?.release()
        } catch (_: Exception) {
        }
        inputSurface = null
        encoderThread?.quitSafely()
        encoderThread = null
        encoderHandler = null
    }

    private fun extractCodecConfig(format: MediaFormat) {
        val csd0 = format.getByteBuffer("csd-0") ?: return
        val csd1 = format.getByteBuffer("csd-1")
        val parsed = NalUtils.parseCodecSpecificData(
            byteBufferToArray(csd0),
            csd1?.let { byteBufferToArray(it) },
        ) ?: return
        sps = parsed.first
        pps = parsed.second
        onCodecConfig(parsed.first, parsed.second)
        Log.i(
            TAG,
            "Codec config SPS=${sps!!.size} type=${NalUtils.nalType(sps!!)} " +
                "PPS=${pps!!.size} type=${NalUtils.nalType(pps!!)}",
        )
    }

    private fun handleOutputBuffer(codec: MediaCodec, index: Int, info: MediaCodec.BufferInfo) {
        if (!running.get()) {
            codec.releaseOutputBuffer(index, false)
            return
        }
        if (info.size <= 0) {
            codec.releaseOutputBuffer(index, false)
            return
        }
        val buffer = codec.getOutputBuffer(index) ?: run {
            codec.releaseOutputBuffer(index, false)
            return
        }
        val data = ByteArray(info.size)
        buffer.position(info.offset)
        buffer.limit(info.offset + info.size)
        buffer.get(data)
        codec.releaseOutputBuffer(index, false)

        if ((info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
            val parsed = NalUtils.parseCodecSpecificData(data, null)
            if (parsed != null) {
                sps = parsed.first
                pps = parsed.second
                onCodecConfig(parsed.first, parsed.second)
            }
            return
        }

        onEncodedFrame(data, info.presentationTimeUs, info.flags)
    }

    private fun byteBufferToArray(buffer: ByteBuffer): ByteArray {
        val dup = buffer.duplicate()
        dup.clear()
        val arr = ByteArray(dup.remaining())
        dup.get(arr)
        return arr
    }
}
