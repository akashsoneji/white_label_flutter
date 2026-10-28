package com.example.pipze

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.webkit.WebView
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterFragmentActivity() {
    // Link that launched the activity, handed to Dart once via getInitialLink.
    private var initialLink: String? = null
    // Link that arrived while Dart was not listening yet; flushed on onListen.
    private var pendingLink: String? = null
    private var linkEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "app/deeplink").setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    result.success(if (BuildConfig.DEEP_LINK_ENABLED) initialLink else null)
                    initialLink = null
                }
                "getInstallReferrer" -> fetchInstallReferrer(result)
                "getDeviceInfo" -> result.success(
                    mapOf(
                        "platform" to "android",
                        "osVersion" to Build.VERSION.RELEASE,
                        "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
                        "timezone" to TimeZone.getDefault().id,
                        "language" to Locale.getDefault().toLanguageTag(),
                    )
                )
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "app/deeplink/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    linkEventSink = events
                    pendingLink?.let { events.success(it) }
                    pendingLink = null
                }

                override fun onCancel(arguments: Any?) {
                    linkEventSink = null
                }
            }
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val link = linkFrom(intent) ?: return
        val sink = linkEventSink
        if (sink != null) sink.success(link) else pendingLink = link
    }

    /// Returns the raw Play referrer string (e.g. `ref_code=ABC&click_id=...`)
    /// or null. Organic installs return Play's default utm string, which the
    /// Dart side ignores and then falls back to the server claim.
    private fun fetchInstallReferrer(result: MethodChannel.Result) {
        if (!BuildConfig.DEEP_LINK_ENABLED) {
            result.success(null)
            return
        }
        val client = InstallReferrerClient.newBuilder(this).build()
        var replied = false
        fun reply(referrer: String?) {
            runOnUiThread {
                if (replied) return@runOnUiThread
                replied = true
                result.success(referrer)
                try {
                    client.endConnection()
                } catch (_: Exception) {
                }
            }
        }
        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    if (responseCode != InstallReferrerClient.InstallReferrerResponse.OK) {
                        reply(null)
                        return
                    }
                    val referrer = try {
                        client.installReferrer.installReferrer
                    } catch (_: Exception) {
                        null
                    }
                    reply(referrer)
                }

                override fun onInstallReferrerServiceDisconnected() {
                    reply(null)
                }
            })
        } catch (_: Exception) {
            reply(null)
        }
    }

    private fun linkFrom(intent: Intent?): String? {
        if (!BuildConfig.DEEP_LINK_ENABLED) return null
        if (intent?.action != Intent.ACTION_VIEW) return null
        return intent.data?.toString()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Only a fresh launch carries a new link; a recreated activity would replay it.
        if (savedInstanceState == null) initialLink = linkFrom(intent)
        
        // Disable WebView logging and frame rate logs
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(false)
        }
        
        // Disable verbose logging for WebView components
        try {
            // Set log level to reduce noise
            System.setProperty("android.webkit.WebView.EnableSafeBrowsing", "false")
            System.setProperty("android.webkit.WebView.MetricsOptOut", "true")
            
            // Disable GPU logging
            System.setProperty("debug.egl.debug_messages", "0")
            System.setProperty("debug.gpu.debug_messages", "0")
            System.setProperty("debug.gpu.profiler", "0")
            System.setProperty("debug.gpu.use_profiler", "0")
            
            // Suppress specific log tags at system level
            // ASSERT level suppresses all logs for these tags
            System.setProperty("log.tag.View", "ASSERT")
            System.setProperty("log.tag.ImageReader_JNI", "ASSERT")
            System.setProperty("log.tag.GPUAUX", "ASSERT")
            
            // Disable View frame rate logging
            System.setProperty("debug.view.frame_rate", "0")
            System.setProperty("debug.view.requested_frame_rate", "0")
            
            // Disable ImageReader verbose logging
            System.setProperty("debug.imagereader", "0")
            
            // Additional ImageReader buffer suppression
            System.setProperty("log.tag.ImageReader", "ASSERT")
            System.setProperty("log.tag.BufferQueue", "ASSERT")
            
            // Suppress buffer-related warnings
            System.setProperty("debug.buffer.verbose", "0")
            System.setProperty("debug.buffer.warning", "0")
            
        } catch (e: Exception) {
            // Silently fail - don't log errors about logging suppression
        }
        
        // Keep screen on to prevent automatic locking/sleep
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
