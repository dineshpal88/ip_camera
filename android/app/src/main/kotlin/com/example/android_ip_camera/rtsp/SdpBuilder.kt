package com.example.android_ip_camera.rtsp

import android.util.Base64

object SdpBuilder {
    fun buildH264Sdp(
        sessionName: String,
        controlTrack: String,
        sps: ByteArray,
        pps: ByteArray,
        width: Int,
        height: Int,
        fps: Int,
    ): String {
        val cleanSps = NalUtils.stripEmulationAndPrefixes(sps)
        val cleanPps = NalUtils.stripEmulationAndPrefixes(pps)
        require(NalUtils.nalType(cleanSps) == 7) { "SPS must be NAL type 7" }
        require(NalUtils.nalType(cleanPps) == 8) { "PPS must be NAL type 8" }

        val spsB64 = Base64.encodeToString(cleanSps, Base64.NO_WRAP)
        val ppsB64 = Base64.encodeToString(cleanPps, Base64.NO_WRAP)
        val profileLevelId = if (cleanSps.size >= 4) {
            String.format(
                "%02X%02X%02X",
                cleanSps[1].toInt() and 0xFF,
                cleanSps[2].toInt() and 0xFF,
                cleanSps[3].toInt() and 0xFF,
            )
        } else {
            "42E01F"
        }

        // Keep SDP minimal and FFmpeg/VLC friendly.
        return buildString {
            append("v=0\r\n")
            append("o=- 0 0 IN IP4 127.0.0.1\r\n")
            append("s=$sessionName\r\n")
            append("c=IN IP4 0.0.0.0\r\n")
            append("t=0 0\r\n")
            append("a=recvonly\r\n")
            append("a=control:*\r\n")
            append("a=range:npt=0-\r\n")
            append("m=video 0 RTP/AVP 96\r\n")
            append("a=rtpmap:96 H264/90000\r\n")
            append(
                "a=fmtp:96 packetization-mode=1;profile-level-id=$profileLevelId;" +
                    "sprop-parameter-sets=$spsB64,$ppsB64\r\n",
            )
            append("a=control:$controlTrack\r\n")
            append("a=framerate:$fps\r\n")
            append("a=framesize:96 $width-$height\r\n")
        }
    }
}
