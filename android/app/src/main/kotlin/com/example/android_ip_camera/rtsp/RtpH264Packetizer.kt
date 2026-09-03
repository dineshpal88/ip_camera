package com.example.android_ip_camera.rtsp

import android.util.Log
import kotlin.random.Random

/**
 * RFC 6184 H.264 RTP packetizer (single NAL + FU-A).
 * Expects clean NAL units (no start codes / length prefixes).
 */
class RtpH264Packetizer(
    private val mtuPayload: Int = 1200,
    payloadType: Int = 96,
) {
    companion object {
        private const val TAG = "RtpPacketizer"
        private const val RTP_VERSION = 2
        private const val CLOCK_RATE = 90_000
    }

    private val ssrc: Int = Random.nextInt()
    private var sequenceNumber: Int = Random.nextInt(0, 65535)
    private val payloadType: Int = payloadType and 0x7F
    private var basePtsUs: Long = -1L

    fun clockRate(): Int = CLOCK_RATE

    fun resetTimeline() {
        basePtsUs = -1L
    }

    fun extractNalUnits(frame: ByteArray): List<ByteArray> = NalUtils.extractNals(frame)

    fun isStreamableNal(nal: ByteArray): Boolean {
        if (!NalUtils.isValidNal(nal)) return false
        val type = NalUtils.nalType(nal)
        return type != 9 && type != 12
    }

    fun containsIdr(nals: List<ByteArray>): Boolean {
        return nals.any { NalUtils.nalType(it) == 5 }
    }

    fun packetize(
        nalUnits: List<ByteArray>,
        presentationTimeUs: Long,
        isAccessUnitKeyFrame: Boolean = false,
        marker: Boolean? = null,
    ): List<RtpPacket> {
        val rtpTimestamp = toRtpTimestamp(presentationTimeUs)
        val packets = mutableListOf<RtpPacket>()
        for ((index, nal) in nalUnits.withIndex()) {
            val clean = NalUtils.stripEmulationAndPrefixes(nal)
            if (!NalUtils.isValidNal(clean)) continue
            val isLastNal = index == nalUnits.lastIndex
            val nalType = NalUtils.nalType(clean)
            val rtpMarker = marker
                ?: (isLastNal && (isAccessUnitKeyFrame || nalType == 5 || nalType == 1))
            if (clean.size <= mtuPayload) {
                packets.add(buildSingleNalPacket(clean, rtpTimestamp, marker = rtpMarker && isLastNal))
            } else {
                packets.addAll(buildFuAPackets(clean, rtpTimestamp, marker = rtpMarker && isLastNal))
            }
        }
        return packets
    }

    private fun toRtpTimestamp(presentationTimeUs: Long): Long {
        if (basePtsUs < 0L) {
            basePtsUs = presentationTimeUs
        }
        val deltaUs = (presentationTimeUs - basePtsUs).coerceAtLeast(0L)
        return ((deltaUs * CLOCK_RATE) / 1_000_000L) and 0xFFFFFFFFL
    }

    private fun buildSingleNalPacket(
        nal: ByteArray,
        timestamp: Long,
        marker: Boolean,
    ): RtpPacket {
        val header = buildRtpHeader(marker, timestamp)
        val packet = ByteArray(12 + nal.size)
        System.arraycopy(header, 0, packet, 0, 12)
        System.arraycopy(nal, 0, packet, 12, nal.size)
        sequenceNumber = (sequenceNumber + 1) and 0xFFFF
        return RtpPacket(packet, packet.size, timestamp, marker)
    }

    private fun buildFuAPackets(
        nal: ByteArray,
        timestamp: Long,
        marker: Boolean,
    ): List<RtpPacket> {
        val nalType = nal[0].toInt() and 0x1F
        val nalHeader = (nal[0].toInt() and 0x60).toByte()
        val fuPayloadMax = mtuPayload - 2
        val fuData = nal.copyOfRange(1, nal.size)
        val packets = mutableListOf<RtpPacket>()
        var offset = 0
        while (offset < fuData.size) {
            val chunkSize = minOf(fuPayloadMax, fuData.size - offset)
            val isFirst = offset == 0
            val isLast = offset + chunkSize >= fuData.size
            val fuIndicator = (nalHeader.toInt() or 28).toByte()
            var fuHeader = nalType
            if (isFirst) fuHeader = fuHeader or 0x80
            if (isLast) fuHeader = fuHeader or 0x40

            val header = buildRtpHeader(isLast && marker, timestamp)
            val packet = ByteArray(12 + 2 + chunkSize)
            System.arraycopy(header, 0, packet, 0, 12)
            packet[12] = fuIndicator
            packet[13] = fuHeader.toByte()
            System.arraycopy(fuData, offset, packet, 14, chunkSize)
            sequenceNumber = (sequenceNumber + 1) and 0xFFFF
            packets.add(RtpPacket(packet, packet.size, timestamp, isLast && marker))
            offset += chunkSize
        }
        if (packets.isEmpty()) {
            Log.w(TAG, "FU-A produced no packets for NAL size=${nal.size}")
        }
        return packets
    }

    private fun buildRtpHeader(marker: Boolean, timestamp: Long): ByteArray {
        val header = ByteArray(12)
        header[0] = (RTP_VERSION shl 6).toByte()
        header[1] = (payloadType or if (marker) 0x80 else 0).toByte()
        header[2] = ((sequenceNumber shr 8) and 0xFF).toByte()
        header[3] = (sequenceNumber and 0xFF).toByte()
        header[4] = ((timestamp shr 24) and 0xFF).toByte()
        header[5] = ((timestamp shr 16) and 0xFF).toByte()
        header[6] = ((timestamp shr 8) and 0xFF).toByte()
        header[7] = (timestamp and 0xFF).toByte()
        header[8] = ((ssrc shr 24) and 0xFF).toByte()
        header[9] = ((ssrc shr 16) and 0xFF).toByte()
        header[10] = ((ssrc shr 8) and 0xFF).toByte()
        header[11] = (ssrc and 0xFF).toByte()
        return header
    }
}
