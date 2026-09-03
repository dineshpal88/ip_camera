package com.example.android_ip_camera.rtsp

import android.util.Log

/**
 * Helpers that always produce clean H.264 NAL units:
 * first byte = NAL header, NO start codes, NO AVCC length prefixes.
 */
object NalUtils {
    private const val TAG = "NalUtils"

    fun stripEmulationAndPrefixes(data: ByteArray): ByteArray {
        var offset = 0
        // Strip repeated Annex-B start codes.
        while (offset + 3 <= data.size) {
            if (data[offset] == 0.toByte() && data[offset + 1] == 0.toByte()) {
                when {
                    data[offset + 2] == 1.toByte() -> {
                        offset += 3
                        continue
                    }
                    offset + 3 < data.size &&
                        data[offset + 2] == 0.toByte() &&
                        data[offset + 3] == 1.toByte() -> {
                        offset += 4
                        continue
                    }
                }
            }
            break
        }
        // Strip AVCC 4-byte length if it exactly wraps the remaining payload.
        if (offset + 4 < data.size) {
            val length = readInt(data, offset)
            if (length > 0 && offset + 4 + length == data.size) {
                offset += 4
            }
        }
        return if (offset == 0) data else data.copyOfRange(offset, data.size)
    }

    fun nalType(nal: ByteArray): Int =
        if (nal.isEmpty()) -1 else nal[0].toInt() and 0x1F

    fun isValidNal(nal: ByteArray): Boolean {
        if (nal.isEmpty()) return false
        val type = nalType(nal)
        return type in 1..23
    }

    /**
     * Extract clean NALs from either Annex-B (start codes) or AVCC (length prefixes).
     */
    fun extractNals(frame: ByteArray): List<ByteArray> {
        if (frame.isEmpty()) return emptyList()
        val annexB = isAnnexB(frame)
        val raw = if (annexB) splitAnnexB(frame) else splitAvcc(frame)
        return raw.map { stripEmulationAndPrefixes(it) }.filter { isValidNal(it) }
    }

    /**
     * Parse MediaCodec csd-0 / csd-1 into clean SPS/PPS.
     */
    fun parseCodecSpecificData(csd0: ByteArray, csd1: ByteArray?): Pair<ByteArray, ByteArray>? {
        // AVC decoder configuration record starts with version=1.
        if (csd0.isNotEmpty() && csd0[0] == 1.toByte() && csd0.size > 7) {
            parseAvcDecoderConfig(csd0)?.let { return it }
        }

        val from0 = extractNals(csd0)
        var sps = from0.firstOrNull { nalType(it) == 7 }
        var pps = from0.firstOrNull { nalType(it) == 8 }

        if (csd1 != null) {
            val from1 = extractNals(csd1)
            if (sps == null) sps = from1.firstOrNull { nalType(it) == 7 }
            if (pps == null) pps = from1.firstOrNull { nalType(it) == 8 }
            // csd-1 is often a single PPS NAL (with or without start code)
            if (pps == null) {
                val cleaned = stripEmulationAndPrefixes(csd1)
                if (nalType(cleaned) == 8) pps = cleaned
            }
        }

        if (sps == null) {
            val cleaned = stripEmulationAndPrefixes(csd0)
            if (nalType(cleaned) == 7) sps = cleaned
        }

        if (sps == null || pps == null) {
            Log.w(TAG, "Failed to parse SPS/PPS from csd (csd0=${csd0.size} csd1=${csd1?.size})")
            return null
        }
        Log.i(
            TAG,
            "Parsed SPS type=${nalType(sps)} size=${sps.size} first=${sps[0].toInt() and 0xFF} " +
                "PPS type=${nalType(pps)} size=${pps.size}",
        )
        return Pair(sps, pps)
    }

    private fun parseAvcDecoderConfig(data: ByteArray): Pair<ByteArray, ByteArray>? {
        return try {
            var offset = 5 // skip version/profile/compat/level
            val lengthSizeMinusOne = data[offset].toInt() and 0x03
            offset++
            if (lengthSizeMinusOne != 3) {
                Log.w(TAG, "Unexpected lengthSizeMinusOne=$lengthSizeMinusOne")
            }
            val numSps = data[offset].toInt() and 0x1F
            offset++
            var sps: ByteArray? = null
            repeat(numSps) {
                val len = ((data[offset].toInt() and 0xFF) shl 8) or (data[offset + 1].toInt() and 0xFF)
                offset += 2
                val nal = stripEmulationAndPrefixes(data.copyOfRange(offset, offset + len))
                offset += len
                if (nalType(nal) == 7) sps = nal
            }
            val numPps = data[offset].toInt() and 0xFF
            offset++
            var pps: ByteArray? = null
            repeat(numPps) {
                val len = ((data[offset].toInt() and 0xFF) shl 8) or (data[offset + 1].toInt() and 0xFF)
                offset += 2
                val nal = stripEmulationAndPrefixes(data.copyOfRange(offset, offset + len))
                offset += len
                if (nalType(nal) == 8) pps = nal
            }
            if (sps != null && pps != null) {
                Log.i(TAG, "Parsed avcC SPS=${sps!!.size} PPS=${pps!!.size}")
                Pair(sps!!, pps!!)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "avcC parse failed: ${e.message}")
            null
        }
    }

    private fun isAnnexB(data: ByteArray): Boolean {
        if (data.size < 3) return false
        if (data[0] != 0.toByte() || data[1] != 0.toByte()) return false
        if (data[2] == 1.toByte()) return true
        return data.size >= 4 && data[2] == 0.toByte() && data[3] == 1.toByte()
    }

    private fun splitAnnexB(data: ByteArray): List<ByteArray> {
        val starts = mutableListOf<Pair<Int, Int>>() // startCodeLen to nalStart
        var i = 0
        while (i + 3 <= data.size) {
            if (data[i] == 0.toByte() && data[i + 1] == 0.toByte()) {
                if (data[i + 2] == 1.toByte()) {
                    starts.add(3 to (i + 3))
                    i += 3
                    continue
                }
                if (i + 3 < data.size && data[i + 2] == 0.toByte() && data[i + 3] == 1.toByte()) {
                    starts.add(4 to (i + 4))
                    i += 4
                    continue
                }
            }
            i++
        }
        if (starts.isEmpty()) return emptyList()
        val nals = mutableListOf<ByteArray>()
        for (index in starts.indices) {
            val nalStart = starts[index].second
            val nalEnd = if (index + 1 < starts.size) {
                starts[index + 1].second - starts[index + 1].first
            } else {
                data.size
            }
            if (nalEnd > nalStart) {
                nals.add(data.copyOfRange(nalStart, nalEnd))
            }
        }
        return nals
    }

    private fun splitAvcc(data: ByteArray): List<ByteArray> {
        val nals = mutableListOf<ByteArray>()
        var offset = 0
        while (offset + 4 <= data.size) {
            val length = readInt(data, offset)
            offset += 4
            if (length <= 0 || offset + length > data.size) break
            nals.add(data.copyOfRange(offset, offset + length))
            offset += length
        }
        return nals
    }

    private fun readInt(data: ByteArray, offset: Int): Int {
        return ((data[offset].toInt() and 0xFF) shl 24) or
            ((data[offset + 1].toInt() and 0xFF) shl 16) or
            ((data[offset + 2].toInt() and 0xFF) shl 8) or
            (data[offset + 3].toInt() and 0xFF)
    }
}
