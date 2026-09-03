package com.example.android_ip_camera.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import java.net.Inet4Address
import java.net.NetworkInterface

object NetworkUtils {
    private const val TAG = "NetworkUtils"

    fun getWifiIpv4Address(context: Context): String? {
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = cm.activeNetwork ?: return getFallbackIpv4()
            val caps = cm.getNetworkCapabilities(network)
            if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                val linkProps = cm.getLinkProperties(network)
                linkProps?.linkAddresses?.forEach { addr ->
                    val inet = addr.address
                    if (inet is Inet4Address && !inet.isLoopbackAddress) {
                        return inet.hostAddress
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read Wi-Fi IP via ConnectivityManager", e)
        }
        return getFallbackIpv4()
    }

    private fun getFallbackIpv4(): String? {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val ni = interfaces.nextElement()
                if (!ni.isUp || ni.isLoopback) continue
                val name = ni.name.lowercase()
                if (!name.startsWith("wlan") && !name.startsWith("wifi") && !name.startsWith("eth")) {
                    continue
                }
                ni.inetAddresses.asSequence().forEach { addr ->
                    if (addr is Inet4Address && !addr.isLoopbackAddress) {
                        return addr.hostAddress
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Fallback IP lookup failed", e)
        }
        return null
    }
}
