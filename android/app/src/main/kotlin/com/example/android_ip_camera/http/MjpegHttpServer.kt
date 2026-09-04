package com.example.android_ip_camera.http

import android.util.Log
import java.io.BufferedOutputStream
import java.io.IOException
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * Lightweight MJPEG HTTP server for browser playback.
 * Path: GET /stream.mjpg  (also / and /stream)
 */
class MjpegHttpServer(
    private val port: Int = 8080,
) {
    companion object {
        private const val TAG = "MjpegHttpServer"
        private const val BOUNDARY = "ipcameraframe"
    }

    private val running = AtomicBoolean(false)
    private val latestFrame = AtomicReference<ByteArray?>(null)
    private val clients = CopyOnWriteArrayList<Socket>()
    private var serverSocket: ServerSocket? = null
    private var acceptThread: Thread? = null

    fun start(): Boolean {
        if (running.get()) return true
        return try {
            val server = ServerSocket(port)
            serverSocket = server
            running.set(true)
            acceptThread = Thread({
                Log.i(TAG, "MJPEG listening on :$port/stream.mjpg")
                while (running.get()) {
                    try {
                        val client = server.accept()
                        Thread({ handleClient(client) }, "MjpegClient").start()
                    } catch (_: Exception) {
                        if (!running.get()) break
                    }
                }
            }, "MjpegAccept").also { it.isDaemon = true; it.start() }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start MJPEG server on $port", e)
            running.set(false)
            false
        }
    }

    fun stop() {
        running.set(false)
        try {
            serverSocket?.close()
        } catch (_: Exception) {
        }
        serverSocket = null
        for (c in clients) {
            try {
                c.close()
            } catch (_: Exception) {
            }
        }
        clients.clear()
        latestFrame.set(null)
        acceptThread = null
        Log.i(TAG, "MJPEG server stopped")
    }

    fun publishFrame(jpeg: ByteArray) {
        if (!running.get() || jpeg.isEmpty()) return
        latestFrame.set(jpeg)
    }

    fun getClientCount(): Int = clients.size

    private fun handleClient(socket: Socket) {
        clients.add(socket)
        try {
            socket.soTimeout = 0
            socket.tcpNoDelay = true
            val input = socket.getInputStream().bufferedReader()
            val requestLine = input.readLine() ?: return
            // Drain headers
            while (true) {
                val line = input.readLine() ?: break
                if (line.isEmpty()) break
            }

            val path = requestLine.split(" ").getOrNull(1) ?: "/"
            val out = BufferedOutputStream(socket.getOutputStream())

            if (path.contains("favicon")) {
                writeSimple(out, 404, "text/plain", "Not found")
                return
            }

            // CORS so Flutter web (localhost) can fetch if needed.
            if (path.contains("stream") || path == "/" || path.endsWith(".mjpg") || path.endsWith(".mjpeg")) {
                writeMjpegStream(out)
            } else if (path.contains("snapshot") || path.endsWith(".jpg")) {
                val frame = latestFrame.get()
                if (frame == null) {
                    writeSimple(out, 503, "text/plain", "No frame yet")
                } else {
                    writeJpeg(out, frame)
                }
            } else {
                writeSimple(
                    out,
                    200,
                    "text/plain",
                    "Android IP Camera MJPEG\nGET /stream.mjpg\nGET /snapshot.jpg\n",
                )
            }
        } catch (_: Exception) {
            // Client disconnected
        } finally {
            clients.remove(socket)
            try {
                socket.close()
            } catch (_: Exception) {
            }
        }
    }

    private fun writeMjpegStream(out: BufferedOutputStream) {
        val header = buildString {
            append("HTTP/1.1 200 OK\r\n")
            append("Connection: close\r\n")
            append("Cache-Control: no-cache, no-store, must-revalidate\r\n")
            append("Pragma: no-cache\r\n")
            append("Access-Control-Allow-Origin: *\r\n")
            append("Content-Type: multipart/x-mixed-replace; boundary=$BOUNDARY\r\n")
            append("\r\n")
        }.toByteArray(Charsets.US_ASCII)
        out.write(header)
        out.flush()

        var lastSent: ByteArray? = null
        while (running.get()) {
            val frame = latestFrame.get()
            if (frame == null || frame === lastSent) {
                try {
                    Thread.sleep(40)
                } catch (_: InterruptedException) {
                    break
                }
                continue
            }
            lastSent = frame
            try {
                val part = buildString {
                    append("--$BOUNDARY\r\n")
                    append("Content-Type: image/jpeg\r\n")
                    append("Content-Length: ${frame.size}\r\n")
                    append("\r\n")
                }.toByteArray(Charsets.US_ASCII)
                out.write(part)
                out.write(frame)
                out.write("\r\n".toByteArray(Charsets.US_ASCII))
                out.flush()
            } catch (_: IOException) {
                break
            }
            try {
                Thread.sleep(50) // ~20 fps max per client
            } catch (_: InterruptedException) {
                break
            }
        }
    }

    private fun writeJpeg(out: BufferedOutputStream, jpeg: ByteArray) {
        val header = buildString {
            append("HTTP/1.1 200 OK\r\n")
            append("Content-Type: image/jpeg\r\n")
            append("Content-Length: ${jpeg.size}\r\n")
            append("Cache-Control: no-cache\r\n")
            append("Access-Control-Allow-Origin: *\r\n")
            append("Connection: close\r\n")
            append("\r\n")
        }.toByteArray(Charsets.US_ASCII)
        out.write(header)
        out.write(jpeg)
        out.flush()
    }

    private fun writeSimple(
        out: BufferedOutputStream,
        code: Int,
        mime: String,
        body: String,
    ) {
        val bytes = body.toByteArray(Charsets.UTF_8)
        val header = buildString {
            append("HTTP/1.1 $code OK\r\n")
            append("Content-Type: $mime\r\n")
            append("Content-Length: ${bytes.size}\r\n")
            append("Access-Control-Allow-Origin: *\r\n")
            append("Connection: close\r\n")
            append("\r\n")
        }.toByteArray(Charsets.US_ASCII)
        out.write(header)
        out.write(bytes)
        out.flush()
    }
}
