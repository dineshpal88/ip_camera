package com.example.android_ip_camera

import android.content.Context
import android.graphics.SurfaceTexture
import android.view.Surface
import android.view.TextureView
import io.flutter.plugin.platform.PlatformView

class CameraPreviewView(
    context: Context,
) : PlatformView, TextureView.SurfaceTextureListener {
    private val textureView = TextureView(context)
    private var surface: Surface? = null
    private var surfaceTexture: SurfaceTexture? = null

    init {
        textureView.surfaceTextureListener = this
        IpCameraEngine.setPreviewBufferSizeListener { width, height ->
            applyBufferSize(width, height, restartPreview = true)
        }
    }

    override fun getView() = textureView

    override fun dispose() {
        IpCameraEngine.setPreviewBufferSizeListener(null)
        IpCameraEngine.stopPreview()
        surface?.release()
        surface = null
        surfaceTexture = null
    }

    override fun onSurfaceTextureAvailable(texture: SurfaceTexture, width: Int, height: Int) {
        surfaceTexture = texture
        val (bufferW, bufferH) = IpCameraEngine.getPreviewBufferSize()
        applyBufferSize(bufferW, bufferH, restartPreview = false)
        surface = Surface(texture)
        IpCameraEngine.startPreview(surface!!)
    }

    override fun onSurfaceTextureSizeChanged(texture: SurfaceTexture, width: Int, height: Int) {
        val (bufferW, bufferH) = IpCameraEngine.getPreviewBufferSize()
        applyBufferSize(bufferW, bufferH, restartPreview = false)
    }

    override fun onSurfaceTextureDestroyed(texture: SurfaceTexture): Boolean {
        IpCameraEngine.stopPreview()
        surface?.release()
        surface = null
        surfaceTexture = null
        return true
    }

    override fun onSurfaceTextureUpdated(texture: SurfaceTexture) {}

    private fun applyBufferSize(width: Int, height: Int, restartPreview: Boolean) {
        val texture = surfaceTexture ?: return
        texture.setDefaultBufferSize(width, height)
        if (!restartPreview) return
        val previewSurface = surface ?: return
        IpCameraEngine.startPreview(previewSurface)
    }
}
