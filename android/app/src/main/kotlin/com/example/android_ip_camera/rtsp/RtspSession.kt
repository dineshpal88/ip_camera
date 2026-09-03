package com.example.android_ip_camera.rtsp

import android.util.Log
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.Socket
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

class RtspSession(
    val sessionId: String,
    private val streamPath: String,
    private val contentBase: String,
    private val socket: Socket,
    private val sdp: String,
    private val onPlay: (RtspSession) -> Unit,
    private val onTeardown: (RtspSession) -> Unit,
    private val onClientConnected: () -> Unit,
    private val onClientDisconnected: () -> Unit,
) {
    companion object {
        private const val TAG = "RtspSession"
    }

    var clientRtpPort: Int = 0
    var clientRtcpPort: Int = 0
    var clientAddress: InetAddress? = null
    var useTcpInterleaved: Boolean = false
    var interleavedChannel: Int = 0
    val playing = AtomicBoolean(false)
    val awaitingKeyframe = AtomicBoolean(true)
    private val closed = AtomicBoolean(false)

    private var udpSocket: DatagramSocket? = null
    private var outputStream: OutputStream? = null
    private var reader: BufferedReader? = null
    private val writeLock = Any()

    fun start() {
        Thread({
            try {
                // Use one reader for the whole session. Creating a second BufferedReader
                // on the same InputStream drops pipelined FFmpeg/media_kit requests
                // (DESCRIBE/SETUP) and causes "Failed to recognize file format".
                reader = BufferedReader(InputStreamReader(socket.getInputStream()))
                outputStream = socket.getOutputStream()
                while (!closed.get()) {
                    val request = readRequest(reader!!) ?: break
                    if (request.isBlank()) break
                    val method = processRequest(request)
                    Log.i(TAG, "Handled $method session=$sessionId tcp=$useTcpInterleaved")
                    if (method == "TEARDOWN") break
                    if (method == "PLAY" && useTcpInterleaved) {
                        // Keep connection open for interleaved RTP; stop parsing RTSP text.
                        while (!closed.get() && playing.get()) {
                            Thread.sleep(250)
                        }
                        break
                    }
                }
            } catch (e: Exception) {
                Log.d(TAG, "Session ended: ${e.message}")
            } finally {
                closeSession()
            }
        }, "RtspSession-$sessionId").start()
    }

    private fun readRequest(reader: BufferedReader): String? {
        val sb = StringBuilder()
        val first = reader.readLine() ?: return null
        sb.append(first).append("\r\n")
        while (true) {
            val line = reader.readLine() ?: break
            if (line.isEmpty()) break
            sb.append(line).append("\r\n")
        }
        return sb.toString()
    }

    private fun processRequest(raw: String): String {
        val lines = raw.split("\r\n", "\n").filter { it.isNotBlank() }
        if (lines.isEmpty()) return ""
        val requestLine = lines[0].split(" ")
        if (requestLine.isEmpty()) return ""
        val method = requestLine[0].uppercase(Locale.US)
        val requestTarget = requestLine.getOrNull(1).orEmpty()
        if (!isSupportedRequestTarget(requestTarget)) {
            Log.w(TAG, "Unsupported target: $requestTarget")
            respond(parseCSeq(lines), 404, "Not Found")
            return method
        }
        val cseq = parseCSeq(lines)

        when (method) {
            "OPTIONS" -> respondOptions(cseq)
            "DESCRIBE" -> respondDescribe(cseq)
            "SETUP" -> respondSetup(cseq, lines)
            "PLAY" -> respondPlay(cseq)
            "PAUSE" -> respond(cseq, 200, "OK", mapOf("Session" to sessionId))
            "GET_PARAMETER", "SET_PARAMETER" -> respond(
                cseq,
                200,
                "OK",
                mapOf("Session" to sessionId),
            )
            "TEARDOWN" -> respondTeardown(cseq)
            else -> {
                Log.w(TAG, "Unsupported method: $method")
                respond(cseq, 501, "Not Implemented")
            }
        }
        return method
    }

    private fun parseCSeq(lines: List<String>): Int {
        return lines.firstOrNull { it.uppercase(Locale.US).startsWith("CSEQ:") }
            ?.substringAfter(":")?.trim()?.toIntOrNull() ?: 0
    }

    private fun isSupportedRequestTarget(target: String): Boolean {
        if (target == "*" || target.isBlank()) return true
        val normalizedPath = streamPath.trimEnd('/')
        return target.contains(normalizedPath) ||
            target.contains("/track0") ||
            target.endsWith(normalizedPath) ||
            target.endsWith("$normalizedPath/") ||
            target.endsWith("$normalizedPath/track0")
    }

    private fun respondOptions(cseq: Int) {
        respond(
            cseq,
            200,
            "OK",
            mapOf(
                "Public" to "OPTIONS, DESCRIBE, SETUP, PLAY, PAUSE, TEARDOWN, GET_PARAMETER, SET_PARAMETER",
            ),
        )
    }

    private fun respondDescribe(cseq: Int) {
        val body = sdp
        respond(
            cseq,
            200,
            "OK",
            mapOf(
                "Content-Base" to "$contentBase/",
                "Content-Type" to "application/sdp",
                "Content-Length" to body.toByteArray(Charsets.UTF_8).size.toString(),
            ),
            body,
        )
    }

    private fun respondSetup(cseq: Int, lines: List<String>) {
        val transport = lines.firstOrNull {
            it.uppercase(Locale.US).startsWith("TRANSPORT:")
        }?.substringAfter(":")?.trim().orEmpty()

        // Always use RTP-over-RTSP TCP interleaved.
        // UDP media ports are frequently blocked (macOS/Windows firewall), which makes
        // VLC show the playlist entry with duration 00:00 and no video window.
        useTcpInterleaved = true
        interleavedChannel = Regex("interleaved=(\\d+)", RegexOption.IGNORE_CASE)
            .find(transport)?.groupValues?.getOrNull(1)?.toIntOrNull() ?: 0

        val transportResponse =
            "RTP/AVP/TCP;unicast;interleaved=$interleavedChannel-${interleavedChannel + 1};mode=play"

        respond(
            cseq,
            200,
            "OK",
            mapOf(
                "Transport" to transportResponse,
                "Session" to "$sessionId;timeout=60",
            ),
        )
        Log.i(TAG, "SETUP forced TCP interleaved=$interleavedChannel raw=$transport")
    }

    private fun respondPlay(cseq: Int) {
        val started = playing.compareAndSet(false, true)
        respond(
            cseq,
            200,
            "OK",
            mapOf(
                "Session" to sessionId,
                "RTP-Info" to "url=$contentBase/track0;seq=0;rtptime=0",
                "Range" to "npt=0.000-",
            ),
        )
        if (started) {
            awaitingKeyframe.set(true)
            onPlay(this)
            onClientConnected()
        }
    }

    private fun respondTeardown(cseq: Int) {
        playing.set(false)
        respond(cseq, 200, "OK", mapOf("Session" to sessionId))
        closeSession()
    }

    fun sendRtpPacket(packet: RtpPacket) {
        if (!playing.get() || closed.get()) return
        try {
            if (useTcpInterleaved) {
                synchronized(writeLock) {
                    val out = outputStream ?: return
                    out.write(
                        byteArrayOf(
                            0x24,
                            interleavedChannel.toByte(),
                            ((packet.length shr 8) and 0xFF).toByte(),
                            (packet.length and 0xFF).toByte(),
                        ),
                    )
                    out.write(packet.data, 0, packet.length)
                    out.flush()
                }
            } else {
                val addr = clientAddress ?: return
                val ds = udpSocket ?: return
                ds.send(DatagramPacket(packet.data, packet.length, addr, clientRtpPort))
            }
        } catch (e: Exception) {
            Log.w(TAG, "sendRtp failed: ${e.message}")
            closeSession()
        }
    }

    fun teardown() {
        closeSession()
    }

    private fun closeSession() {
        if (!closed.compareAndSet(false, true)) return
        val wasPlaying = playing.getAndSet(false)
        try {
            udpSocket?.close()
        } catch (_: Exception) {
        }
        udpSocket = null
        try {
            if (!socket.isClosed) socket.close()
        } catch (_: Exception) {
        }
        onTeardown(this)
        if (wasPlaying) onClientDisconnected()
    }

    private fun respond(
        cseq: Int,
        code: Int,
        message: String,
        headers: Map<String, String> = emptyMap(),
        body: String? = null,
    ) {
        synchronized(writeLock) {
            val out = outputStream ?: return
            val payload = body?.toByteArray(Charsets.UTF_8)
            out.write("RTSP/1.0 $code $message\r\n".toByteArray(Charsets.UTF_8))
            out.write("CSeq: $cseq\r\n".toByteArray(Charsets.UTF_8))
            out.write("Server: AndroidIPCamera/1.0\r\n".toByteArray(Charsets.UTF_8))
            headers.forEach { (k, v) ->
                out.write("$k: $v\r\n".toByteArray(Charsets.UTF_8))
            }
            if (payload != null && !headers.keys.any { it.equals("Content-Length", true) }) {
                out.write("Content-Length: ${payload.size}\r\n".toByteArray(Charsets.UTF_8))
            }
            out.write("\r\n".toByteArray(Charsets.UTF_8))
            if (payload != null) out.write(payload)
            out.flush()
        }
    }
}
