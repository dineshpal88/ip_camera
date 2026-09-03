package com.example.android_ip_camera.rtsp

import android.util.Log
import java.net.ServerSocket
import java.net.Socket
import java.util.UUID
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class RtspServer(
    private val port: Int = 8554,
    private val streamPath: String = "/live",
    private val contentBase: String,
    private val sdpProvider: () -> String?,
    private val onClientConnected: () -> Unit,
    private val onClientDisconnected: () -> Unit,
    private val onPlay: (RtspSession) -> Unit,
    private val onError: (String) -> Unit,
) {
    companion object {
        private const val TAG = "RtspServer"
    }

    private var serverSocket: ServerSocket? = null
    private var acceptThread: Thread? = null
    private val running = AtomicBoolean(false)
    private val sessions = CopyOnWriteArrayList<RtspSession>()
    private val clientCount = AtomicInteger(0)
    private val packetizer = RtpH264Packetizer()

    val activeSessions: List<RtspSession>
        get() = sessions.filter { it.playing.get() }

    fun getClientCount(): Int = clientCount.get()

    fun start(): Boolean {
        if (running.get()) return true
        return try {
            serverSocket = ServerSocket(port)
            running.set(true)
            acceptThread = Thread({
                while (running.get()) {
                    try {
                        val socket = serverSocket?.accept() ?: break
                        socket.soTimeout = 0
                        handleClient(socket)
                    } catch (e: Exception) {
                        if (running.get()) Log.w(TAG, "Accept error: ${e.message}")
                    }
                }
            }, "RtspAccept").also { it.start() }
            Log.i(TAG, "RTSP server started on port $port path=$streamPath")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start RTSP server", e)
            onError("RTSP port $port is already in use.")
            stop()
            false
        }
    }

    fun stop() {
        running.set(false)
        sessions.toList().forEach { it.teardown() }
        sessions.clear()
        clientCount.set(0)
        try {
            serverSocket?.close()
        } catch (_: Exception) {
        }
        serverSocket = null
        acceptThread?.interrupt()
        acceptThread = null
        Log.i(TAG, "RTSP server stopped")
    }

    fun broadcastFrame(
        frame: ByteArray,
        presentationTimeUs: Long,
        isKeyFrame: Boolean,
        sps: ByteArray? = null,
        pps: ByteArray? = null,
    ) {
        var nals = packetizer.extractNalUnits(frame)
            .filter { packetizer.isStreamableNal(it) }
            .map { NalUtils.stripEmulationAndPrefixes(it) }
            .filter { NalUtils.isValidNal(it) }
        if (nals.isEmpty()) return
        val idr = isKeyFrame || packetizer.containsIdr(nals)
        if (idr && sps != null && pps != null) {
            val cleanSps = NalUtils.stripEmulationAndPrefixes(sps)
            val cleanPps = NalUtils.stripEmulationAndPrefixes(pps)
            if (NalUtils.nalType(cleanSps) == 7 && NalUtils.nalType(cleanPps) == 8) {
                // Remove any in-band SPS/PPS duplicates, then prepend clean ones.
                nals = listOf(cleanSps, cleanPps) + nals.filter {
                    val t = NalUtils.nalType(it)
                    t != 7 && t != 8
                }
            }
        }
        val rtpPackets = packetizer.packetize(nals, presentationTimeUs, idr)
        val active = activeSessions
        if (active.isEmpty()) return
        for (session in active) {
            if (session.awaitingKeyframe.get()) {
                if (!idr) continue
                session.awaitingKeyframe.set(false)
                Log.i(TAG, "Sending first IDR/keyframe to session=${session.sessionId}")
            }
            for (rtp in rtpPackets) {
                session.sendRtpPacket(rtp)
            }
        }
    }

    fun sendCodecConfigToSession(
        session: RtspSession,
        sps: ByteArray,
        pps: ByteArray,
        presentationTimeUs: Long,
    ) {
        if (!session.playing.get()) return
        val cleanSps = NalUtils.stripEmulationAndPrefixes(sps)
        val cleanPps = NalUtils.stripEmulationAndPrefixes(pps)
        if (NalUtils.nalType(cleanSps) != 7 || NalUtils.nalType(cleanPps) != 8) {
            Log.e(TAG, "Refusing to send invalid SPS/PPS types ${NalUtils.nalType(cleanSps)}/${NalUtils.nalType(cleanPps)}")
            return
        }
        // Send SPS and PPS as separate single-NAL packets (more compatible than STAP-A).
        val rtpPackets = packetizer.packetize(listOf(cleanSps, cleanPps), presentationTimeUs, marker = false)
        for (rtp in rtpPackets) {
            session.sendRtpPacket(rtp)
        }
        Log.i(TAG, "Sent SPS(${cleanSps.size})+PPS(${cleanPps.size}) to session=${session.sessionId}")
    }

    fun broadcastCodecConfig(sps: ByteArray, pps: ByteArray, presentationTimeUs: Long) {
        for (session in activeSessions) {
            sendCodecConfigToSession(session, sps, pps, presentationTimeUs)
        }
    }

    fun requestKeyFrameForClients(onRequest: () -> Unit) {
        if (activeSessions.isNotEmpty()) onRequest()
    }

    private fun handleClient(socket: Socket) {
        Thread({
            try {
                val sdp = sdpProvider() ?: run {
                    Log.w(TAG, "No SDP available; rejecting client")
                    socket.close()
                    return@Thread
                }
                val sessionId = UUID.randomUUID().toString().replace("-", "")
                val session = RtspSession(
                    sessionId = sessionId,
                    streamPath = streamPath,
                    contentBase = contentBase,
                    socket = socket,
                    sdp = sdp,
                    onPlay = { s ->
                        sessions.add(s)
                        onPlay(s)
                    },
                    onTeardown = { s ->
                        sessions.remove(s)
                    },
                    onClientConnected = {
                        clientCount.incrementAndGet()
                        onClientConnected()
                    },
                    onClientDisconnected = {
                        clientCount.updateAndGet { maxOf(0, it - 1) }
                        onClientDisconnected()
                    },
                )
                // Session owns the socket I/O from the first request onward.
                session.start()
            } catch (e: Exception) {
                Log.d(TAG, "Client handler ended: ${e.message}")
                try {
                    socket.close()
                } catch (_: Exception) {
                }
            }
        }, "RtspClient").start()
    }
}
