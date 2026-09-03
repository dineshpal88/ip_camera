package com.example.android_ip_camera.camera

data class CameraConfiguration(
    val width: Int = 1280,
    val height: Int = 720,
    val fps: Int = 30,
    val bitrate: Int = 2_000_000,
    val useFrontCamera: Boolean = false,
) {
    companion object {
        val RESOLUTIONS = listOf(
            Pair(640, 480),
            Pair(1280, 720),
            Pair(1920, 1080),
        )
        val FPS_OPTIONS = listOf(15, 24, 30)
        val BITRATE_OPTIONS = listOf(1_000_000, 2_000_000, 4_000_000, 6_000_000)

        fun resolutionLabel(width: Int, height: Int): String = "${width}x$height"

        fun bitrateLabel(bitrate: Int): String = when (bitrate) {
            1_000_000 -> "1 Mbps"
            2_000_000 -> "2 Mbps"
            4_000_000 -> "4 Mbps"
            6_000_000 -> "6 Mbps"
            else -> "${bitrate / 1_000_000} Mbps"
        }
    }
}
