package com.example.android_ip_camera.rtsp

class RtpPacket(
    val data: ByteArray,
    val length: Int,
    val timestamp: Long,
    val marker: Boolean,
)
